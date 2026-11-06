import { FieldValue, Timestamp, getFirestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { defineSecret } from 'firebase-functions/params';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { buildHlsAreaRequest, parseHlsStatisticsCsv, type HlsVertex, type ParsedHlsSample } from './appeears';

const appeearsUsername = defineSecret('APPEEARS_USERNAME');
const appeearsPassword = defineSecret('APPEEARS_PASSWORD');
const APPEEARS_API = 'https://appeears.earthdatacloud.nasa.gov/api';
const MAX_STATS_FILE_BYTES = 5 * 1024 * 1024;
const MAX_POLYGON_VERTICES = 100;

class AppEearsSubmissionRejected extends Error {}

function getDb() {
  return getFirestore();
}

interface Vertex extends HlsVertex {}

function parseVertices(value: unknown): Vertex[] {
  if (!Array.isArray(value) || value.length < 3 || value.length > MAX_POLYGON_VERTICES) {
    throw new HttpsError('failed-precondition', 'حدود الحقل غير صالحة.');
  }
  return value.map((point): Vertex => {
    if (typeof point !== 'object' || point === null) {
      throw new HttpsError('failed-precondition', 'صيغة نقاط الحقل غير صالحة.');
    }
    const candidate = point as Record<string, unknown>;
    const lat = candidate.lat;
    const lng = candidate.lng;
    if (
      typeof lat !== 'number' || typeof lng !== 'number' ||
      !Number.isFinite(lat) || !Number.isFinite(lng) ||
      lat < -90 || lat > 90 || lng < -180 || lng > 180
    ) {
      throw new HttpsError('failed-precondition', 'إحداثيات الحقل خارج النطاق.');
    }
    return { lat, lng };
  });
}

function polygonAreaFeddan(vertices: Vertex[]): number {
  const radius = 6378137;
  let sum = 0;
  for (let index = 0; index < vertices.length; index += 1) {
    const current = vertices[index]!;
    const next = vertices[(index + 1) % vertices.length]!;
    const latitude1 = (current.lat * Math.PI) / 180;
    const latitude2 = (next.lat * Math.PI) / 180;
    const deltaLongitude = ((next.lng - current.lng) * Math.PI) / 180;
    sum += deltaLongitude * (2 + Math.sin(latitude1) + Math.sin(latitude2));
  }
  return Math.abs((sum * radius * radius) / 2) / 4200.833;
}

function assertActiveAccess(access: FirebaseFirestore.DocumentData | undefined): void {
  if (!access) throw new HttpsError('permission-denied', 'الخدمة غير مفعّلة.');
  const expiry = access.expiresAt;
  if (
    access.status !== 'active' || !(expiry instanceof Timestamp) ||
    expiry.toMillis() <= Date.now()
  ) {
    throw new HttpsError('permission-denied', 'انتهى تفعيل خدمة الأقمار.');
  }
}

async function readJson(response: Response): Promise<Record<string, unknown>> {
  const value: unknown = await response.json();
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw new Error('AppEEARS returned an invalid JSON response');
  }
  return value as Record<string, unknown>;
}

async function getAppEearsToken(): Promise<string> {
  const credentials = `${appeearsUsername.value()}:${appeearsPassword.value()}`;
  const response = await fetch(`${APPEEARS_API}/login`, {
    method: 'POST',
    headers: {
      Authorization: `Basic ${Buffer.from(credentials).toString('base64')}`,
      'Content-Length': '0',
    },
    signal: AbortSignal.timeout(20_000),
  });
  if (!response.ok) {
    logger.error('NASA AppEEARS login failed', { status: response.status });
    throw new Error('تعذر تسجيل الدخول إلى NASA AppEEARS. تحقق من أسرار Earthdata.');
  }
  const body = await readJson(response);
  if (typeof body.token !== 'string' || body.token.length < 20) {
    throw new Error('NASA AppEEARS لم يُرجع رمز وصول صالحاً.');
  }
  return body.token;
}

