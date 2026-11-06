export interface HlsVertex {
  lat: number;
  lng: number;
}

export interface ParsedHlsSample {
  mean: number;
  stDev: number;
  sampleCount: number;
  from: string;
  to: string;
}

export interface AppEearsTaskRequest {
  task_type: 'area';
  task_name: string;
  params: {
    dates: Array<{ startDate: string; endDate: string }>;
    layers: Array<{ product: string; layer: 'NDVI' }>;
    output: { format: { type: 'geotiff' }; projection: 'native' };
    geo: {
      type: 'FeatureCollection';
      features: Array<{
        type: 'Feature';
        geometry: { type: 'Polygon'; coordinates: number[][][] };
        properties: Record<string, never>;
      }>;
      fileName: string;
    };
  };
}

function formatAppEearsDate(date: Date): string {
  const month = String(date.getUTCMonth() + 1).padStart(2, '0');
  const day = String(date.getUTCDate()).padStart(2, '0');
  return `${month}-${day}-${date.getUTCFullYear()}`;
}

export function buildHlsAreaRequest(
  vertices: HlsVertex[],
  taskName: string,
  now = new Date(),
): AppEearsTaskRequest {
  if (vertices.length < 3 || vertices.length > 100) {
    throw new Error('HLS boundary must contain between 3 and 100 vertices');
  }
  const ring = vertices.map(({ lat, lng }) => [lng, lat]);
  const first = ring[0];
  const last = ring[ring.length - 1];
  if (!first || !last) throw new Error('HLS boundary has no coordinates');
  if (first[0] !== last[0] || first[1] !== last[1]) ring.push([...first]);

  const end = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
  const start = new Date(end.getTime() - 90 * 24 * 60 * 60 * 1000);

  return {
    task_type: 'area',
    task_name: taskName.slice(0, 80),
    params: {
      dates: [{
        startDate: formatAppEearsDate(start),
        endDate: formatAppEearsDate(end),
      }],
      layers: [
        { product: 'HLSS30_VI.020', layer: 'NDVI' },
        { product: 'HLSL30_VI.020', layer: 'NDVI' },
      ],
      output: { format: { type: 'geotiff' }, projection: 'native' },
      geo: {
        type: 'FeatureCollection',
        features: [{
          type: 'Feature',
          geometry: { type: 'Polygon', coordinates: [ring] },
          properties: {},
        }],
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
    if (dayOfYear >= 1 && dayOfYear <= 366) {
      return new Date(Date.UTC(year, 0, dayOfYear));
    }
  }
  if (/^\d{8}$/.test(value)) {
    const year = Number(value.slice(0, 4));
    const month = Number(value.slice(4, 6));
    const day = Number(value.slice(6, 8));
    const parsed = new Date(Date.UTC(year, month - 1, day));
    if (
      parsed.getUTCFullYear() === year &&
      parsed.getUTCMonth() === month - 1 &&
      parsed.getUTCDate() === day
    ) return parsed;
  }
  return null;
}

function sampleDate(headers: string[], row: string[]): Date | null {
  const dateHeaders = headers
    .map((header, index) => ({ header: normalizedHeader(header), index }))
    .filter(({ header }) =>
      header.includes('date') || header.includes('time') || header.includes('filename') ||
      header.includes('granule') || header === 'file',
    );
  for (const item of dateHeaders) {
    const value = row[item.index] ?? '';
    const date = parseDate(value);
    if (date) return date;
  }
  for (const value of row) {
    const date = parseDate(value);
    if (date) return date;
  }
  return null;
}

function scaledNdvi(value: number): number {
  // HLS-VI NDVI is int16 with a 0.0001 scale factor. AppEEARS statistics may
  // already be scaled, so apply it only when the returned value is outside NDVI range.
  return Math.abs(value) > 1.0001 ? value * 0.0001 : value;
}

export function parseHlsStatisticsCsv(content: string): ParsedHlsSample[] {
  const lines = content.replace(/^\uFEFF/, '').split(/\r?\n/).filter((line) => line.trim().length > 0);
  if (lines.length < 2) return [];

  let headerIndex = -1;
  let headers: string[] = [];
  let meanIndex = -1;
  for (let index = 0; index < Math.min(lines.length, 30); index += 1) {
    const candidate = parseCsvRow(lines[index]!);
    const normalized = candidate.map(normalizedHeader);
    const foundMean = normalized.findIndex((name) => name === 'mean' || name.endsWith('mean'));
    if (foundMean >= 0) {
      headerIndex = index;
      headers = candidate;
      meanIndex = foundMean;
      break;
    }
  }
  if (headerIndex < 0 || meanIndex < 0) {
    throw new Error('AppEEARS statistics CSV has no mean column');
  }

  const normalized = headers.map(normalizedHeader);
  const layerIndex = normalized.findIndex((name) => name === 'layer');
  const stDevIndex = normalized.findIndex((name) =>
    name.includes('standarddeviation') || name === 'stdev' || name === 'stddev' || name === 'sd',
  );
  const countIndex = normalized.findIndex((name) =>
    name === 'count' || name.includes('validpixelcount') || name === 'pixelcount',
  );
  const samples: ParsedHlsSample[] = [];
  for (const line of lines.slice(headerIndex + 1)) {
    const row = parseCsvRow(line);
    if (layerIndex >= 0 && (row[layerIndex] ?? '').trim().toLowerCase() !== 'ndvi') continue;
    const meanCell = row[meanIndex] ?? '';
    if (meanCell.trim().length === 0) continue;
    const rawMean = Number(meanCell.replace(/,/g, ''));
    if (!Number.isFinite(rawMean)) continue;
    const mean = scaledNdvi(rawMean);
    if (mean < -1.05 || mean > 1.05) continue;
    const date = sampleDate(headers, row);
    if (!date) continue;
    const nextDate = new Date(date.getTime() + 24 * 60 * 60 * 1000);
    const rawStDev = stDevIndex >= 0
      ? Number((row[stDevIndex] ?? '').replace(/,/g, ''))
      : 0;
    const rawCount = countIndex >= 0
      ? Number((row[countIndex] ?? '').replace(/,/g, ''))
      : 0;
    samples.push({
      mean,
      stDev: Number.isFinite(rawStDev) ? scaledNdvi(rawStDev) : 0,
      sampleCount: Number.isFinite(rawCount) ? Math.max(0, Math.round(rawCount)) : 0,
      from: date.toISOString(),
      to: nextDate.toISOString(),
    });
  }
  return samples.sort((left, right) => left.from.localeCompare(right.from));
}
