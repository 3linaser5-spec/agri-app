import type { HlsPoint } from './hls-analysis';

export interface Sentinel2PointSample {
  date: string;
  pointId: string;
  latitude: number;
  longitude: number;
  indices: Record<string, number>;
  bands: Record<string, number>;
}

export interface Sentinel2Observation {
  date: string;
  validPointCount: number;
  totalPointCount: number;
  metrics: Record<string, { mean: number; median: number; count: number }>;
  bands: Record<string, { mean: number; median: number; count: number }>;
  points: Array<{
    id: string;
    latitude: number;
    longitude: number;
    indices: Record<string, number>;
    bands: Record<string, number>;
  }>;
}

interface UtmCoordinate {
  easting: number;
  northing: number;
  epsg: number;
}

interface StatsBand {
  stats?: {
    mean?: number;
    sampleCount?: number;
    noDataCount?: number;
  };
}

interface StatsResponse {
  status?: string;
  data?: Array<{
    interval?: { from?: string; to?: string };
    outputs?: {
      metrics?: { bands?: Record<string, StatsBand> };
    };
  }>;
}

const TOKEN_URL =
  'https://identity.dataspace.copernicus.eu/auth/realms/CDSE/protocol/openid-connect/token';
const STATISTICS_URL = 'https://sh.dataspace.copernicus.eu/api/v1/statistics';
const TOKEN_TIMEOUT_MS = 15_000;
const STATISTICS_TIMEOUT_MS = 90_000;
const MAX_RESPONSE_BYTES = 4 * 1024 * 1024;
const SAMPLE_RADIUS_METERS = 1;
const SCL_BAD_CLASSES = [0, 1, 3, 8, 9, 10, 11];

const OUTPUTS = [
  { key: 'NDVI_10M', band: 0, kind: 'index' },
  { key: 'EVI_10M', band: 1, kind: 'index' },
  { key: 'SAVI_10M', band: 2, kind: 'index' },
  { key: 'MSAVI2_10M', band: 3, kind: 'index' },
  { key: 'NDWI_MCF_10M', band: 4, kind: 'index' },
  { key: 'S2_10M_B02', band: 5, kind: 'reflectance' },
  { key: 'S2_10M_B03', band: 6, kind: 'reflectance' },
  { key: 'S2_10M_B04', band: 7, kind: 'reflectance' },
  { key: 'S2_10M_B08', band: 8, kind: 'reflectance' },
] as const;

let cachedToken: { clientId: string; token: string; expiresAt: number } | null = null;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function numberOrNull(value: unknown): number | null {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  return null;
}

function radians(degrees: number): number {
  return degrees * Math.PI / 180;
}

/** Converts WGS84 coordinates to the local UTM zone used by the Stats API geometry. */
export function toUtmCoordinate(latitude: number, longitude: number): UtmCoordinate {
  if (!Number.isFinite(latitude) || latitude < -80 || latitude > 84 ||
      !Number.isFinite(longitude) || longitude < -180 || longitude > 180) {
    throw new Error('Sentinel-2 sample is outside the supported UTM range.');
  }

  const zone = Math.min(60, Math.max(1, Math.floor((longitude + 180) / 6) + 1));
  const majorAxis = 6_378_137;
  const eccentricitySquared = 0.00669437999014;
  const secondEccentricitySquared = eccentricitySquared / (1 - eccentricitySquared);
  const scale = 0.9996;
  const lat = radians(latitude);
  const lon = radians(longitude);
  const centralMeridian = radians((zone - 1) * 6 - 180 + 3);
  const sinLat = Math.sin(lat);
  const cosLat = Math.cos(lat);
  const tanLat = Math.tan(lat);
  const n = majorAxis / Math.sqrt(1 - eccentricitySquared * sinLat * sinLat);
  const t = tanLat * tanLat;
  const c = secondEccentricitySquared * cosLat * cosLat;
  const a = cosLat * (lon - centralMeridian);
  const e4 = eccentricitySquared * eccentricitySquared;
  const e6 = e4 * eccentricitySquared;
  const meridianArc = majorAxis * (
    (1 - eccentricitySquared / 4 - 3 * e4 / 64 - 5 * e6 / 256) * lat -
    (3 * eccentricitySquared / 8 + 3 * e4 / 32 + 45 * e6 / 1024) * Math.sin(2 * lat) +
    (15 * e4 / 256 + 45 * e6 / 1024) * Math.sin(4 * lat) -
    (35 * e6 / 3072) * Math.sin(6 * lat)
  );
  const easting = 500_000 + scale * n * (
    a + (1 - t + c) * a ** 3 / 6 +
    (5 - 18 * t + t * t + 72 * c - 58 * secondEccentricitySquared) * a ** 5 / 120
  );
  let northing = scale * (
    meridianArc + n * tanLat * (
      a * a / 2 + (5 - t + 9 * c + 4 * c * c) * a ** 4 / 24 +
      (61 - 58 * t + t * t + 600 * c - 330 * secondEccentricitySquared) * a ** 6 / 720
    )
  );
  if (latitude < 0) northing += 10_000_000;
  return { easting, northing, epsg: latitude < 0 ? 32700 + zone : 32600 + zone };
}

