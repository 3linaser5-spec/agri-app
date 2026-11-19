export interface HlsPoint {
  latitude: number;
  longitude: number;
  id: string;
  category: string;
}

export interface HlsCoordinate {
  latitude: number;
  longitude: number;
}

export interface HlsCsvRow {
  [column: string]: string;
}

export interface HlsSample {
  date: string;
  pointId: string;
  latitude?: number;
  longitude?: number;
  product: string;
  layer: string;
  value: number;
}

export interface HlsQaMask {
  raw: number;
  cirrus: boolean;
  cloud: boolean;
  adjacent: boolean;
  shadow: boolean;
  snowIce: boolean;
  water: boolean;
  aerosolCode: number;
  aerosol: boolean;
  clear: boolean;
}

export interface HlsMetricSummary {
  mean: number;
  median: number;
  count: number;
}

export interface HlsAlert {
  code: string;
  severity: 'high' | 'medium';
  reason: string;
  message: string;
  latitude: number | null;
  longitude: number | null;
  fieldCheck: string;
}

export interface HlsObservation {
  date: string;
  validPointCount: number;
  totalPointCount: number;
  qa: {
    clearPointCount: number;
    flaggedPointCount: number;
    cirrusPointCount: number;
    cloudPointCount: number;
    adjacentPointCount: number;
    shadowPointCount: number;
    snowIcePointCount: number;
    waterPointCount: number;
    aerosolPointCount: number;
  };
  metrics: Record<string, HlsMetricSummary>;
  points: Array<{
    id: string;
    latitude: number | null;
    longitude: number | null;
    metrics: Record<string, number>;
    qa: Record<string, HlsQaMask>;
  }>;
  alerts: HlsAlert[];
}

const MAX_POLYGON_VERTICES = 25;
const FILL_VALUES = new Set([-9999, -19999]);
const VI_LAYERS = new Set([
  'EVI',
  'MSAVI',
  'NBR',
  'NBR2',
  'NDMI',
  'NDVI',
  'NDWI',
  'SAVI',
  'TVI',
]);
const L30_BANDS = new Set([
  'B01', 'B02', 'B03', 'B04', 'B05', 'B06', 'B07', 'B09', 'B10', 'B11',
  'FMASK', 'SAA', 'SZA', 'VAA', 'VZA',
]);
const S30_BANDS = new Set([
  'B01', 'B02', 'B03', 'B04', 'B05', 'B06', 'B07', 'B08', 'B8A', 'B09',
  'B10', 'B11', 'B12', 'FMASK', 'SAA', 'SZA', 'VAA', 'VZA',
]);

function isCoordinate(value: unknown): value is HlsCoordinate {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) return false;
  const record = value as Record<string, unknown>;
  const latitude = record['latitude'] ?? record['lat'];
  const longitude = record['longitude'] ?? record['lon'] ?? record['lng'];
  return (
    typeof latitude === 'number' && Number.isFinite(latitude) &&
    typeof longitude === 'number' && Number.isFinite(longitude) &&
    latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180
  );
}

function coordinateFrom(value: unknown): HlsCoordinate | null {
  if (isCoordinate(value)) {
    const record = value as unknown as Record<string, number>;
    return {
      latitude: record['latitude'] ?? record['lat']!,
      longitude: record['longitude'] ?? record['lon'] ?? record['lng']!,
    };
  }
  if (
    Array.isArray(value) && value.length >= 2 &&
    typeof value[0] === 'number' && Number.isFinite(value[0]) &&
    typeof value[1] === 'number' && Number.isFinite(value[1])
  ) {
    return { latitude: value[0], longitude: value[1] };
  }
  return null;
}

function sameCoordinate(a: HlsCoordinate, b: HlsCoordinate): boolean {
  return Math.abs(a.latitude - b.latitude) < 1e-10 &&
    Math.abs(a.longitude - b.longitude) < 1e-10;
}