async function appeearsRequest(
  path: string,
  token: string,
  init: RequestInit = {},
): Promise<Response> {
  const response = await fetch(`${APPEEARS_API}${path}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: 'application/json',
      ...(init.body ? { 'Content-Type': 'application/json' } : {}),
      ...init.headers,
    },
    signal: init.signal ?? AbortSignal.timeout(60_000),
  });
  return response;
}

async function submitHlsTask(
  vertices: Vertex[],
  fieldName: string,
  taskName: string,
  token: string,
): Promise<string> {
  const now = new Date();
  const payload = buildHlsAreaRequest(vertices, taskName, now);
  payload.params.geo.fileName = fieldName
    .replace(/[^\p{L}\p{N}_-]/gu, '_')
    .slice(0, 40) || 'NabatiField';

  const response = await appeearsRequest('/task', token, {
    method: 'POST',
    body: JSON.stringify(payload),
    signal: AbortSignal.timeout(45_000),
  });
  if (!response.ok) {
    const errorText = (await response.text()).slice(0, 1000);
    logger.error('NASA AppEEARS task submission failed', {
      status: response.status,
      response: errorText,
    });
    if (response.status >= 400 && response.status < 500) {
      throw new AppEearsSubmissionRejected('NASA AppEEARS rejected the task request');
    }
    throw new Error('NASA AppEEARS submission returned an ambiguous server error.');
  }
  const body = await readJson(response);
  if (typeof body.task_id !== 'string' || body.task_id.length < 20) {
    throw new Error('لم تُرجع NASA AppEEARS معرّف المهمة.');
  }
  return body.task_id;
}

function combineSameDay(samples: ParsedHlsSample[]): ParsedHlsSample[] {
  const groups = new Map<string, ParsedHlsSample[]>();
  for (const sample of samples) {
    const key = sample.from.slice(0, 10);
    const group = groups.get(key) ?? [];
    group.push(sample);
    groups.set(key, group);
  }
  return [...groups.values()].map((group) => {
    const totalCount = group.reduce((sum, sample) => sum + sample.sampleCount, 0);
    const weightedMean = totalCount > 0
      ? group.reduce((sum, sample) => sum + sample.mean * sample.sampleCount, 0) / totalCount
      : group.reduce((sum, sample) => sum + sample.mean, 0) / group.length;
    const date = group[0]!.from.slice(0, 10);
    const from = new Date(`${date}T00:00:00.000Z`);
    const to = new Date(from.getTime() + 24 * 60 * 60 * 1000);
    return {
      mean: weightedMean,
      stDev: group.reduce((sum, sample) => sum + sample.stDev, 0) / group.length,
      sampleCount: totalCount,
      from: from.toISOString(),
      to: to.toISOString(),
    };
  }).sort((left, right) => left.from.localeCompare(right.from));
}

async function fetchTaskSamples(taskId: string, token: string): Promise<ParsedHlsSample[]> {
  const bundleResponse = await appeearsRequest(`/bundle/${encodeURIComponent(taskId)}`, token);
  if (!bundleResponse.ok) {
    throw new Error(`تعذر قراءة حزمة NASA AppEEARS (${bundleResponse.status}).`);
  }
  const bundle = await readJson(bundleResponse);
  if (!Array.isArray(bundle.files)) throw new Error('حزمة NASA AppEEARS لا تحتوي قائمة ملفات.');

  const statsFiles = bundle.files.filter((item: unknown) => {
    if (typeof item !== 'object' || item === null) return false;
    const file = item as Record<string, unknown>;
    const name = typeof file.file_name === 'string' ? file.file_name.toLowerCase() : '';
    return typeof file.file_id === 'string' &&
      name.includes('statistics.csv') && !/statistics[-_ ]?qa/.test(name);
  }) as Array<Record<string, unknown>>;
  if (statsFiles.length === 0) {
    throw new Error('اكتملت مهمة NASA لكن لم يظهر ملف إحصاءات NDVI.');
  }

  const samples: ParsedHlsSample[] = [];
  for (const file of statsFiles) {
    const fileId = file.file_id as string;
    if (typeof file.file_size === 'number' && file.file_size > MAX_STATS_FILE_BYTES) {
      throw new Error('تجاوز ملف إحصاءات NASA الحد الآمن للقراءة.');
    }
    const response = await appeearsRequest(
      `/bundle/${encodeURIComponent(taskId)}/${encodeURIComponent(fileId)}`,
      token,
      { headers: { Accept: 'text/csv,application/octet-stream' }, signal: AbortSignal.timeout(60_000) },
    );
    if (!response.ok) throw new Error(`تعذر تنزيل إحصاءات NASA (${response.status}).`);
    const text = await response.text();
    if (Buffer.byteLength(text, 'utf8') > MAX_STATS_FILE_BYTES) {
      throw new Error('ملف إحصاءات NASA أكبر من الحد الآمن للقراءة.');
    }
    samples.push(...parseHlsStatisticsCsv(text));
  }
  return combineSameDay(samples);
}

function appEearsStatus(body: Record<string, unknown>): string {
  return typeof body.status === 'string' ? body.status.toLowerCase() : 'unknown';
}

function addDays(date: Date, days: number): Date {
  return new Date(date.getTime() + days * 24 * 60 * 60 * 1000);
}

async function failJob(
  jobRef: FirebaseFirestore.DocumentReference,
  reason: string,
  refundQuota: boolean,
): Promise<void> {
  await getDb().runTransaction(async (transaction) => {
    const jobSnapshot = await transaction.get(jobRef);
    if (!jobSnapshot.exists || jobSnapshot.get('status') === 'done' || jobSnapshot.get('status') === 'failed') return;
    const job = jobSnapshot.data()!;
    const fieldRef = getDb().collection('satellite_fields').doc(String(job.fieldId));
    const accessRef = getDb().collection('satellite_access').doc(String(job.uid));
    const [fieldSnapshot, accessSnapshot] = await Promise.all([
      transaction.get(fieldRef),
      transaction.get(accessRef),
    ]);
    transaction.update(jobRef, {
      status: 'failed',
      error: reason,
      completedAt: FieldValue.serverTimestamp(),
      nextPollAt: FieldValue.delete(),
    });
    if (fieldSnapshot.exists && fieldSnapshot.get('lastNdviJobId') === jobRef.id) {
      transaction.update(fieldRef, {
        lastAnalysisStatus: 'failed',
        lastAnalysisError: reason,
      });
    }
    const access = accessSnapshot.data();
    if (
      refundQuota && !job.quotaRefunded && accessSnapshot.exists && access &&
      access?.analysisPeriod === job.analysisPeriod
    ) {
      const count = Math.max(0, Number(access.analysisCount ?? 0) - 1);
      transaction.update(accessRef, { analysisCount: count });
      transaction.update(jobRef, { quotaRefunded: true });
    }
  });
}

async function completeJob(
  jobRef: FirebaseFirestore.DocumentReference,
  samples: ParsedHlsSample[],
): Promise<void> {
  await getDb().runTransaction(async (transaction) => {
    const jobSnapshot = await transaction.get(jobRef);
    if (!jobSnapshot.exists || jobSnapshot.get('status') !== 'submitted') return;
    const job = jobSnapshot.data()!;
    const fieldRef = getDb().collection('satellite_fields').doc(String(job.fieldId));
    const accessRef = getDb().collection('satellite_access').doc(String(job.uid));
    const fieldSnapshot = await transaction.get(fieldRef);
    const accessSnapshot = await transaction.get(accessRef);
    if (!fieldSnapshot.exists || fieldSnapshot.get('uid') !== job.uid) {
      transaction.update(jobRef, {
        status: 'failed',
        error: 'الحقل المرتبط بمهمة NASA لم يعد متاحاً.',
        completedAt: FieldValue.serverTimestamp(),
        nextPollAt: FieldValue.delete(),
      });
      const access = accessSnapshot.data();
      if (
        !job.quotaRefunded && accessSnapshot.exists && access &&
        access.analysisPeriod === job.analysisPeriod
      ) {
        transaction.update(accessRef, {
          analysisCount: Math.max(0, Number(access.analysisCount ?? 0) - 1),
        });
        transaction.update(jobRef, { quotaRefunded: true });
      }
      return;
    }

    for (const sample of samples) {
      const dayId = sample.from.slice(0, 10);
      const historyRef = fieldRef.collection('ndvi_history').doc(dayId);
      transaction.set(historyRef, {
        ...sample,
        from: Timestamp.fromDate(new Date(sample.from)),
        to: Timestamp.fromDate(new Date(sample.to)),
        source: 'NASA HLS-VI (Sentinel-2 + Landsat) via AppEEARS',
        createdAt: FieldValue.serverTimestamp(),
      });
    }
    const latest = samples[samples.length - 1];
    if (fieldSnapshot.get('lastNdviJobId') === jobRef.id) {
      transaction.update(fieldRef, {
        lastAnalyzedAt: FieldValue.serverTimestamp(),
        lastAnalysisStatus: samples.length > 0 ? 'ready' : 'no_valid_scenes',
        lastAnalysisError: FieldValue.delete(),
        lastNdvi: latest?.mean ?? null,
        lastNdviIntervalFrom: latest ? Timestamp.fromDate(new Date(latest.from)) : null,
        lastNdviIntervalTo: latest ? Timestamp.fromDate(new Date(latest.to)) : null,
        lastNdviJobId: FieldValue.delete(),
      });
    }
    transaction.update(jobRef, {
      status: 'done',
      resultCount: samples.length,
      completedAt: FieldValue.serverTimestamp(),
      nextPollAt: FieldValue.delete(),
      error: FieldValue.delete(),
    });
  });
}

async function pollJob(jobRef: FirebaseFirestore.DocumentReference, token: string): Promise<void> {
  const snapshot = await jobRef.get();
  if (!snapshot.exists || snapshot.get('status') !== 'submitted') return;
  const job = snapshot.data()!;
  const taskId = typeof job.taskId === 'string' ? job.taskId : '';
  const createdAt = job.createdAt instanceof Timestamp ? job.createdAt.toDate() : new Date();
  if (!taskId) {
    await failJob(jobRef, 'لم يُحفظ معرّف مهمة NASA بصورة صحيحة.', true);
    return;
  }
  if (Date.now() - createdAt.getTime() > 72 * 60 * 60 * 1000) {
    await failJob(jobRef, 'انتهت مهلة معالجة NASA AppEEARS بعد 72 ساعة.', true);
    return;
  }

  const response = await appeearsRequest(`/task/${encodeURIComponent(taskId)}`, token, {
    signal: AbortSignal.timeout(30_000),
  });
  if (!response.ok) {
    if (response.status === 404 || response.status === 410) {
      await failJob(jobRef, 'لم تعد مهمة NASA متاحة؛ أُعيدت الحصة إلى الاشتراك.', true);
      return;
    }
    throw new Error(`NASA AppEEARS task status returned HTTP ${response.status}`);
  }
  const state = appEearsStatus(await readJson(response));
  if (state === 'done') {
    const samples = await fetchTaskSamples(taskId, token);
    await completeJob(jobRef, samples);
    return;
  }
  if (state === 'error' || state === 'failed' || state === 'cancelled') {
    await failJob(jobRef, 'تعذر على NASA إكمال معالجة بيانات HLS؛ أُعيدت الحصة.', true);
    return;
  }
  await jobRef.update({
    lastPolledAt: FieldValue.serverTimestamp(),
    nextPollAt: Timestamp.fromDate(addDays(new Date(), 5 / (24 * 60))),
    nasaStatus: state,
  });
}

async function listRecentAppEearsTasks(token: string): Promise<Record<string, unknown>[]> {
  const response = await appeearsRequest('/task?limit=100&offset=0', token);
  if (!response.ok) throw new Error(`AppEEARS task list returned HTTP ${response.status}`);
  const body: unknown = await response.json();
  if (Array.isArray(body)) {
    return body.filter((item) => typeof item === 'object' && item !== null) as Record<string, unknown>[];
  }
  if (typeof body === 'object' && body !== null) {
    const object = body as Record<string, unknown>;
    for (const key of ['tasks', 'data', 'results']) {
      const list = object[key];
      if (Array.isArray(list)) {
        return list.filter((item) => typeof item === 'object' && item !== null) as Record<string, unknown>[];
      }
    }
    if (typeof object.task_id === 'string') return [object];
  }
  throw new Error('AppEEARS task list has an unexpected response format');
}

async function deferJobOrFail(
  jobRef: FirebaseFirestore.DocumentReference,
  jobSnapshot: FirebaseFirestore.QueryDocumentSnapshot,
  reason: string,
): Promise<void> {
  const attempts = Number(jobSnapshot.get('pollAttempts') ?? 0) + 1;
  if (attempts >= 12) {
    await failJob(jobRef, reason, true);
  } else {
    await jobRef.update({
      pollAttempts: attempts,
      nextPollAt: Timestamp.fromDate(addDays(new Date(), 15 / (24 * 60))),
    });
  }
}

async function reconcileSubmittingJob(
  job: FirebaseFirestore.QueryDocumentSnapshot,
  recentTasks: Record<string, unknown>[],
  token: string,
): Promise<void> {
  const taskName = job.get('taskName');
  const createdAt = job.get('createdAt');
  const matchingTask = typeof taskName === 'string'
    ? recentTasks.find((task) => task.task_name === taskName)
    : undefined;
  if (matchingTask && typeof matchingTask.task_id === 'string') {
    await job.ref.update({
      status: 'submitted',
      taskId: matchingTask.task_id,
      submittedAt: FieldValue.serverTimestamp(),
      reconciledAt: FieldValue.serverTimestamp(),
      pollAttempts: 0,
      nextPollAt: Timestamp.now(),
    });
    await pollJob(job.ref, token);
    return;
  }

  const ageMs = createdAt instanceof Timestamp ? Date.now() - createdAt.toMillis() : 0;
  if (ageMs >= 30 * 60 * 1000) {
    await failJob(
      job.ref,
      'لم يظهر طلب NASA بعد التحقق؛ أُعيدت الحصة إلى الاشتراك.',
      true,
    );
    return;
  }
  await job.ref.update({ nextPollAt: Timestamp.fromDate(addDays(new Date(), 5 / (24 * 60))) });
}

export const saveSatelliteField = onCall(
  {
    region: 'europe-west1',
    enforceAppCheck: true,
    timeoutSeconds: 30,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', 'سجل الدخول أولاً.');
    const name = typeof request.data?.name === 'string' ? request.data.name.trim() : '';
    const fieldId = typeof request.data?.fieldId === 'string' ? request.data.fieldId.trim() : '';
    if (!name || name.length > 120 || fieldId.includes('/') || fieldId.length > 180) {
      throw new HttpsError('invalid-argument', 'اسم الحقل أو معرّفه غير صالح.');
    }
    const vertices = parseVertices(request.data?.vertices);
    const areaFeddan = polygonAreaFeddan(vertices);
    if (!Number.isFinite(areaFeddan) || areaFeddan <= 0 || areaFeddan > 100000) {
      throw new HttpsError('failed-precondition', 'مساحة الحدود غير صالحة.');
    }

    const accessRef = getDb().collection('satellite_access').doc(uid);
    const fieldsQuery = getDb().collection('satellite_fields').where('uid', '==', uid);
    const targetRef = fieldId
      ? getDb().collection('satellite_fields').doc(fieldId)
      : getDb().collection('satellite_fields').doc();

    await getDb().runTransaction(async (transaction) => {
      const [accessSnapshot, fieldsSnapshot, targetSnapshot] = await Promise.all([
        transaction.get(accessRef),
        transaction.get(fieldsQuery),
        fieldId ? transaction.get(targetRef) : Promise.resolve(null),
      ]);
      const access = accessSnapshot.data();
      assertActiveAccess(access);
      const existingField = targetSnapshot?.data();
      if (fieldId && (!targetSnapshot?.exists || existingField?.uid !== uid)) {
        throw new HttpsError('permission-denied', 'هذا الحقل لا يتبع حسابك.');
      }
      if (existingField?.deleting === true) {
        throw new HttpsError('failed-precondition', 'يجري حذف هذا الحقل حالياً.');
      }
      const maxFields = Number(access?.maxFields);
      if (!Number.isInteger(maxFields) || maxFields < 1) {
        throw new HttpsError('failed-precondition', 'لا يوجد حد حقول صالح للاشتراك.');
      }
      const maxAreaFeddan = Number(access?.maxAreaFeddan);
      if (!Number.isFinite(maxAreaFeddan) || maxAreaFeddan <= 0) {
        throw new HttpsError('failed-precondition', 'لا يوجد حد مساحة صالح للاشتراك.');
      }
      if (areaFeddan > maxAreaFeddan) {
        throw new HttpsError('resource-exhausted', `تتجاوز مساحة الحقل حد اشتراكك (${maxAreaFeddan} فدان).`);
      }
      if (!fieldId && fieldsSnapshot.size >= maxFields) {
        throw new HttpsError('resource-exhausted', 'وصلت إلى الحد الأقصى لعدد الحقول في اشتراكك.');
      }
      const data = { uid, name, vertices, areaFeddan, updatedAt: FieldValue.serverTimestamp() };
      if (fieldId) transaction.update(targetRef, data);
      else {
        transaction.set(targetRef, { ...data, createdAt: FieldValue.serverTimestamp() });
        // كتابة المستند المشترك تجعل إنشاء الحقول المتزامن يتعارض ويُعاد فحص الحد.
        transaction.update(accessRef, { fieldCount: fieldsSnapshot.size + 1 });
      }
    });
    return { fieldId: targetRef.id, areaFeddan };
  },
);

export const deleteSatelliteField = onCall(
  { region: 'europe-west1', enforceAppCheck: true, timeoutSeconds: 60 },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', 'سجل الدخول أولاً.');
    const fieldId = typeof request.data?.fieldId === 'string' ? request.data.fieldId.trim() : '';
    if (!fieldId || fieldId.length > 180 || fieldId.includes('/')) {
      throw new HttpsError('invalid-argument', 'معرّف الحقل غير صالح.');
    }
    const db = getDb();
    const fieldRef = db.collection('satellite_fields').doc(fieldId);
    const accessRef = db.collection('satellite_access').doc(uid);
    const fieldsQuery = db.collection('satellite_fields').where('uid', '==', uid);
    await db.runTransaction(async (transaction) => {
      const [fieldSnapshot, accessSnapshot, fieldsSnapshot] = await Promise.all([
        transaction.get(fieldRef),
        transaction.get(accessRef),
        transaction.get(fieldsQuery),
      ]);
      if (!fieldSnapshot.exists || fieldSnapshot.get('uid') !== uid) {
        throw new HttpsError('permission-denied', 'هذا الحقل لا يتبع حسابك.');
      }
      if (fieldSnapshot.get('deleting') === true) return;
      if (accessSnapshot.exists) {
        transaction.update(accessRef, { fieldCount: Math.max(0, fieldsSnapshot.size - 1) });
      }
      transaction.update(fieldRef, {
        deleting: true,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
    await db.recursiveDelete(fieldRef);
    return { deleted: true };
  },
);

export const requestSatelliteNdvi = onCall(
  {
    region: 'europe-west1',
    enforceAppCheck: true,
    timeoutSeconds: 90,
    memory: '512MiB',
    maxInstances: 5,
    secrets: [appeearsUsername, appeearsPassword],
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', 'سجل الدخول أولاً.');
    const fieldId = typeof request.data?.fieldId === 'string' ? request.data.fieldId.trim() : '';
    if (!fieldId || fieldId.length > 180 || fieldId.includes('/')) {
      throw new HttpsError('invalid-argument', 'معرّف الحقل غير صالح.');
    }

    const db = getDb();
    const accessRef = db.collection('satellite_access').doc(uid);
    const fieldRef = db.collection('satellite_fields').doc(fieldId);
    const jobRef = db.collection('satellite_ndvi_jobs').doc();
    const taskName = `nabati-${jobRef.id}-${fieldId.slice(0, 8)}`;
    const currentPeriod = new Date().toISOString().slice(0, 7);
    let vertices: Vertex[] = [];
    let fieldName = '';
    let alreadyProcessing = false;

    await db.runTransaction(async (transaction) => {
      const [accessSnapshot, fieldSnapshot] = await Promise.all([
        transaction.get(accessRef),
        transaction.get(fieldRef),
      ]);
      if (!accessSnapshot.exists || !fieldSnapshot.exists) {
        throw new HttpsError('not-found', 'الاشتراك أو الحقل غير موجود.');
      }
      const access = accessSnapshot.data()!;
      const field = fieldSnapshot.data()!;
      assertActiveAccess(access);
      if (field.uid !== uid) throw new HttpsError('permission-denied', 'هذا الحقل لا يتبع حسابك.');

      const lastStatus = field.lastAnalysisStatus;
      const lastRequested = field.lastAnalysisRequestedAt;
      const requestAge = lastRequested instanceof Timestamp
        ? Date.now() - lastRequested.toMillis()
        : Number.POSITIVE_INFINITY;
      if (lastStatus === 'processing' && requestAge < 72 * 60 * 60 * 1000) {
        alreadyProcessing = true;
        return;
      }

      const limit = Number(access.maxAnalysesPerMonth);
      if (!Number.isInteger(limit) || limit < 1) {
        throw new HttpsError('failed-precondition', 'لا يوجد حد تحليلات مفعل للاشتراك.');
      }
      const count = access.analysisPeriod === currentPeriod ? Number(access.analysisCount ?? 0) : 0;
      if (count >= limit) {
        throw new HttpsError('resource-exhausted', 'استهلكت عدد تحليلات NDVI المتاح لهذا الشهر.');
      }
      vertices = parseVertices(field.vertices);
      fieldName = typeof field.name === 'string' ? field.name : 'حقل نباتي';
      transaction.update(accessRef, {
        analysisPeriod: currentPeriod,
        analysisCount: count + 1,
        lastAnalysisRequestedAt: FieldValue.serverTimestamp(),
      });
      transaction.set(jobRef, {
        uid,
        fieldId,
        taskName,
        status: 'submitting',
        analysisPeriod: currentPeriod,
        quotaRefunded: false,
        createdAt: FieldValue.serverTimestamp(),
        nextPollAt: Timestamp.fromDate(addDays(new Date(), 5 / (24 * 60))),
      });
      transaction.update(fieldRef, {
        lastAnalysisStatus: 'processing',
        lastAnalysisError: FieldValue.delete(),
        lastAnalysisRequestedAt: FieldValue.serverTimestamp(),
        lastNdviJobId: jobRef.id,
      });
    });

    if (alreadyProcessing) return { status: 'processing', source: 'NASA HLS-VI' };

    let token: string;
    try {
      token = await getAppEearsToken();
    } catch (error) {
      logger.error('NASA AppEEARS login failed before submission', {
        uid,
        error: error instanceof Error ? error.message : 'unknown',
      });
      await failJob(jobRef, 'تعذر تسجيل الدخول إلى NASA؛ أُعيدت الحصة.', true);
      throw new HttpsError(
        'unavailable',
        'تعذر الاتصال بحساب NASA Earthdata؛ لم تُخصم الحصة. راجع إعداد الأسرار وحاول لاحقاً.',
      );
    }

    try {
      const taskId = await submitHlsTask(vertices, fieldName, taskName, token);
      await jobRef.update({
        status: 'submitted',
        taskId,
        submittedAt: FieldValue.serverTimestamp(),
        nextPollAt: Timestamp.fromDate(addDays(new Date(), 5 / (24 * 60))),
      });
      return { status: 'processing', source: 'NASA HLS-VI' };
    } catch (error) {
      if (error instanceof AppEearsSubmissionRejected) {
        await failJob(jobRef, 'رفضت NASA طلب التحليل؛ أُعيدت الحصة.', true);
        throw new HttpsError(
          'unavailable',
          'رفضت NASA طلب التحليل؛ لم تُخصم الحصة. راجع بيانات Earthdata أو حاول لاحقاً.',
        );
      }
      logger.error('NASA HLS task submission failed', {
        uid,
        error: error instanceof Error ? error.message : 'unknown',
      });
      return {
        status: 'processing',
        source: 'NASA HLS-VI',
        confirmationPending: true,
      };
    }
  },
);

export const processSatelliteNdviJobs = onSchedule(
  {
    schedule: 'every 5 minutes',
    timeZone: 'UTC',
    region: 'europe-west1',
    timeoutSeconds: 540,
    memory: '512MiB',
    maxInstances: 1,
    secrets: [appeearsUsername, appeearsPassword],
  },
  async () => {
    const db = getDb();
    const jobs = db.collection('satellite_ndvi_jobs');
    const now = Timestamp.now();
    const [dueSubmitted, dueSubmitting] = await Promise.all([
      jobs
      .where('status', '==', 'submitted')
      .where('nextPollAt', '<=', now)
      .limit(5)
      .get(),
      jobs
        .where('status', '==', 'submitting')
        .where('nextPollAt', '<=', now)
        .limit(5)
        .get(),
    ]);
    if (dueSubmitted.empty && dueSubmitting.empty) return;

    const isExpired = (job: FirebaseFirestore.QueryDocumentSnapshot): boolean => {
      const createdAt = job.get('createdAt');
      return createdAt instanceof Timestamp &&
        Date.now() - createdAt.toMillis() > 72 * 60 * 60 * 1000;
    };
    for (const job of [...dueSubmitted.docs, ...dueSubmitting.docs]) {
      if (isExpired(job)) {
        await failJob(job.ref, 'انتهت مهلة NASA AppEEARS بعد 72 ساعة؛ أُعيدت الحصة.', true);
      }
    }
    const submittedJobs = dueSubmitted.docs.filter((job) => !isExpired(job));
    const submittingJobs = dueSubmitting.docs.filter((job) => !isExpired(job));
    if (submittedJobs.length === 0 && submittingJobs.length === 0) return;

    let token: string;
    try {
      token = await getAppEearsToken();
    } catch (error) {
      logger.error('NASA AppEEARS polling login failed', {
        error: error instanceof Error ? error.message : 'unknown',
      });
      for (const job of [...submittedJobs, ...submittingJobs]) {
        await deferJobOrFail(
          job.ref,
          job,
          'تعذر تسجيل الدخول إلى NASA بعد محاولات متعددة؛ أُعيدت الحصة.',
        );
      }
      return;
    }

    for (const job of submittedJobs) {
      try {
        await pollJob(job.ref, token);
      } catch (error) {
        logger.warn('NASA HLS task poll failed', {
          jobId: job.id,
          error: error instanceof Error ? error.message : 'unknown',
        });
        await deferJobOrFail(
          job.ref,
          job,
          'تعذر استلام نتيجة NASA بعد عدة محاولات؛ أُعيدت الحصة.',
        );
      }
    }

    if (submittingJobs.length > 0) {
      let recentTasks: Record<string, unknown>[];
      try {
        recentTasks = await listRecentAppEearsTasks(token);
      } catch (error) {
        logger.warn('NASA AppEEARS task reconciliation failed', {
          error: error instanceof Error ? error.message : 'unknown',
        });
        for (const job of submittingJobs) {
          await deferJobOrFail(
            job.ref,
            job,
            'تعذر التحقق من قبول NASA AppEEARS بعد عدة محاولات؛ أُعيدت الحصة.',
          );
        }
        return;
      }
      for (const job of submittingJobs) {
        try {
          await reconcileSubmittingJob(job, recentTasks, token);
        } catch (error) {
          logger.warn('NASA AppEEARS submission reconciliation failed', {
            jobId: job.id,
            error: error instanceof Error ? error.message : 'unknown',
          });
          await deferJobOrFail(
            job.ref,
            job,
            'تعذر التحقق من قبول NASA AppEEARS بعد عدة محاولات؛ أُعيدت الحصة.',
          );
        }
      }
    }
  },
);