function pointGeometry(point: HlsPoint): {
  geometry: { type: 'Polygon'; coordinates: number[][][] };
  properties: { crs: string };
} {
  const projected = toUtmCoordinate(point.latitude, point.longitude);
  const west = projected.easting - SAMPLE_RADIUS_METERS;
  const east = projected.easting + SAMPLE_RADIUS_METERS;
  const south = projected.northing - SAMPLE_RADIUS_METERS;
  const north = projected.northing + SAMPLE_RADIUS_METERS;
  return {
    geometry: {
      type: 'Polygon',
      coordinates: [[
        [west, south], [east, south], [east, north], [west, north], [west, south],
      ]],
    },
    properties: { crs: `http://www.opengis.net/def/crs/EPSG/0/${projected.epsg}` },
  };
}

async function getAccessToken(clientId: string, clientSecret: string): Promise<string> {
  const now = Date.now();
  if (cachedToken?.clientId === clientId && cachedToken.expiresAt > now) {
    return cachedToken.token;
  }
  const response = await fetch(TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'client_credentials',
      client_id: clientId,
      client_secret: clientSecret,
    }),
    signal: AbortSignal.timeout(TOKEN_TIMEOUT_MS),
  });
  if (!response.ok) throw new Error(`Copernicus OAuth returned HTTP ${response.status}`);
  const payload: unknown = await response.json();
  if (!isRecord(payload) || typeof payload['access_token'] !== 'string') {
    throw new Error('Copernicus OAuth response was invalid.');
  }
  const expiresIn = typeof payload['expires_in'] === 'number' ? payload['expires_in'] : 300;
  const expiresAt = now + Math.max(30, expiresIn - 60) * 1000;
  cachedToken = { clientId, token: payload['access_token'], expiresAt };
  return payload['access_token'];
}