/** Validates a latitude/longitude ring; an open ring is closed internally by consumers. */
export function validateHlsPolygon(input: unknown): HlsCoordinate[] {
  if (!Array.isArray(input) || input.length < 3 || input.length > 100) {
    throw new Error('المضلع يجب أن يحتوي على ثلاثة رؤوس على الأقل.');
  }
  const coordinates: HlsCoordinate[] = [];
  for (const item of input) {
    const coordinate = coordinateFrom(item);
    if (!coordinate) throw new Error('إحداثيات حدود الحقل غير صالحة.');
    coordinates.push(coordinate);
  }

  if (coordinates.length > 3 && sameCoordinate(coordinates[0]!, coordinates.at(-1)!)) {
    coordinates.pop();
  }
  if (coordinates.length < 3 || coordinates.length > MAX_POLYGON_VERTICES) {
    throw new Error('حدود الحقل يجب أن تضم من 3 إلى 25 رأسًا مميزًا.');
  }
  const unique = new Set(coordinates.map((point) =>
    `${point.latitude.toFixed(10)},${point.longitude.toFixed(10)}`,
  ));
  if (unique.size !== coordinates.length) {
    throw new Error('حدود الحقل تحتوي على رؤوس مكررة أو غير صالحة.');
  }
  const closed = [...coordinates, coordinates[0]!];
  const area = closed.slice(0, -1).reduce((sum, point, index) => {
    const next = closed[index + 1]!;
    return sum + point.longitude * next.latitude - next.longitude * point.latitude;
  }, 0);
  if (Math.abs(area) < 1e-12) throw new Error('مساحة مضلع الحقل غير صالحة.');
  const meanLatitude = coordinates.reduce((sum, point) => sum + point.latitude, 0) /
    coordinates.length;
  const degreesToMeters = 111_320;
  const areaSquareMeters = Math.abs(area) / 2 * degreesToMeters ** 2 *
    Math.max(0, Math.cos(meanLatitude * Math.PI / 180));
  if (areaSquareMeters < 100 || areaSquareMeters > 500_000_000) {
    throw new Error('مساحة مضلع الحقل خارج النطاق المعقول.');
  }
  return coordinates;
}

/** Ray-casting test. Boundary points are treated as inside. */
export function pointInHlsPolygon(
  point: HlsCoordinate,
  polygonInput: readonly HlsCoordinate[],
): boolean {
  if (polygonInput.length < 3) return false;
  const polygon = polygonInput.length > 3 &&
      sameCoordinate(polygonInput[0]!, polygonInput.at(-1)!)
    ? polygonInput.slice(0, -1)
    : polygonInput;
  let inside = false;
  for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i, i += 1) {
    const a = polygon[j]!;
    const b = polygon[i]!;
    const cross = (point.longitude - a.longitude) * (b.latitude - a.latitude) -
      (point.latitude - a.latitude) * (b.longitude - a.longitude);
    const onSegment = Math.abs(cross) < 1e-10 &&
      point.longitude >= Math.min(a.longitude, b.longitude) - 1e-10 &&
      point.longitude <= Math.max(a.longitude, b.longitude) + 1e-10 &&
      point.latitude >= Math.min(a.latitude, b.latitude) - 1e-10 &&
      point.latitude <= Math.max(a.latitude, b.latitude) + 1e-10;
    if (onSegment) return true;
    const crosses = (a.latitude > point.latitude) !== (b.latitude > point.latitude) &&
      point.longitude < (b.longitude - a.longitude) *
        (point.latitude - a.latitude) / (b.latitude - a.latitude) + a.longitude;
    if (crosses) inside = !inside;
  }
  return inside;
}

function polygonCentroid(polygon: readonly HlsCoordinate[]): HlsCoordinate {
  let twiceArea = 0;
  let latitudeTotal = 0;
  let longitudeTotal = 0;
  for (let index = 0; index < polygon.length; index += 1) {
    const current = polygon[index]!;
    const next = polygon[(index + 1) % polygon.length]!;
    const cross = current.longitude * next.latitude - next.longitude * current.latitude;
    twiceArea += cross;
    latitudeTotal += (current.latitude + next.latitude) * cross;
    longitudeTotal += (current.longitude + next.longitude) * cross;
  }
  if (Math.abs(twiceArea) < 1e-12) {
    return {
      latitude: polygon.reduce((sum, point) => sum + point.latitude, 0) / polygon.length,
      longitude: polygon.reduce((sum, point) => sum + point.longitude, 0) / polygon.length,
    };
  }
  return {
    latitude: latitudeTotal / (3 * twiceArea),
    longitude: longitudeTotal / (3 * twiceArea),
  };
}

