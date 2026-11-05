import { FieldValue, Timestamp, getFirestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { defineSecret } from 'firebase-functions/params';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

const sentinelClientId = defineSecret('SENTINEL_HUB_CLIENT_ID');
const sentinelClientSecret = defineSecret('SENTINEL_HUB_CLIENT_SECRET');
function getDb() {
  return getFirestore();
}
const SENTINEL_TOKEN_URL =
  'https://services.sentinel-hub.com/auth/realms/main/protocol/openid-connect/token';
const SENTINEL_STATS_URL =
  'https://services.sentinel-hub.com/api/v1/statistics';

interface Vertex {
  lat: number;
  lng: number;
}

interface NdviStats {
  mean: number;
  stDev: number;
  sampleCount: number;
  noDataCount: number;
}

interface NdviInterval {
  interval?: { from?: string; to?: string };
  outputs?: {
    ndvi?: { bands?: { B0?: { stats?: NdviStats } } };
  };
}

function parseVertices(value: unknown): Vertex[] {
  if (!Array.isArray(value) || value.length < 3 || value.length > 100) {
    throw new HttpsError('failed-precondition', 'حدود الحقل غير صالحة.');
  }
  const points = value.map((point): Vertex => {
    if (typeof point !== 'object' || point === null) {
      throw new HttpsError('failed-precondition', 'صيغة نقاط الحقل غير صالحة.');
    }
    const candidate = point as Record<string, unknown>;
    const lat = candidate.lat;
    const lng = candidate.lng;
    if (
      typeof lat !== 'number' ||
      typeof lng !== 'number' ||
      !Number.isFinite(lat) ||
      !Number.isFinite(lng) ||
      lat < -90 ||
      lat > 90 ||
      lng < -180 ||
      lng > 180
    ) {
      throw new HttpsError('failed-precondition', 'إحداثيات الحقل خارج النطاق.');
    }
    return { lat, lng };
  });
  return points;
}

async function readJson(response: Response): Promise<Record<string, unknown>> {
  const value: unknown = await response.json();
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw new Error('Sentinel Hub returned an invalid JSON response');
  }
  return value as Record<string, unknown>;
}

async function getSentinelAccessToken(): Promise<string> {
  const response = await fetch(SENTINEL_TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'client_credentials',
      client_id: sentinelClientId.value(),
      client_secret: sentinelClientSecret.value(),
    }),
    signal: AbortSignal.timeout(20_000),
  });
  if (!response.ok) {
    logger.error('Sentinel Hub OAuth request failed', { status: response.status });
    throw new HttpsError(
      'unavailable',
      'تعذر الاتصال بخدمة صور الأقمار الصناعية. حاول لاحقاً.',
    );
  }
  const body = await readJson(response);
  if (typeof body.access_token !== 'string' || body.access_token.length === 0) {
    throw new HttpsError('unavailable', 'لم تُرجع خدمة الأقمار رمز وصول صالحاً.');
  }
  return body.access_token;
}

function ndviEvalscript(): string {
  return `//VERSION=3
function setup() {
  return {
    input: [{ bands: ['B04', 'B08', 'SCL', 'dataMask'] }],
    output: [
      { id: 'ndvi', bands: 1, sampleType: 'FLOAT32' },
      { id: 'dataMask', bands: 1 }
    ]
  };
}
function evaluatePixel(sample) {
  const denominator = sample.B08 + sample.B04;
  const sceneClass = sample.SCL;
  const cloudOrInvalid = sceneClass === 0 || sceneClass === 1 ||
    sceneClass === 3 || sceneClass === 6 || sceneClass === 7 ||
    sceneClass === 8 || sceneClass === 9 || sceneClass === 10 ||
    sceneClass === 11;
  const valid = sample.dataMask === 1 && !cloudOrInvalid && denominator > 0;
  const value = valid ? (sample.B08 - sample.B04) / denominator : 0;
  return { ndvi: [value], dataMask: [valid ? 1 : 0] };
}`;
}

