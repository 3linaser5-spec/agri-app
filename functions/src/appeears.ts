export interface HlsVertex {
  lat: number;
  lng: number;
}

export const HLS_INDEX_KEYS = [
  'NDVI', 'EVI', 'SAVI', 'MSAVI', 'NDMI', 'NDWI', 'NBR', 'NBR2', 'TVI',
] as const;
export type HlsIndexKey = (typeof HLS_INDEX_KEYS)[number];

export interface ParsedHlsSample {
  index: HlsIndexKey;
  zoneId: string;
  mean: number;
  stDev: number;
  sampleCount: number;
  from: string;
  to: string;
}

export interface HlsZone {
  id: string;
  vertices: HlsVertex[];
  center: HlsVertex;
}

export interface AppEearsTaskRequest {
  task_type: 'area';
  task_name: string;
  params: {
    dates: Array<{ startDate: string; endDate: string }>;
    layers: Array<{ product: string; layer: HlsIndexKey }>;
    output: { format: { type: 'geotiff' }; projection: 'native' };
    geo: {
      type: 'FeatureCollection';
      features: Array<{
        type: 'Feature';
        id: string;
        geometry: { type: 'Polygon'; coordinates: number[][][] };
        properties: { zoneId: string };
      }>;
      fileName: string;
    };
  };
}

const HLS_PRODUCTS = ['HLSS30_VI.020', 'HLSL30_VI.020'];
const GRID_SIDE = 3;

function formatAppEearsDate(date: Date): string {
  const month = String(date.getUTCMonth() + 1).padStart(2, '0');
  const day = String(date.getUTCDate()).padStart(2, '0');
  return `${month}-${day}-${date.getUTCFullYear()}`;
}

function clipAgainstEdge(
  polygon: HlsVertex[],
  inside: (point: HlsVertex) => boolean,
  intersect: (start: HlsVertex, end: HlsVertex) => HlsVertex,
): HlsVertex[] {
  if (polygon.length === 0) return [];
  const output: HlsVertex[] = [];
  let previous = polygon[polygon.length - 1]!;
  let previousInside = inside(previous);
  for (const current of polygon) {
    const currentInside = inside(current);
    if (currentInside !== previousInside) output.push(intersect(previous, current));
    if (currentInside) output.push(current);
    previous = current;
    previousInside = currentInside;
  }
  return output;
}

function clipToRectangle(
  polygon: HlsVertex[],
  minLng: number,
  minLat: number,
  maxLng: number,
  maxLat: number,
): HlsVertex[] {
  let result = polygon;
  const vertical = (x: number) => (a: HlsVertex, b: HlsVertex): HlsVertex => {
    const ratio = (x - a.lng) / (b.lng - a.lng);
    return { lat: a.lat + ratio * (b.lat - a.lat), lng: x };
  };
  const horizontal = (y: number) => (a: HlsVertex, b: HlsVertex): HlsVertex => {
    const ratio = (y - a.lat) / (b.lat - a.lat);
    return { lat: y, lng: a.lng + ratio * (b.lng - a.lng) };
  };
  result = clipAgainstEdge(result, (p) => p.lng >= minLng, vertical(minLng));
  result = clipAgainstEdge(result, (p) => p.lng <= maxLng, vertical(maxLng));
  result = clipAgainstEdge(result, (p) => p.lat >= minLat, horizontal(minLat));
  result = clipAgainstEdge(result, (p) => p.lat <= maxLat, horizontal(maxLat));
  return result;
}

function planarArea(vertices: HlsVertex[]): number {
  let sum = 0;
  for (let i = 0; i < vertices.length; i += 1) {
    const current = vertices[i]!;
    const next = vertices[(i + 1) % vertices.length]!;
    sum += current.lng * next.lat - next.lng * current.lat;
  }
  return Math.abs(sum / 2);
}