function scanlineInteriorPoint(polygon: readonly HlsCoordinate[]): HlsCoordinate | null {
  const latitudes = [...new Set(polygon.map((point) => point.latitude))]
    .sort((a, b) => a - b);
  let best: HlsCoordinate | null = null;
  let bestWidth = 0;
  for (let index = 0; index < latitudes.length - 1; index += 1) {
    const latitude = (latitudes[index]! + latitudes[index + 1]!) / 2;
    const intersections: number[] = [];
    for (let edge = 0; edge < polygon.length; edge += 1) {
      const a = polygon[edge]!;
      const b = polygon[(edge + 1) % polygon.length]!;
      if ((a.latitude > latitude) === (b.latitude > latitude)) continue;
      intersections.push(a.longitude +
        (latitude - a.latitude) * (b.longitude - a.longitude) /
          (b.latitude - a.latitude));
    }
    intersections.sort((a, b) => a - b);
    for (let edge = 0; edge + 1 < intersections.length; edge += 2) {
      const left = intersections[edge]!;
      const right = intersections[edge + 1]!;
      const width = right - left;
      if (width <= bestWidth) continue;
      const candidate = { latitude, longitude: (left + right) / 2 };
      if (pointInHlsPolygon(candidate, polygon)) {
        best = candidate;
        bestWidth = width;
      }
    }
  }
  return best;
}

/** Samples a 3x3 bounding-box grid and retains only points inside the polygon. */
export function sampleHlsPoints(input: unknown): HlsPoint[] {
  const polygon = validateHlsPolygon(input);
  const minLatitude = Math.min(...polygon.map((point) => point.latitude));
  const maxLatitude = Math.max(...polygon.map((point) => point.latitude));
  const minLongitude = Math.min(...polygon.map((point) => point.longitude));
  const maxLongitude = Math.max(...polygon.map((point) => point.longitude));
  const fractions = [0.2, 0.5, 0.8];
  const candidates: HlsCoordinate[] = [];
  for (const latitudeFraction of fractions) {
    for (const longitudeFraction of fractions) {
      const point = {
        latitude: minLatitude + (maxLatitude - minLatitude) * latitudeFraction,
        longitude: minLongitude + (maxLongitude - minLongitude) * longitudeFraction,
      };
      if (pointInHlsPolygon(point, polygon)) candidates.push(point);
    }
  }

  if (candidates.length === 0) {
    const centroid = polygonCentroid(polygon);
    if (pointInHlsPolygon(centroid, polygon)) candidates.push(centroid);
  }
  if (candidates.length === 0) {
    const interior = scanlineInteriorPoint(polygon);
    if (interior) candidates.push(interior);
  }
  if (candidates.length === 0) {
    throw new Error('تعذر إنشاء نقطة عينة داخل حدود الحقل.');
  }

  return candidates.slice(0, 9).map((point, index) => ({
    latitude: Number(point.latitude.toFixed(7)),
    longitude: Number(point.longitude.toFixed(7)),
    id: `p${index + 1}`,
    category: 'field',
  }));
}

function normalizeHeader(value: string): string {
  return value.replace(/^\uFEFF/, '').trim().toLowerCase().replace(/[^a-z0-9]/g, '');
}