async function fetchNdviStatistics(vertices: Vertex[]): Promise<NdviInterval[]> {
  const now = new Date();
  const from = new Date(now.getTime() - 90 * 24 * 60 * 60 * 1000);
  const ring = vertices.map((point) => [point.lng, point.lat]);
  const first = ring[0];
  const last = ring[ring.length - 1];
  if (first === undefined || last === undefined) {
    throw new HttpsError('failed-precondition', 'لا توجد حدود قابلة للتحليل.');
  }
  if (first[0] !== last[0] || first[1] !== last[1]) ring.push([...first]);

  const token = await getSentinelAccessToken();
  const body = {
    input: {
      bounds: { geometry: { type: 'Polygon', coordinates: [ring] } },
      data: [
        {
          type: 'sentinel-2-l2a',
          dataFilter: { maxCloudCoverage: 40, mosaickingOrder: 'leastCC' },
        },
      ],
    },
    aggregation: {
      timeRange: { from: from.toISOString(), to: now.toISOString() },
      aggregationInterval: { of: 'P15D' },
      lastIntervalBehavior: 'SHORTEN',
      evalscript: ndviEvalscript(),
      resx: 10,
      resy: 10,
    },
  };

  const response = await fetch(SENTINEL_STATS_URL, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      Accept: 'application/json',
    },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(90_000),
  });
  if (!response.ok) {
    logger.error('Sentinel Hub Statistical API failed', { status: response.status });
    if (response.status === 429) {
      throw new HttpsError(
        'resource-exhausted',
        'وصلت خدمة الأقمار إلى حد الطلبات مؤقتاً. حاول لاحقاً.',
      );
    }
    throw new HttpsError(
      'unavailable',
      'تعذر استخراج مؤشر NDVI من صور Sentinel‑2 حالياً.',
    );
  }
  const result = await readJson(response);
  if (!Array.isArray(result.data)) {
    throw new HttpsError('unavailable', 'استجابة صور الأقمار غير مكتملة.');
  }
  return result.data as NdviInterval[];
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
    access.status !== 'active' ||
    !(expiry instanceof Timestamp) ||
    expiry.toMillis() <= Date.now()
  ) {
    throw new HttpsError('permission-denied', 'انتهى تفعيل خدمة الأقمار.');
  }
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
    const name = typeof request.data?.name === 'string'
      ? request.data.name.trim()
      : '';
    const fieldId = typeof request.data?.fieldId === 'string'
      ? request.data.fieldId.trim()
      : '';
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
      const maxFields = Number(access?.maxFields);
      if (!Number.isInteger(maxFields) || maxFields < 1) {
        throw new HttpsError('failed-precondition', 'لا يوجد حد حقول صالح للاشتراك.');
      }
      const maxAreaFeddan = Number(access?.maxAreaFeddan);
      if (!Number.isFinite(maxAreaFeddan) || maxAreaFeddan <= 0) {
        throw new HttpsError('failed-precondition', 'لا يوجد حد مساحة صالح للاشتراك.');
      }
      if (areaFeddan > maxAreaFeddan) {
        throw new HttpsError(
          'resource-exhausted',
          `تتجاوز مساحة الحقل حد اشتراكك (${maxAreaFeddan} فدان).`,
        );
      }
      if (!fieldId && fieldsSnapshot.size >= maxFields) {
        throw new HttpsError(
          'resource-exhausted',
          'وصلت إلى الحد الأقصى لعدد الحقول في اشتراكك.',
        );
      }
      const data = {
        uid,
        name,
        vertices,
        areaFeddan,
        updatedAt: FieldValue.serverTimestamp(),
      };
      if (fieldId) {
        transaction.update(targetRef, data);
      } else {
        transaction.set(targetRef, {
          ...data,
          createdAt: FieldValue.serverTimestamp(),
        });
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
    const fieldId =
      typeof request.data?.fieldId === 'string' ? request.data.fieldId.trim() : '';
    if (!fieldId || fieldId.length > 180 || fieldId.includes('/')) {
      throw new HttpsError('invalid-argument', 'معرّف الحقل غير صالح.');
    }
    const fieldRef = getDb().collection('satellite_fields').doc(fieldId);
    const snapshot = await fieldRef.get();
    if (!snapshot.exists || snapshot.get('uid') !== uid) {
      throw new HttpsError('permission-denied', 'هذا الحقل لا يتبع حسابك.');
    }
    await getDb().recursiveDelete(fieldRef);
    return { deleted: true };
  },
);

