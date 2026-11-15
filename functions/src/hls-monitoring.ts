import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { defineSecret } from 'firebase-functions/params';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import {
  aggregateHlsSamples,
  parseHlsSamples,
  sampleHlsPoints,
  type HlsObservation,
  type HlsPoint,
} from './hls-analysis';

const NASA_EARTHDATA_USERNAME = defineSecret('NASA_EARTHDATA_USERNAME');
const NASA_EARTHDATA_PASSWORD = defineSecret('NASA_EARTHDATA_PASSWORD');
const APPEEARS_BASE_URL = 'https://appeears.earthdatacloud.nasa.gov/api';
const MAX_RANGE_DAYS = 366;
const MAX_BUNDLE_FILES = 20;
const MAX_CSV_BYTES_PER_FILE = 5 * 1024 * 1024;
const MAX_TOTAL_CSV_BYTES = 20 * 1024 * 1024;
const NASA_TIMEOUT_MS = 30_000;
const NASA_BUNDLE_TIMEOUT_MS = 20_000;
const INDEX_METRICS = new Set([
  'EVI', 'MSAVI', 'NBR', 'NBR2', 'NDMI', 'NDVI', 'NDRE', 'NDWI', 'SAVI', 'TVI',
]);
const EARTHDATA_SETUP_ERROR =
  'لم تُضبط أسرار NASA Earthdata. يُرجى من مالك التطبيق إعداد NASA_EARTHDATA_USERNAME وNASA_EARTHDATA_PASSWORD قبل استخدام التحليل.';
const SAFE_FAILURE_ARABIC =
  'تعذر إكمال تحليل صور الأقمار الصناعية حاليًا. حاول مرة أخرى لاحقًا.';

const PRODUCTS_AND_LAYERS: ReadonlyArray<{ product: string; layers: readonly string[] }> = [
  {
    product: 'HLSL30.020',
    layers: ['B01', 'B02', 'B03', 'B04', 'B05', 'B06', 'B07', 'B09', 'B10', 'B11', 'Fmask', 'SAA', 'SZA', 'VAA', 'VZA'],
  },
  {
    product: 'HLSS30.020',
    layers: ['B01', 'B02', 'B03', 'B04', 'B05', 'B06', 'B07', 'B08', 'B8A', 'B09', 'B10', 'B11', 'B12', 'Fmask', 'SAA', 'SZA', 'VAA', 'VZA'],
  },
  {
    product: 'HLSL30_VI.020',
    layers: ['EVI', 'MSAVI', 'NBR', 'NBR2', 'NDMI', 'NDVI', 'NDWI', 'SAVI', 'TVI'],
  },
  {
    product: 'HLSS30_VI.020',
    layers: ['EVI', 'MSAVI', 'NBR', 'NBR2', 'NDMI', 'NDVI', 'NDWI', 'SAVI', 'TVI'],
  },
];

interface TokenCache {
  token: string;
  safeExpiresAt: number;
}

interface InternalJob {
  uid: string;
  fieldId: string;
  runId: string;
  samplePoints: HlsPoint[];
  nasaTaskId?: string;
  status?: string;
  lockUntil?: number;
}

let earthdataTokenCache: TokenCache | null = null;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function safeFieldId(value: unknown): value is string {
  return typeof value === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(value);
}

function safeRunId(value: unknown): value is string {
  return typeof value === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(value);
}

function parseIsoDate(value: unknown): Date | null {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return null;
  const date = new Date(`${value}T00:00:00.000Z`);
  return Number.isFinite(date.getTime()) && date.toISOString().slice(0, 10) === value
    ? date
    : null;
}

function appeearsDate(date: Date): string {
  const month = String(date.getUTCMonth() + 1).padStart(2, '0');
  const day = String(date.getUTCDate()).padStart(2, '0');
  return `${month}-${day}-${date.getUTCFullYear()}`;
}

function getFieldPolygon(data: Record<string, unknown>): unknown {
  const candidate = data['polygon'] ?? data['fieldPolygon'] ?? data['boundary'] ?? data['coordinates'];
  if (candidate !== undefined) return candidate;
  const geometry = data['geometry'];
  if (!isRecord(geometry) || !Array.isArray(geometry['coordinates'])) return undefined;
  const ring = geometry['coordinates'][0];
  if (!Array.isArray(ring)) return undefined;
  // GeoJSON stores coordinates as [longitude, latitude]; the helper accepts [latitude, longitude].
  return ring.map((position: unknown) => {
    if (!Array.isArray(position) || position.length < 2) return position;
    return { latitude: position[1], longitude: position[0] };
  });
}