/** Parses RFC4180-style CSV, including escaped quotes and commas/newlines in quoted cells. */
export function parseHlsCsv(text: string): HlsCsvRow[] {
  const rows: string[][] = [];
  let row: string[] = [];
  let cell = '';
  let quoted = false;
  for (let index = 0; index < text.length; index += 1) {
    const character = text[index]!;
    if (quoted) {
      if (character === '"' && text[index + 1] === '"') {
        cell += '"';
        index += 1;
      } else if (character === '"') {
        quoted = false;
      } else {
        cell += character;
      }
      continue;
    }
    if (character === '"' && cell.length === 0) {
      quoted = true;
    } else if (character === ',') {
      row.push(cell);
      cell = '';
    } else if (character === '\n' || character === '\r') {
      if (character === '\r' && text[index + 1] === '\n') index += 1;
      row.push(cell);
      cell = '';
      if (row.some((value) => value.length > 0)) rows.push(row);
      row = [];
    } else {
      cell += character;
    }
  }
  if (quoted) throw new Error('CSV يحتوي على اقتباس غير مكتمل.');
  if (cell.length > 0 || row.length > 0) {
    row.push(cell);
    if (row.some((value) => value.length > 0)) rows.push(row);
  }
  if (rows.length < 2) return [];
  const headers = rows[0]!.map(normalizeHeader);
  return rows.slice(1).map((values) => {
    const result: HlsCsvRow = {};
    headers.forEach((header, index) => {
      if (header) result[header] = values[index] ?? '';
    });
    return result;
  });
}

function firstColumn(row: HlsCsvRow, ...names: string[]): string | undefined {
  for (const name of names) {
    const value = row[normalizeHeader(name)];
    if (value !== undefined && value.trim() !== '') return value.trim();
  }
  return undefined;
}

function normalizeProduct(value: string): string | null {
  const product = value.trim().toUpperCase().replace(/\s/g, '');
  if (product.includes('HLSL30_VI') || product === 'HLSL30VI') return 'HLSL30_VI.020';
  if (product.includes('HLSS30_VI') || product === 'HLSS30VI') return 'HLSS30_VI.020';
  if (product.includes('HLSL30')) return 'HLSL30.020';
  if (product.includes('HLSS30')) return 'HLSS30.020';
  return null;
}

function normalizedDate(value: string): string | null {
  const trimmed = value.trim();
  let date: string | null = null;
  if (/^\d{4}-\d{2}-\d{2}(?:T.*)?$/.test(trimmed)) {
    date = trimmed.slice(0, 10);
  } else {
    const us = /^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$/.exec(trimmed);
    if (us) date = `${us[3]}-${us[1]!.padStart(2, '0')}-${us[2]!.padStart(2, '0')}`;
  }
  if (!date || !/^\d{4}-\d{2}-\d{2}$/.test(date)) return null;
  const parsed = new Date(`${date}T00:00:00.000Z`);
  return Number.isFinite(parsed.getTime()) && parsed.toISOString().slice(0, 10) === date
    ? date
    : null;
}

/** Converts flexible NASA CSV rows to canonical samples. */
export function parseHlsSamples(csvText: string): HlsSample[] {
  const parsedRows = parseHlsCsv(csvText);
  const samples: HlsSample[] = [];
  for (const row of parsedRows) {
    const dateValue = firstColumn(row, 'Date', 'ObservationDate', 'AcquisitionDate', 'Time');
    const date = dateValue ? normalizedDate(dateValue) : null;
    if (!date) continue;
    const productValue = firstColumn(row, 'Product', 'ProductName', 'Dataset');
    const product = productValue ? normalizeProduct(productValue) : null;
    const pointId = firstColumn(row, 'ID', 'PointID', 'SampleID', 'CoordinateID') ?? '';
    const latText = firstColumn(row, 'Latitude', 'Lat');
    const lonText = firstColumn(row, 'Longitude', 'Lon', 'Lng');
    const latitude = latText === undefined ? undefined : Number(latText);
    const longitude = lonText === undefined ? undefined : Number(lonText);
    const validCoords = latitude !== undefined && Number.isFinite(latitude) &&
      longitude !== undefined && Number.isFinite(longitude);
    const layerValue = firstColumn(row, 'Layer', 'LayerName', 'Band');
    const valueText = firstColumn(row, 'Value', 'PixelValue', 'SampleValue');
    if (product && layerValue && valueText !== undefined) {
      const value = Number(valueText);
      if (Number.isFinite(value)) {
        samples.push({
          date,
          pointId: pointId || (validCoords ? `${latitude},${longitude}` : 'unknown'),
          ...(validCoords ? { latitude, longitude } : {}),
          product,
          layer: layerValue.toUpperCase(),
          value,
        });
      }
      continue;
    }
    if (product) {
      for (const [column, raw] of Object.entries(row)) {
        const layer = column.toUpperCase();
        if (
          !(VI_LAYERS.has(layer) || L30_BANDS.has(layer) || S30_BANDS.has(layer)) ||
          raw.trim() === ''
        ) continue;
        const value = Number(raw);
        if (!Number.isFinite(value)) continue;
        samples.push({
          date,
          pointId: pointId || (validCoords ? `${latitude},${longitude}` : 'unknown'),
          ...(validCoords ? { latitude, longitude } : {}),
          product,
          layer,
          value,
        });
      }
    }
  }
  return samples;
}