export function buildHlsZones(vertices: HlsVertex[]): HlsZone[] {
  if (vertices.length < 3 || vertices.length > 100) {
    throw new Error('HLS boundary must contain between 3 and 100 vertices');
  }
  const minLat = Math.min(...vertices.map((point) => point.lat));
  const maxLat = Math.max(...vertices.map((point) => point.lat));
  const minLng = Math.min(...vertices.map((point) => point.lng));
  const maxLng = Math.max(...vertices.map((point) => point.lng));
  const zones: HlsZone[] = [];
  for (let row = 0; row < GRID_SIDE; row += 1) {
    for (let column = 0; column < GRID_SIDE; column += 1) {
      const zoneMinLat = minLat + (maxLat - minLat) * row / GRID_SIDE;
      const zoneMaxLat = minLat + (maxLat - minLat) * (row + 1) / GRID_SIDE;
      const zoneMinLng = minLng + (maxLng - minLng) * column / GRID_SIDE;
      const zoneMaxLng = minLng + (maxLng - minLng) * (column + 1) / GRID_SIDE;
      const clipped = clipToRectangle(vertices, zoneMinLng, zoneMinLat, zoneMaxLng, zoneMaxLat);
      if (clipped.length < 3 || planarArea(clipped) < planarArea(vertices) / 1000) continue;
      // المعرفات متسلسلة بلا فجوات حتى يطابق ترتيبها معرّفات NASA (aid0001، aid0002...).
      const id = `Z${String(zones.length + 1).padStart(2, '0')}`;
      zones.push({
        id,
        vertices: clipped,
        center: {
          lat: clipped.reduce((sum, point) => sum + point.lat, 0) / clipped.length,
          lng: clipped.reduce((sum, point) => sum + point.lng, 0) / clipped.length,
        },
      });
    }
  }
  if (zones.length === 0) {
    zones.push({
      id: 'Z01',
      vertices,
      center: {
        lat: vertices.reduce((sum, point) => sum + point.lat, 0) / vertices.length,
        lng: vertices.reduce((sum, point) => sum + point.lng, 0) / vertices.length,
      },
    });
  }
  return zones;
}

export function buildHlsAreaRequest(
  vertices: HlsVertex[],
  taskName: string,
  now = new Date(),
): AppEearsTaskRequest {
  if (vertices.length < 3 || vertices.length > 100) {
    throw new Error('HLS boundary must contain between 3 and 100 vertices');
  }
  const zones = buildHlsZones(vertices);
  const end = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
  const start = new Date(end.getTime() - 90 * 24 * 60 * 60 * 1000);

  return {
    task_type: 'area',
    task_name: taskName.slice(0, 80),
    params: {
      dates: [{ startDate: formatAppEearsDate(start), endDate: formatAppEearsDate(end) }],
      layers: HLS_PRODUCTS.flatMap((product) => HLS_INDEX_KEYS.map((layer) => ({ product, layer }))),
      output: { format: { type: 'geotiff' }, projection: 'native' },
      geo: {
        type: 'FeatureCollection',
        features: zones.map((zone) => {
          const ring = zone.vertices.map(({ lat, lng }) => [lng, lat]);
          const first = ring[0]!;
          const last = ring[ring.length - 1]!;
          if (first[0] !== last[0] || first[1] !== last[1]) ring.push([...first]);
          return {
            type: 'Feature' as const,
            id: zone.id,
            geometry: { type: 'Polygon' as const, coordinates: [ring] },
            properties: { zoneId: zone.id },
          };
        }),
        fileName: 'NabatiField',
      },
    },
  };
}

function parseCsvRow(line: string): string[] {
  const values: string[] = [];
  let value = '';
  let quoted = false;
  for (let index = 0; index < line.length; index += 1) {
    const character = line[index]!;
    if (character === '"') {
      if (quoted && line[index + 1] === '"') {
        value += '"';
        index += 1;
      } else {
        quoted = !quoted;
      }
    } else if (character === ',' && !quoted) {
      values.push(value.trim());
      value = '';
    } else {
      value += character;
    }
  }
  values.push(value.trim());
  return values;
}

function normalizedHeader(value: string): string {
  return value.toLowerCase().replace(/[^a-z0-9]/g, '');
}

function parseDate(value: string): Date | null {
  const direct = new Date(value);
  if (/^\d{4}-\d{2}-\d{2}/.test(value) && Number.isFinite(direct.getTime())) {
    return new Date(Date.UTC(direct.getUTCFullYear(), direct.getUTCMonth(), direct.getUTCDate()));
  }
  const ordinal = /(?:doy)?(20\d{2})(\d{3})(?:t\d{6})?/i.exec(value);
  if (ordinal) {
    const year = Number(ordinal[1]);
    const dayOfYear = Number(ordinal[2]);
    if (dayOfYear >= 1 && dayOfYear <= 366) return new Date(Date.UTC(year, 0, dayOfYear));
  }
  if (/^\d{8}$/.test(value)) {
    const year = Number(value.slice(0, 4));
    const month = Number(value.slice(4, 6));
    const day = Number(value.slice(6, 8));
    const parsed = new Date(Date.UTC(year, month - 1, day));
    if (parsed.getUTCFullYear() === year && parsed.getUTCMonth() === month - 1 && parsed.getUTCDate() === day) return parsed;
  }
  return null;
}

function sampleDate(headers: string[], row: string[]): Date | null {
  const dateHeaders = headers
    .map((header, index) => ({ header: normalizedHeader(header), index }))
    .filter(({ header }) => header.includes('date') || header.includes('time') || header.includes('filename') || header.includes('granule') || header === 'file');
  for (const item of dateHeaders) {
    const date = parseDate(row[item.index] ?? '');
    if (date) return date;
  }
  for (const value of row) {
    const date = parseDate(value);
    if (date) return date;
  }
  return null;
}