function validateSecrets(): { username: string; password: string } {
  let username = '';
  let password = '';
  try {
    username = NASA_EARTHDATA_USERNAME.value().trim();
    password = NASA_EARTHDATA_PASSWORD.value();
  } catch {
    throw new HttpsError('failed-precondition', EARTHDATA_SETUP_ERROR);
  }
  if (!username || !password) {
    throw new HttpsError('failed-precondition', EARTHDATA_SETUP_ERROR);
  }
  return { username, password };
}

async function getEarthdataToken(username: string, password: string): Promise<string> {
  const now = Date.now();
  if (earthdataTokenCache && earthdataTokenCache.safeExpiresAt > now) {
    return earthdataTokenCache.token;
  }

  const response = await fetch(`${APPEEARS_BASE_URL}/login`, {
    method: 'POST',
    headers: {
      Authorization: `Basic ${Buffer.from(`${username}:${password}`).toString('base64')}`,
      Accept: 'application/json',
    },
    signal: AbortSignal.timeout(NASA_TIMEOUT_MS),
  });
  if (!response.ok) throw new Error('Earthdata login failed');
  const payload: unknown = await response.json();
  if (!isRecord(payload) || typeof payload['token'] !== 'string' || payload['token'].length === 0) {
    throw new Error('Earthdata login response was invalid');
  }
  const token = payload['token'];
  const expirationValue = payload['expiration'] ?? payload['expires'] ?? payload['expires_at'];
  const providerExpiration = typeof expirationValue === 'string'
    ? Date.parse(expirationValue)
    : typeof expirationValue === 'number'
      ? (expirationValue < 10_000_000_000 ? expirationValue * 1000 : expirationValue)
      : Number.NaN;
  // If the service omits an explicit expiry, keep the usual short-lived token for at most 55 minutes.
  const safeExpiresAt = Number.isFinite(providerExpiration)
    ? providerExpiration - 5 * 60 * 1000
    : now + 55 * 60 * 1000;
  earthdataTokenCache = { token, safeExpiresAt };
  return token;
}

async function requestJson(
  path: string,
  token: string,
  init: RequestInit = {},
): Promise<unknown> {
  const response = await fetch(`${APPEEARS_BASE_URL}${path}`, {
    ...init,
    headers: {
      Accept: 'application/json',
      Authorization: `Bearer ${token}`,
      ...(init.body === undefined ? {} : { 'Content-Type': 'application/json' }),
      ...init.headers,
    },
    signal: init.signal ?? AbortSignal.timeout(NASA_TIMEOUT_MS),
  });
  if (!response.ok) throw new Error(`AppEEARS returned HTTP ${response.status}`);
  return response.json() as Promise<unknown>;
}

function getTaskId(payload: unknown): string | null {
  if (!isRecord(payload)) return null;
  const value = payload['task_id'] ?? payload['taskId'] ?? payload['id'];
  return typeof value === 'string' || typeof value === 'number'
    ? String(value)
    : null;
}

function getRemoteStatus(payload: unknown): string {
  if (typeof payload === 'string') return payload.trim().slice(0, 40) || 'unknown';
  if (!isRecord(payload)) return 'unknown';
  const value = payload['status'] ?? payload['task_status'] ?? payload['state'];
  if (typeof value !== 'string') return 'unknown';
  const status = value.trim().slice(0, 40);
  return /^[A-Za-z0-9 _-]+$/.test(status) ? status : 'unknown';
}

function isRemoteDone(status: string): boolean {
  return ['done', 'complete', 'completed', 'finished', 'succeeded', 'success'].includes(
    status.toLowerCase(),
  );
}

function isRemoteFailure(status: string): boolean {
  return ['failed', 'error', 'canceled', 'cancelled', 'deleted'].includes(status.toLowerCase());
}