function buildEvalscript(): string {
  return `//VERSION=3
function setup() {
  return {
    input: [{ bands: ["B02", "B03", "B04", "B08", "SCL", "dataMask"], units: "REFLECTANCE" }],
    output: [
      { id: "metrics", bands: 9, sampleType: "FLOAT32" },
      { id: "dataMask", bands: 1 }
    ]
  };
}
function evaluatePixel(s) {
  const badClass = ${JSON.stringify(SCL_BAD_CLASSES)}.indexOf(Math.round(s.SCL)) >= 0;
  const red = s.B04;
  const green = s.B03;
  const blue = s.B02;
  const nir = s.B08;
  const ndviDenominator = nir + red;
  const eviDenominator = nir + 6 * red - 7.5 * blue + 1;
  const saviDenominator = nir + red + 0.5;
  const ndwiDenominator = green + nir;
  const radicand = Math.max(0, (2 * nir + 1) * (2 * nir + 1) - 8 * (nir - red));
  const valid = s.dataMask === 1 && !badClass &&
    Math.abs(ndviDenominator) > 1e-8 && Math.abs(eviDenominator) > 1e-8 &&
    Math.abs(saviDenominator) > 1e-8 && Math.abs(ndwiDenominator) > 1e-8;
  if (!valid) return { metrics: [0, 0, 0, 0, 0, red, green, red, nir], dataMask: [0] };
  return {
    metrics: [
      (nir - red) / ndviDenominator,
      2.5 * (nir - red) / eviDenominator,
      1.5 * (nir - red) / saviDenominator,
      (2 * nir + 1 - Math.sqrt(radicand)) / 2,
      (green - nir) / ndwiDenominator,
      s.B02, s.B03, s.B04, s.B08
    ],
    dataMask: [1]
  };
}`;
}

export function buildSentinel2StatisticsRequest(
  point: HlsPoint,
  startDate: Date,
  endDate: Date,
): Record<string, unknown> {
  const bounds = pointGeometry(point);
  const toExclusive = new Date(endDate.getTime() + 86_400_000);
  return {
    input: {
      bounds,
      data: [{
        type: 'sentinel-2-l2a',
        dataFilter: { mosaickingOrder: 'leastCC' },
      }],
    },
    aggregation: {
      timeRange: {
        from: `${startDate.toISOString().slice(0, 10)}T00:00:00Z`,
        to: `${toExclusive.toISOString().slice(0, 10)}T00:00:00Z`,
      },
      aggregationInterval: { of: 'P1D' },
      lastIntervalBehavior: 'SHORTEN',
      evalscript: buildEvalscript(),
      resx: 10,
      resy: 10,
    },
  };
}

export function parseSentinel2Stats(payload: unknown, point: HlsPoint): Sentinel2PointSample[] {
  if (!isRecord(payload) || payload['status'] !== 'OK' || !Array.isArray(payload['data'])) {
    throw new Error('Copernicus Statistical API returned an invalid response.');
  }
  const results: Sentinel2PointSample[] = [];
  for (const entry of payload['data']) {
    if (!isRecord(entry)) continue;
    const interval = entry['interval'];
    if (!isRecord(interval) || typeof interval['from'] !== 'string') continue;
    const date = interval['from'].slice(0, 10);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) continue;
    const outputs = entry['outputs'];
    if (!isRecord(outputs) || !isRecord(outputs['metrics'])) continue;
    const bands = outputs['metrics']['bands'];
    if (!isRecord(bands)) continue;
    const indices: Record<string, number> = {};
    const reflectanceBands: Record<string, number> = {};
    for (const output of OUTPUTS) {
      const band = bands[`B${output.band}`];
      if (!isRecord(band) || !isRecord(band['stats'])) continue;
      const value = numberOrNull(band['stats']['mean']);
      if (value === null) continue;
      if (output.kind === 'index') indices[output.key] = value;
      else reflectanceBands[output.key] = value;
    }
    if (Object.keys(indices).length === 0) continue;
    results.push({
      date,
      pointId: point.id,
      latitude: point.latitude,
      longitude: point.longitude,
      indices,
      bands: reflectanceBands,
    });
  }
  return results;
}

async function requestPointSamples(
  point: HlsPoint,
  startDate: Date,
  endDate: Date,
  token: string,
): Promise<Sentinel2PointSample[]> {
  const response = await fetch(STATISTICS_URL, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      Accept: 'application/json',
    },
    body: JSON.stringify(buildSentinel2StatisticsRequest(point, startDate, endDate)),
    signal: AbortSignal.timeout(STATISTICS_TIMEOUT_MS),
  });
  if (!response.ok) throw new Error(`Copernicus Statistics API returned HTTP ${response.status}`);
  const body = await response.text();
  if (Buffer.byteLength(body, 'utf8') > MAX_RESPONSE_BYTES) {
    throw new Error('Copernicus Statistics response exceeded the configured size limit.');
  }
  return parseSentinel2Stats(JSON.parse(body) as unknown, point);
}