/** AppEEARS Point CSV values are already scale-applied; reject fill values without rescaling. */
export function normalizeHlsPointValue(
  productInput: string,
  layerInput: string,
  raw: number,
): number | null {
  if (!Number.isFinite(raw) || FILL_VALUES.has(raw)) return null;
  const product = normalizeProduct(productInput);
  if (!product) return null;
  const layer = layerInput.trim().toUpperCase();
  if (layer === 'FMASK') return raw === 255 ? null : Math.trunc(raw);
  if (['SAA', 'SZA', 'VAA', 'VZA'].includes(layer) && raw === 40000) return null;
  return raw;
}

/** Decodes the 1-based Fmask QA bit fields; water is descriptive, not an error. */
export function decodeHlsFmask(raw: number): HlsQaMask | null {
  if (!Number.isFinite(raw) || FILL_VALUES.has(raw) || raw < 0 || raw === 255) return null;
  const bits = Math.trunc(raw);
  const cloud = (bits & (1 << 1)) !== 0;
  const adjacent = (bits & (1 << 2)) !== 0;
  const shadow = (bits & (1 << 3)) !== 0;
  const snowIce = (bits & (1 << 4)) !== 0;
  const water = (bits & (1 << 5)) !== 0;
  const aerosolCode = (bits >> 6) & 0b11;
  return {
    raw: bits,
    cirrus: (bits & 1) !== 0,
    cloud,
    adjacent,
    shadow,
    snowIce,
    water,
    aerosolCode,
    aerosol: aerosolCode > 0,
    clear: !(bits & 1) && !cloud && !adjacent && !shadow && !snowIce,
  };
}

function median(values: number[]): number {
  const ordered = [...values].sort((a, b) => a - b);
  const middle = Math.floor(ordered.length / 2);
  return ordered.length % 2 === 0
    ? (ordered[middle - 1]! + ordered[middle]!) / 2
    : ordered[middle]!;
}

interface MutablePoint {
  id: string;
  latitude: number | null;
  longitude: number | null;
  rawValues: Map<string, number[]>;
  rawQa: Map<string, HlsQaMask>;
  metricValues: Map<string, number[]>;
}

function sourceName(product: string): string {
  return product.startsWith('HLSL30') ? 'HLSL30' : 'HLSS30';
}

function allowedLayer(product: string, layer: string): boolean {
  if (product.endsWith('_VI.020')) return VI_LAYERS.has(layer);
  if (product === 'HLSL30.020') return L30_BANDS.has(layer);
  if (product === 'HLSS30.020') return S30_BANDS.has(layer);
  return false;
}