function bundleFiles(payload: unknown): Array<{ id: string; name: string; size: number | null }> {
  const entries = Array.isArray(payload)
    ? payload
    : isRecord(payload) && Array.isArray(payload['files'])
      ? payload['files']
      : [];
  if (entries.length > MAX_BUNDLE_FILES) throw new Error('AppEEARS bundle exceeded file limit');
  const files: Array<{ id: string; name: string; size: number | null }> = [];
  for (const entry of entries) {
    if (!isRecord(entry)) continue;
    const idValue = entry['file_id'] ?? entry['fileId'] ?? entry['id'];
    const nameValue = entry['file_name'] ?? entry['fileName'] ?? entry['name'] ?? '';
    const sizeValue = entry['file_size'] ?? entry['fileSize'] ?? entry['size'];
    if (typeof idValue !== 'string' && typeof idValue !== 'number') continue;
    const name = typeof nameValue === 'string' ? nameValue : '';
    if (!/\.csv(?:\.gz)?$/i.test(name) && !String(entry['file_type'] ?? '').toLowerCase().includes('csv')) {
      continue;
    }
    const size = typeof sizeValue === 'number' && Number.isFinite(sizeValue) ? sizeValue : null;
    if (size !== null && size > MAX_CSV_BYTES_PER_FILE) {
      throw new Error('AppEEARS CSV file exceeded size limit');
    }
    files.push({ id: String(idValue), name, size });
  }
  return files;
}

async function downloadCsvBundle(bundleId: string, token: string): Promise<string[]> {
  const bundle = await requestJson(`/bundle/${encodeURIComponent(bundleId)}`, token);
  const files = bundleFiles(bundle);
  if (files.length === 0) throw new Error('AppEEARS bundle contained no CSV files');
  const texts: string[] = [];
  let totalBytes = 0;
  for (const file of files) {
    const response = await fetch(
      `${APPEEARS_BASE_URL}/bundle/${encodeURIComponent(bundleId)}/${encodeURIComponent(file.id)}`,
      {
        headers: { Authorization: `Bearer ${token}`, Accept: 'text/csv, application/octet-stream' },
        signal: AbortSignal.timeout(NASA_BUNDLE_TIMEOUT_MS),
      },
    );
    if (!response.ok) throw new Error(`AppEEARS bundle file returned HTTP ${response.status}`);
    const advertisedLength = Number(response.headers.get('content-length'));
    if (Number.isFinite(advertisedLength) && advertisedLength > MAX_CSV_BYTES_PER_FILE) {
      throw new Error('AppEEARS CSV file exceeded size limit');
    }
    const text = await response.text();
    const bytes = Buffer.byteLength(text, 'utf8');
    if (bytes > MAX_CSV_BYTES_PER_FILE || totalBytes + bytes > MAX_TOTAL_CSV_BYTES) {
      throw new Error('AppEEARS bundle exceeded size limit');
    }
    totalBytes += bytes;
    if (/\.gz$/i.test(file.name)) throw new Error('Compressed AppEEARS CSV is unsupported');
    texts.push(text);
  }
  return texts;
}

function safeRunStatus(value: unknown): string {
  if (typeof value !== 'string') return 'pending';
  return /^[A-Za-z0-9 _-]{1,40}$/.test(value) ? value : 'pending';
}

async function markRunFailed(
  uid: string,
  fieldId: string,
  runId: string,
  message: string = SAFE_FAILURE_ARABIC,
): Promise<void> {
  const db = getFirestore();
  const runRef = db.collection('users').doc(uid)
    .collection('satellite_fields').doc(fieldId)
    .collection('analysis_runs').doc(runId);
  await Promise.allSettled([
    runRef.set({
      status: 'failed',
      errorArabic: message,
      error_message: message,
      updatedAt: FieldValue.serverTimestamp(),
      updated_at: FieldValue.serverTimestamp(),
    }, { merge: true }),
    db.collection('hls_analysis_jobs').doc(runId).set({
      status: 'failed',
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true }),
  ]);
}

async function claimJob(jobRef: FirebaseFirestore.DocumentReference): Promise<boolean> {
  const db = getFirestore();
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(jobRef);
    if (!snapshot.exists) return false;
    const data = snapshot.data() ?? {};
    if (data['status'] === 'completed' || data['status'] === 'failed') return false;
    const lockUntil = typeof data['lockUntil'] === 'number' ? data['lockUntil'] : 0;
    if (data['status'] === 'processing' && lockUntil > Date.now()) return false;
    transaction.set(jobRef, {
      status: 'processing',
      lockUntil: Date.now() + 10 * 60 * 1000,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    return true;
  });
}