export const requestSatelliteNdvi = onCall(
  {
    region: 'europe-west1',
    enforceAppCheck: true,
    timeoutSeconds: 120,
    memory: '512MiB',
    maxInstances: 5,
    secrets: [sentinelClientId, sentinelClientSecret],
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', 'سجل الدخول أولاً.');

    const fieldId =
      typeof request.data?.fieldId === 'string' ? request.data.fieldId.trim() : '';
    if (!fieldId || fieldId.length > 180 || fieldId.includes('/')) {
      throw new HttpsError('invalid-argument', 'معرّف الحقل غير صالح.');
    }

    const accessRef = getDb().collection('satellite_access').doc(uid);
    const fieldRef = getDb().collection('satellite_fields').doc(fieldId);
    const currentPeriod = new Date().toISOString().slice(0, 7);
    let vertices: Vertex[] = [];

    // حجز حصة التحليل ذرياً قبل الاتصال بالمزود لمنع السباق بين الأجهزة.
    await getDb().runTransaction(async (transaction) => {
      const [accessSnapshot, fieldSnapshot] = await Promise.all([
        transaction.get(accessRef),
        transaction.get(fieldRef),
      ]);
      if (!accessSnapshot.exists || !fieldSnapshot.exists) {
        throw new HttpsError('not-found', 'الاشتراك أو الحقل غير موجود.');
      }
      const access = accessSnapshot.data()!;
      const field = fieldSnapshot.data()!;
      const expiry = access.expiresAt;
      if (
        access.status !== 'active' ||
        !(expiry instanceof Timestamp) ||
        expiry.toMillis() <= Date.now()
      ) {
        throw new HttpsError('permission-denied', 'انتهى تفعيل خدمة الأقمار.');
      }
      if (field.uid !== uid) {
        throw new HttpsError('permission-denied', 'هذا الحقل لا يتبع حسابك.');
      }
      const limit = Number(access.maxAnalysesPerMonth);
      if (!Number.isInteger(limit) || limit < 1) {
        throw new HttpsError('failed-precondition', 'لا يوجد حد تحليلات مفعل للاشتراك.');
      }
      const count = access.analysisPeriod === currentPeriod
        ? Number(access.analysisCount ?? 0)
        : 0;
      if (count >= limit) {
        throw new HttpsError(
          'resource-exhausted',
          'استهلكت عدد تحليلات NDVI المتاح لهذا الشهر.',
        );
      }
      vertices = parseVertices(field.vertices);
      transaction.update(accessRef, {
        analysisPeriod: currentPeriod,
        analysisCount: count + 1,
        lastAnalysisRequestedAt: FieldValue.serverTimestamp(),
      });
    });

    try {
      const intervals = await fetchNdviStatistics(vertices);
      const samples = intervals.flatMap((item) => {
        const stats = item.outputs?.ndvi?.bands?.B0?.stats;
        const from = item.interval?.from;
        const to = item.interval?.to;
        if (
          !stats ||
          typeof from !== 'string' ||
          typeof to !== 'string' ||
          !Number.isFinite(stats.mean) ||
          !Number.isFinite(stats.stDev) ||
          !Number.isFinite(stats.sampleCount) ||
          !Number.isFinite(stats.noDataCount) ||
          stats.sampleCount <= stats.noDataCount
        ) {
          return [];
        }
        return [{
          mean: stats.mean,
          stDev: stats.stDev,
          sampleCount: stats.sampleCount,
          validPixelCount: Math.max(0, stats.sampleCount - stats.noDataCount),
          from,
          to,
        }];
      });

      const batch = getDb().batch();
      for (const sample of samples) {
        const historyRef = fieldRef.collection('ndvi_history').doc();
        batch.set(historyRef, {
          ...sample,
          source: 'Sentinel-2 L2A',
          createdAt: FieldValue.serverTimestamp(),
        });
      }
      const latest = samples[samples.length - 1];
      batch.update(fieldRef, {
        lastAnalyzedAt: FieldValue.serverTimestamp(),
        lastAnalysisStatus: samples.length > 0 ? 'ready' : 'no_valid_scenes',
        lastNdvi: latest?.mean ?? null,
        lastNdviIntervalFrom: latest?.from ?? null,
        lastNdviIntervalTo: latest?.to ?? null,
      });
      await batch.commit();

      return {
        status: samples.length > 0 ? 'ready' : 'no_valid_scenes',
        intervals: samples.length,
        latestNdvi: latest?.mean ?? null,
        source: 'Sentinel-2 L2A',
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      logger.error('Satellite NDVI analysis failed', {
        uid,
        fieldId,
        error: error instanceof Error ? error.message : 'unknown',
      });
      throw new HttpsError(
        'unavailable',
        'تعذر إتمام تحليل NDVI. قد تُحتسب المحاولة من رصيد الشهر؛ تواصل مع الإدارة إذا تكرر الخطأ.',
      );
    }
  },
);