/** Samples native 10 m Sentinel-2 L2A reflectance and derived indices at field sample points. */
export async function fetchSentinel2PointSamples(
  points: readonly HlsPoint[],
  startDate: Date,
  endDate: Date,
  clientId: string,
  clientSecret: string,
): Promise<Sentinel2PointSample[]> {
  if (points.length < 1 || points.length > 9) {
    throw new Error('Sentinel-2 supports one to nine field sample points.');
  }
  if (!clientId.trim() || !clientSecret) throw new Error('Copernicus OAuth credentials are missing.');
  if (endDate.getTime() < startDate.getTime()) throw new Error('Invalid Sentinel-2 date range.');
  const token = await getAccessToken(clientId.trim(), clientSecret);
  const allSamples: Sentinel2PointSample[] = [];
  const concurrency = 3;
  for (let offset = 0; offset < points.length; offset += concurrency) {
    const batch = points.slice(offset, offset + concurrency);
    const results = await Promise.allSettled(batch.map((point) =>
      requestPointSamples(point, startDate, endDate, token),
    ));
    const succeeded = results.filter((result): result is PromiseFulfilledResult<Sentinel2PointSample[]> =>
      result.status === 'fulfilled',
    );
    if (succeeded.length === 0 && allSamples.length === 0) {
      throw new Error('All Copernicus sample requests failed.');
    }
    allSamples.push(...succeeded.flatMap((result) => result.value));
  }
  return allSamples;
}

function median(values: readonly number[]): number {
  const sorted = [...values].sort((a, b) => a - b);
  const middle = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 0
    ? (sorted[middle - 1]! + sorted[middle]!) / 2
    : sorted[middle]!;
}

/** Aggregates clear Sentinel-2 point pixels into a field-level daily time series. */
export function aggregateSentinel2Samples(
  samples: readonly Sentinel2PointSample[],
  expectedPoints: readonly HlsPoint[],
): Sentinel2Observation[] {
  const byDate = new Map<string, Map<string, Sentinel2PointSample>>();
  for (const sample of samples) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(sample.date) || !sample.pointId) continue;
    let points = byDate.get(sample.date);
    if (!points) {
      points = new Map<string, Sentinel2PointSample>();
      byDate.set(sample.date, points);
    }
    points.set(sample.pointId, sample);
  }

  return [...byDate.entries()].sort(([a], [b]) => a.localeCompare(b)).map(([date, points]) => {
    const metricValues = new Map<string, number[]>();
    const bandValues = new Map<string, number[]>();
    const pointRows = [...points.values()].map((point) => {
      for (const [key, value] of Object.entries(point.indices)) {
        if (!Number.isFinite(value)) continue;
        const bucket = metricValues.get(key) ?? [];
        bucket.push(value);
        metricValues.set(key, bucket);
      }
      for (const [key, value] of Object.entries(point.bands)) {
        if (!Number.isFinite(value)) continue;
        const bucket = bandValues.get(key) ?? [];
        bucket.push(value);
        bandValues.set(key, bucket);
      }
      return {
        id: point.pointId,
        latitude: point.latitude,
        longitude: point.longitude,
        indices: point.indices,
        bands: point.bands,
      };
    });
    const summarize = (values: Map<string, number[]>) => Object.fromEntries(
      [...values.entries()].map(([key, items]) => [key, {
        mean: items.reduce((sum, value) => sum + value, 0) / items.length,
        median: median(items),
        count: items.length,
      }]),
    );
    return {
      date,
      validPointCount: pointRows.filter((point) => Object.keys(point.indices).length > 0).length,
      totalPointCount: expectedPoints.length,
      metrics: summarize(metricValues),
      bands: summarize(bandValues),
      points: pointRows,
    };
  });
}