function readInternalJob(value: unknown): InternalJob | null {
  if (!isRecord(value)) return null;
  const { uid, fieldId, runId, samplePoints, nasaTaskId, status, lockUntil } = value;
  if (
    typeof uid !== 'string' || !safeFieldId(fieldId) || !safeRunId(runId) ||
    !Array.isArray(samplePoints) || samplePoints.length < 1 || samplePoints.length > 9 ||
    !samplePoints.every((point) => isRecord(point) &&
      typeof point['id'] === 'string' && typeof point['latitude'] === 'number' &&
      typeof point['longitude'] === 'number')
  ) return null;
  return {
    uid,
    fieldId,
    runId,
    samplePoints: samplePoints as HlsPoint[],
    ...(typeof nasaTaskId === 'string' ? { nasaTaskId } : {}),
    ...(typeof status === 'string' ? { status } : {}),
    ...(typeof lockUntil === 'number' ? { lockUntil } : {}),
  };
}

function buildTaskPayload(taskName: string, startDate: Date, endDate: Date, points: HlsPoint[]) {
  return {
    task_type: 'point',
    task_name: taskName,
    params: {
      dates: [{ startDate: appeearsDate(startDate), endDate: appeearsDate(endDate) }],
      layers: PRODUCTS_AND_LAYERS.flatMap(({ product, layers }) =>
        layers.map((layer) => ({ product, layer })),
      ),
      coordinates: points.map(({ latitude, longitude, id, category }) => ({
        latitude,
        longitude,
        id,
        category,
      })),
    },
  };
}