/** Aggregates multi-product samples by date and point, retaining map-ready point values. */
export function aggregateHlsSamples(
  samples: readonly HlsSample[],
  expectedPoints: readonly HlsPoint[] = [],
): HlsObservation[] {
  const byDate = new Map<string, Map<string, MutablePoint>>();
  const expectedById = new Map(expectedPoints.map((point) => [point.id, point]));
  for (const sample of samples) {
    const date = normalizedDate(sample.date);
    const product = normalizeProduct(sample.product);
    const layer = sample.layer.trim().toUpperCase();
    if (!date || !product || !allowedLayer(product, layer)) continue;
    const scaled = normalizeHlsPointValue(product, layer, sample.value);
    if (scaled === null) continue;
    let points = byDate.get(date);
    if (!points) {
      points = new Map<string, MutablePoint>();
      byDate.set(date, points);
    }
    const id = sample.pointId || `${sample.latitude ?? ''},${sample.longitude ?? ''}`;
    let point = points.get(id);
    if (!point) {
      const expected = expectedById.get(id);
      point = {
        id,
        latitude: sample.latitude ?? expected?.latitude ?? null,
        longitude: sample.longitude ?? expected?.longitude ?? null,
        rawValues: new Map<string, number[]>(),
        rawQa: new Map<string, HlsQaMask>(),
        metricValues: new Map<string, number[]>(),
      };
      points.set(id, point);
    }
    if (sample.latitude !== undefined && Number.isFinite(sample.latitude)) point.latitude = sample.latitude;
    if (sample.longitude !== undefined && Number.isFinite(sample.longitude)) point.longitude = sample.longitude;

    if (layer === 'FMASK') {
      const qa = decodeHlsFmask(sample.value);
      if (qa) point.rawQa.set(sourceName(product), qa);
      continue;
    }
    const rawKey = `${product}:${layer}`;
    const bucket = point.rawValues.get(rawKey) ?? [];
    bucket.push(scaled);
    point.rawValues.set(rawKey, bucket);
  }

  const observations: HlsObservation[] = [];
  for (const [date, pointMap] of [...byDate.entries()].sort(([a], [b]) => a.localeCompare(b))) {
    const pointResults: HlsObservation['points'] = [];
    const metricSamples = new Map<string, number[]>();
    const qaCounts = {
      clearPointCount: 0,
      flaggedPointCount: 0,
      cirrusPointCount: 0,
      cloudPointCount: 0,
      adjacentPointCount: 0,
      shadowPointCount: 0,
      snowIcePointCount: 0,
      waterPointCount: 0,
      aerosolPointCount: 0,
    };

    for (const point of pointMap.values()) {
      const pointMetricValues = new Map<string, number[]>();
      for (const [rawKey, values] of point.rawValues) {
        const [product = '', layer = ''] = rawKey.split(':');
        const isVi = product.endsWith('_VI.020');
        const source = sourceName(product);
        const qa = point.rawQa.get(source);
        if (qa ? !qa.clear : !isVi) continue;
        const value = values.reduce((sum, item) => sum + item, 0) / values.length;
        const metric = isVi ? layer : `${source}_${layer}`;
        const bucket = pointMetricValues.get(metric) ?? [];
        bucket.push(value);
        pointMetricValues.set(metric, bucket);
      }

      const s30Qa = point.rawQa.get('HLSS30');
      const b8a = point.rawValues.get('HLSS30.020:B8A');
      const b05 = point.rawValues.get('HLSS30.020:B05');
      if (s30Qa?.clear && b8a?.length && b05?.length) {
        const nearInfrared = b8a.reduce((sum, value) => sum + value, 0) / b8a.length;
        const redEdge = b05.reduce((sum, value) => sum + value, 0) / b05.length;
        const denominator = nearInfrared + redEdge;
        if (Number.isFinite(denominator) && Math.abs(denominator) > 1e-12) {
          pointMetricValues.set('NDRE', [(nearInfrared - redEdge) / denominator]);
        }
      }

      const pointMetrics: Record<string, number> = {};
      for (const [metric, values] of pointMetricValues) {
        const value = values.reduce((sum, item) => sum + item, 0) / values.length;
        pointMetrics[metric] = value;
        const bucket = metricSamples.get(metric) ?? [];
        bucket.push(value);
        metricSamples.set(metric, bucket);
      }
      const qa: Record<string, HlsQaMask> = {};
      for (const [source, mask] of point.rawQa) qa[source] = mask;
      const flags = Object.values(qa);
      if (flags.length > 0) {
        if (flags.every((mask) => mask.clear)) qaCounts.clearPointCount += 1;
        if (flags.some((mask) => !mask.clear)) qaCounts.flaggedPointCount += 1;
        if (flags.some((mask) => mask.cirrus)) qaCounts.cirrusPointCount += 1;
        if (flags.some((mask) => mask.cloud)) qaCounts.cloudPointCount += 1;
        if (flags.some((mask) => mask.adjacent)) qaCounts.adjacentPointCount += 1;
        if (flags.some((mask) => mask.shadow)) qaCounts.shadowPointCount += 1;
        if (flags.some((mask) => mask.snowIce)) qaCounts.snowIcePointCount += 1;
        if (flags.some((mask) => mask.water)) qaCounts.waterPointCount += 1;
        if (flags.some((mask) => mask.aerosol)) qaCounts.aerosolPointCount += 1;
      }
      if (Object.keys(pointMetrics).length > 0 || flags.length > 0) {
        pointResults.push({
          id: point.id,
          latitude: point.latitude,
          longitude: point.longitude,
          metrics: pointMetrics,
          qa,
        });
      }
    }

    const metrics: Record<string, HlsMetricSummary> = {};
    for (const [metric, values] of metricSamples) {
      metrics[metric] = {
        mean: values.reduce((sum, value) => sum + value, 0) / values.length,
        median: median(values),
        count: values.length,
      };
    }
    observations.push({
      date,
      validPointCount: pointResults.filter((point) => Object.keys(point.metrics).length > 0).length,
      totalPointCount: Math.max(expectedPoints.length, pointMap.size),
      qa: qaCounts,
      metrics,
      points: pointResults,
      alerts: [],
    });
  }
  return attachHlsAlerts(observations);
}