function parseIndex(value: string): HlsIndexKey | null {
  const normalized = value.trim().toUpperCase().replace(/[^A-Z0-9]/g, '');
  return HLS_INDEX_KEYS.find((index) => index === normalized) ?? null;
}

function parseZone(value: string): string | null {
  const named = /Z0?(\d+)/i.exec(value);
  if (named) return `Z${String(Number(named[1])).padStart(2, '0')}`;
  const aid = /aid0*(\d+)/i.exec(value);
  if (aid) return `Z${String(Number(aid[1])).padStart(2, '0')}`;
  return null;
}

function scaleValue(value: number, index: HlsIndexKey): number {
  const scale = index === 'TVI' ? 0.01 : 0.0001;
  return Math.abs(value) > 1.0001 || (index === 'TVI' && Math.abs(value) > 10)
    ? value * scale
    : value;
}

export function parseHlsStatisticsCsv(content: string, fileName = ''): ParsedHlsSample[] {
  const lines = content.replace(/^\uFEFF/, '').split(/\r?\n/).filter((line) => line.trim().length > 0);
  if (lines.length < 2) return [];
  let headerIndex = -1;
  let headers: string[] = [];
  let meanIndex = -1;
  for (let index = 0; index < Math.min(lines.length, 30); index += 1) {
    const candidate = parseCsvRow(lines[index]!);
    const foundMean = candidate.map(normalizedHeader).findIndex((name) => name === 'mean' || name.endsWith('mean'));
    if (foundMean >= 0) {
      headerIndex = index;
      headers = candidate;
      meanIndex = foundMean;
      break;
    }
  }
  if (headerIndex < 0) throw new Error('AppEEARS statistics CSV has no mean column');
  const normalized = headers.map(normalizedHeader);
  const layerIndex = normalized.findIndex((name) => name === 'layer' || name.endsWith('layer') || name === 'variable');
  const zoneIndex = normalized.findIndex((name) => ['aid', 'areaid', 'featureid', 'zoneid', 'polygonid', 'id'].includes(name));
  const stDevIndex = normalized.findIndex((name) => name.includes('standarddeviation') || name === 'stdev' || name === 'stddev' || name === 'sd');
  const countIndex = normalized.findIndex((name) => name === 'count' || name.includes('validpixelcount') || name === 'pixelcount');
  const fileIndex = parseZone(fileName);
  const defaultIndex = parseIndex(fileName);
  const samples: ParsedHlsSample[] = [];
  for (const line of lines.slice(headerIndex + 1)) {
    const row = parseCsvRow(line);
    const layerText = layerIndex >= 0 ? row[layerIndex] ?? '' : '';
    // عند غياب عمود Layer نستنتج المؤشر من نص الصف (اسم الحبيبة) ثم من اسم الملف.
    const rowIndex = row
      .map((cell) => /(?:^|[._\-\s])(NDVI|EVI|SAVI|MSAVI|NDMI|NDWI|NBR2|NBR|TVI)(?:[._\-\s]|$)/i.exec(cell)?.[1])
      .find((value): value is string => typeof value === 'string');
    const index =
      parseIndex(layerText) ??
      (rowIndex ? parseIndex(rowIndex) : null) ??
      defaultIndex ??
      (layerIndex < 0 ? 'NDVI' : null);
    if (!index) continue;
    const cell = row[meanIndex] ?? '';
    if (!cell.trim()) continue;
    const rawMean = Number(cell.replace(/,/g, ''));
    if (!Number.isFinite(rawMean)) continue;
    const mean = scaleValue(rawMean, index);
    if (index !== 'TVI' && (mean < -1.05 || mean > 1.05)) continue;
    const date = sampleDate(headers, row);
    if (!date) continue;
    const nextDate = new Date(date.getTime() + 24 * 60 * 60 * 1000);
    const rawStDev = stDevIndex >= 0 ? Number((row[stDevIndex] ?? '').replace(/,/g, '')) : 0;
    const rawCount = countIndex >= 0 ? Number((row[countIndex] ?? '').replace(/,/g, '')) : 0;
    samples.push({
      index,
      zoneId: (zoneIndex >= 0 ? parseZone(row[zoneIndex] ?? '') : null) ?? fileIndex ?? 'Z01',
      mean,
      stDev: Number.isFinite(rawStDev) ? scaleValue(rawStDev, index) : 0,
      sampleCount: Number.isFinite(rawCount) ? Math.max(0, Math.round(rawCount)) : 0,
      from: date.toISOString(),
      to: nextDate.toISOString(),
    });
  }
  return samples.sort((left, right) => left.from.localeCompare(right.from));
}