async function writeCompletedObservations(
  uid: string,
  fieldId: string,
  runId: string,
  observations: HlsObservation[],
): Promise<void> {
  const db = getFirestore();
  const observationsRef = db.collection('users').doc(uid)
    .collection('satellite_fields').doc(fieldId)
    .collection('analysis_runs').doc(runId).collection('observations');
  for (let offset = 0; offset < observations.length; offset += 350) {
    const batch = db.batch();
    for (const observation of observations.slice(offset, offset + 350)) {
      const { date, ...data } = observation;
      const metrics: Record<string, number> = {};
      const bands: Record<string, number> = {};
      const medianMetrics: Record<string, number> = {};
      for (const [name, summary] of Object.entries(observation.metrics)) {
        if (INDEX_METRICS.has(name)) metrics[name] = summary.mean;
        else bands[name] = summary.mean;
        medianMetrics[name] = summary.median;
      }
      const samples = observation.points.map((point) => {
        const indices: Record<string, number> = {};
        const pointBands: Record<string, number> = {};
        for (const [name, value] of Object.entries(point.metrics)) {
          if (INDEX_METRICS.has(name)) indices[name] = value;
          else pointBands[name] = value;
        }
        const fmask = point.qa['HLSS30']?.raw ?? point.qa['HLSL30']?.raw;
        return {
          id: point.id,
          latitude: point.latitude,
          longitude: point.longitude,
          indices,
          bands: pointBands,
          qa: point.qa,
          ...(fmask === undefined ? {} : { fmask }),
        };
      });
      batch.set(observationsRef.doc(date), {
        ...data,
        date,
        metrics,
        bands,
        samples,
        metric_summaries: observation.metrics,
        median_metrics: medianMetrics,
        valid_sample_count: observation.validPointCount,
        total_sample_count: observation.totalPointCount,
        validSampleCount: observation.validPointCount,
        totalSampleCount: observation.totalPointCount,
        sources: ['NASA HLS/AppEEARS'],
        quality: observation.qa,
        alerts: observation.alerts.map((alert) => alert.message),
        alert_details: observation.alerts,
        // Retain explicit camelCase aliases for the public callable/schema contract.
        validPointCount: observation.validPointCount,
        totalPointCount: observation.totalPointCount,
        metricSummaries: observation.metrics,
        createdAt: FieldValue.serverTimestamp(),
        created_at: FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}

async function finishTask(
  uid: string,
  fieldId: string,
  runId: string,
  samplePoints: HlsPoint[],
  taskId: string,
  token: string,
): Promise<{ runId: string; status: string }> {
  const db = getFirestore();
  const jobRef = db.collection('hls_analysis_jobs').doc(runId);
  const runRef = db.collection('users').doc(uid)
    .collection('satellite_fields').doc(fieldId)
    .collection('analysis_runs').doc(runId);
  const claim = await claimJob(jobRef);
  if (!claim) {
    const latest = await runRef.get();
    const latestStatus = safeRunStatus(latest.get('status'));
    return {
      runId,
      status: latestStatus === 'completed' || latestStatus === 'failed'
        ? latestStatus
        : 'pending',
    };
  }

  try {
    const task = await requestJson(`/task/${encodeURIComponent(taskId)}`, token);
    const remoteStatus = getRemoteStatus(task);
    if (isRemoteFailure(remoteStatus)) {
      await markRunFailed(uid, fieldId, runId);
      throw new HttpsError('failed-precondition', SAFE_FAILURE_ARABIC);
    }
    if (!isRemoteDone(remoteStatus)) {
      await Promise.all([
        runRef.set({ status: remoteStatus, updatedAt: FieldValue.serverTimestamp() }, { merge: true }),
        jobRef.set({
          status: 'pending',
          lockUntil: 0,
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true }),
      ]);
      return { runId, status: 'pending' };
    }

    const bundleId = getTaskId(task) ?? taskId;
    const csvFiles = await downloadCsvBundle(bundleId, token);
    const samples = csvFiles.flatMap((csv) => parseHlsSamples(csv));
    const observations = aggregateHlsSamples(samples, samplePoints);
    await writeCompletedObservations(uid, fieldId, runId, observations);
    const alertCount = observations.reduce((sum, observation) => sum + observation.alerts.length, 0);
    await Promise.all([
      runRef.set({
        status: 'completed',
        summary: {
          observationCount: observations.length,
          validPointCount: observations.reduce((sum, item) => sum + item.validPointCount, 0),
          latestObservationDate: observations.at(-1)?.date ?? null,
          alertCount,
        },
        observation_count: observations.length,
        sources: ['NASA HLS/AppEEARS'],
        completedAt: FieldValue.serverTimestamp(),
        completed_at: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        updated_at: FieldValue.serverTimestamp(),
      }, { merge: true }),
      jobRef.set({
        status: 'completed',
        lockUntil: 0,
        completedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true }),
    ]);
    return { runId, status: 'completed' };
  } catch (error) {
    await markRunFailed(uid, fieldId, runId);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError('unavailable', SAFE_FAILURE_ARABIC);
  }
}

export const requestHlsCropAnalysis = onCall(
  {
    region: 'europe-west1',
    enforceAppCheck: true,
    timeoutSeconds: 540,
    secrets: [NASA_EARTHDATA_USERNAME, NASA_EARTHDATA_PASSWORD],
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', 'سجّل الدخول أولًا.');
    const usernameAndPassword = validateSecrets();
    if (!isRecord(request.data)) {
      throw new HttpsError('invalid-argument', 'بيانات طلب التحليل غير صالحة.');
    }
    const fieldId = request.data['fieldId'];
    const startDate = parseIsoDate(request.data['startDate']);
    const endDate = parseIsoDate(request.data['endDate']);
    if (!safeFieldId(fieldId)) {
      throw new HttpsError('invalid-argument', 'معرّف الحقل غير صالح.');
    }
    if (!startDate || !endDate || endDate.getTime() < startDate.getTime()) {
      throw new HttpsError('invalid-argument', 'تاريخا بداية التحليل ونهايته غير صالحين.');
    }
    const spanDays = Math.floor((endDate.getTime() - startDate.getTime()) / 86_400_000) + 1;
    if (spanDays > MAX_RANGE_DAYS) {
      throw new HttpsError('invalid-argument', 'الفترة المطلوبة يجب ألا تتجاوز 366 يومًا.');
    }

    const db = getFirestore();
    const fieldRef = db.collection('users').doc(uid)
      .collection('satellite_fields').doc(fieldId);
    const fieldSnapshot = await fieldRef.get();
    if (!fieldSnapshot.exists) throw new HttpsError('not-found', 'الحقل المطلوب غير موجود.');
    let samplePoints: HlsPoint[];
    try {
      samplePoints = sampleHlsPoints(getFieldPolygon(fieldSnapshot.data() ?? {}));
    } catch {
      throw new HttpsError('invalid-argument', 'حدود الحقل غير صالحة للتحليل الفضائي.');
    }
    if (samplePoints.length > 9) {
      throw new HttpsError('invalid-argument', 'تعذر تحديد نقاط عينة مناسبة داخل الحقل.');
    }

    const runId = db.collection('hls_analysis_jobs').doc().id;
    const runRef = fieldRef.collection('analysis_runs').doc(runId);
    const jobRef = db.collection('hls_analysis_jobs').doc(runId);
    await Promise.all([
      runRef.create({
        status: 'pending',
        requestedStartDate: request.data['startDate'],
        requestedEndDate: request.data['endDate'],
        samplePointCount: samplePoints.length,
        createdAt: FieldValue.serverTimestamp(),
        source: 'NASA HLS/AppEEARS',
        requested_at: FieldValue.serverTimestamp(),
        start_date: request.data['startDate'],
        end_date: request.data['endDate'],
        sample_point_count: samplePoints.length,
        sources: ['NASA HLS/AppEEARS'],
        created_at: FieldValue.serverTimestamp(),
      }),
      jobRef.create({
        uid,
        fieldId,
        runId,
        samplePoints,
        status: 'starting',
        createdAt: FieldValue.serverTimestamp(),
      }),
    ]);

    try {
      const token = await getEarthdataToken(
        usernameAndPassword.username,
        usernameAndPassword.password,
      );
      const payload = buildTaskPayload(`hls-${runId}`, startDate, endDate, samplePoints);
      const task = await requestJson('/task', token, {
        method: 'POST',
        body: JSON.stringify(payload),
      });
      const nasaTaskId = getTaskId(task);
      if (!nasaTaskId || nasaTaskId.length > 256) throw new Error('Invalid AppEEARS task response');
      await jobRef.set({
        nasaTaskId,
        status: 'pending',
        startedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
      return { runId, status: 'pending', samplePointCount: samplePoints.length };
    } catch (error) {
      await markRunFailed(uid, fieldId, runId);
      if (error instanceof HttpsError) throw error;
      throw new HttpsError('unavailable', SAFE_FAILURE_ARABIC);
    }
  },
);

export const getHlsCropAnalysisStatus = onCall(
  {
    region: 'europe-west1',
    enforceAppCheck: true,
    timeoutSeconds: 540,
    secrets: [NASA_EARTHDATA_USERNAME, NASA_EARTHDATA_PASSWORD],
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', 'سجّل الدخول أولًا.');
    if (!isRecord(request.data)) {
      throw new HttpsError('invalid-argument', 'بيانات الاستعلام عن التحليل غير صالحة.');
    }
    const fieldId = request.data['fieldId'];
    const runId = request.data['runId'];
    if (!safeFieldId(fieldId) || !safeRunId(runId)) {
      throw new HttpsError('invalid-argument', 'معرّف الحقل أو التحليل غير صالح.');
    }

    const db = getFirestore();
    const fieldRef = db.collection('users').doc(uid)
      .collection('satellite_fields').doc(fieldId);
    const fieldSnapshot = await fieldRef.get();
    if (!fieldSnapshot.exists) throw new HttpsError('not-found', 'الحقل المطلوب غير موجود.');
    const runRef = fieldRef.collection('analysis_runs').doc(runId);
    const runSnapshot = await runRef.get();
    if (!runSnapshot.exists) throw new HttpsError('not-found', 'طلب التحليل غير موجود.');
    const visibleStatus = safeRunStatus(runSnapshot.get('status'));
    if (visibleStatus === 'completed' || visibleStatus === 'failed') {
      return { runId, status: visibleStatus };
    }

    const jobRef = db.collection('hls_analysis_jobs').doc(runId);
    const jobSnapshot = await jobRef.get();
    const job = readInternalJob(jobSnapshot.data());
    if (!job || job.uid !== uid || job.fieldId !== fieldId || job.runId !== runId || !job.nasaTaskId) {
      throw new HttpsError('permission-denied', 'لا تملك صلاحية الوصول إلى طلب التحليل هذا.');
    }
    const credentials = validateSecrets();
    let token: string;
    try {
      token = await getEarthdataToken(credentials.username, credentials.password);
    } catch {
      await markRunFailed(uid, fieldId, runId);
      throw new HttpsError('unavailable', SAFE_FAILURE_ARABIC);
    }
    return finishTask(uid, fieldId, runId, job.samplePoints, job.nasaTaskId, token);
  },
);