/** Adds cautious field-check alerts only when successive valid observations decline. */
export function buildHlsAlerts(
  observations: readonly (Pick<HlsObservation, 'date' | 'validPointCount' | 'metrics'> & {
    points?: HlsObservation['points'];
  })[],
): Map<string, HlsAlert[]> {
  const alertsByDate = new Map<string, HlsAlert[]>();
  const valid = observations
    .filter((item) => item.validPointCount > 0 && /^\d{4}-\d{2}-\d{2}$/.test(item.date))
    .slice()
    .sort((a, b) => a.date.localeCompare(b.date));
  for (let index = 1; index < valid.length; index += 1) {
    const current = valid[index]!;
    const previous = valid.slice(Math.max(0, index - 3), index)
      .filter((item) => item.validPointCount > 0);
    if (previous.length === 0) continue;
    const alerts: HlsAlert[] = [];
    for (const metric of ['NDVI', 'NDMI']) {
      const currentValue = current.metrics[metric]?.mean;
      const baselineValues = previous
        .map((item) => item.metrics[metric]?.mean)
        .filter((value): value is number => value !== undefined && Number.isFinite(value));
      if (currentValue === undefined || !Number.isFinite(currentValue) || baselineValues.length === 0) {
        continue;
      }
      const baseline = baselineValues.reduce((sum, value) => sum + value, 0) / baselineValues.length;
      const decline = baseline - currentValue;
      if (decline >= 0.15) {
        const points = current.points ?? [];
        const located = points.find((point) =>
          typeof point.latitude === 'number' && typeof point.longitude === 'number' &&
          Number.isFinite(point.latitude) && Number.isFinite(point.longitude) &&
          Number.isFinite(point.metrics[metric]),
        );
        const reason = `انخفاض ${metric} بمقدار ${decline.toFixed(2)} مقارنة بخط الأساس السابق`;
        alerts.push({
          code: `${metric.toLowerCase()}_decline`,
          severity: decline >= 0.25 ? 'high' : 'medium',
          reason,
          message: `لوحظ انخفاض ملحوظ في ${metric} مقارنة بالعينات السابقة؛ يُستحسن فحص الحقل ميدانيًا. هذا مؤشر متابعة وليس تشخيصًا لحالة المحصول.`,
          latitude: located?.latitude ?? null,
          longitude: located?.longitude ?? null,
          fieldCheck: 'يُرجى إجراء فحص ميداني للنباتات والري والآفات في نقطة التنبيه قبل اتخاذ قرار علاجي.',
        });
      }
    }
    if (alerts.length > 0) alertsByDate.set(current.date, alerts);
  }
  return alertsByDate;
}

function attachHlsAlerts(observations: HlsObservation[]): HlsObservation[] {
  const alerts = buildHlsAlerts(observations);
  return observations.map((observation) => ({
    ...observation,
    alerts: alerts.get(observation.date) ?? [],
  }));
}
