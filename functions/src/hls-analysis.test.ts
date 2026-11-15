import assert from 'node:assert/strict';
import test from 'node:test';
import {
  aggregateHlsSamples,
  buildHlsAlerts,
  decodeHlsFmask,
  parseHlsCsv,
  parseHlsSamples,
  pointInHlsPolygon,
  sampleHlsPoints,
  normalizeHlsPointValue,
  validateHlsPolygon,
  type HlsObservation,
  type HlsSample,
} from './hls-analysis';

const square = [
  { latitude: 30, longitude: 30 },
  { latitude: 30, longitude: 30.02 },
  { latitude: 30.02, longitude: 30.02 },
  { latitude: 30.02, longitude: 30 },
];

test('rejects malformed polygons and accepts an open valid ring', () => {
  assert.throws(() => validateHlsPolygon(null));
  assert.throws(() => validateHlsPolygon([
    { latitude: 91, longitude: 1 },
    { latitude: 0, longitude: 1 },
    { latitude: 1, longitude: 0 },
  ]));
  assert.throws(() => validateHlsPolygon([
    { latitude: 0, longitude: 0 },
    { latitude: 1, longitude: 1 },
    { latitude: 2, longitude: 2 },
  ]));
  assert.throws(() => validateHlsPolygon([
    ...square,
    ...square,
    ...square,
    ...square,
    ...square,
    ...square,
  ]));
  assert.equal(validateHlsPolygon(square).length, 4);
  assert.equal(validateHlsPolygon([...square, square[0]!]).length, 4);
});

test('samples no more than nine points and every sample is inside the polygon', () => {
  const points = sampleHlsPoints(square);
  assert.ok(points.length >= 1 && points.length <= 9);
  for (const point of points) {
    assert.equal(pointInHlsPolygon(point, square), true);
    assert.equal(point.category, 'field');
  }
  assert.equal(pointInHlsPolygon({ latitude: 31, longitude: 31 }, square), false);
});

test('finds an interior sample for a narrow concave field missed by the 3x3 grid', () => {
  const cShapedField = [
    { latitude: 30, longitude: 31 },
    { latitude: 30, longitude: 31.04 },
    { latitude: 30.002, longitude: 31.04 },
    { latitude: 30.002, longitude: 31.002 },
    { latitude: 30.038, longitude: 31.002 },
    { latitude: 30.038, longitude: 31.04 },
    { latitude: 30.04, longitude: 31.04 },
    { latitude: 30.04, longitude: 31 },
  ];
  const points = sampleHlsPoints(cShapedField);
  assert.equal(points.length, 1);
  assert.equal(pointInHlsPolygon(points[0]!, cShapedField), true);
});

test('parses quoted commas, escaped quotes, and line breaks in CSV fields', () => {
  const rows = parseHlsCsv(
    'Date,Latitude,Longitude,ID,Category,Product,Layer,Value\r\n' +
    '2026-05-02,30.1,31.2,"field ""A"", east",field,HLSL30.020, B04 ,5000\r\n',
  );
  assert.equal(rows.length, 1);
  assert.equal(rows[0]?.['id'], 'field "A", east');
  assert.equal(rows[0]?.['layer'], ' B04 ');
  const samples = parseHlsSamples(
    'Date,Latitude,Longitude,ID,Category,Product,Layer,Value\n' +
    '2026-05-02,30.1,31.2,"field ""A"", east",field,HLSL30.020,B04,5000\n',
  );
  assert.equal(samples[0]?.pointId, 'field "A", east');
  assert.equal(samples[0]?.product, 'HLSL30.020');
});

test('ignores fill values while preserving AppEEARS Point values already scaled to physical units', () => {
  assert.equal(normalizeHlsPointValue('HLSL30.020', 'B04', 0.5), 0.5);
  assert.equal(normalizeHlsPointValue('HLSL30.020', 'B10', 12.5), 12.5);
  assert.equal(normalizeHlsPointValue('HLSS30.020', 'B11', 0.5), 0.5);
  assert.equal(normalizeHlsPointValue('HLSL30_VI.020', 'NDVI', 0.65), 0.65);
  assert.equal(normalizeHlsPointValue('HLSS30_VI.020', 'TVI', 1.25), 1.25);
  assert.equal(normalizeHlsPointValue('HLSS30.020', 'SZA', 45), 45);
  assert.equal(normalizeHlsPointValue('HLSL30.020', 'Fmask', 255), null);
  assert.equal(normalizeHlsPointValue('HLSL30.020', 'SZA', 40000), null);
  assert.equal(normalizeHlsPointValue('HLSS30_VI.020', 'NDVI', -9999), null);
  assert.equal(normalizeHlsPointValue('HLSL30.020', 'B04', -19999), null);
});

test('decodes Fmask cloud, adjacency, shadow, snow, water, and aerosol flags', () => {
  const clearWater = decodeHlsFmask(1 << 5);
  assert.equal(clearWater?.water, true);
  assert.equal(clearWater?.clear, true);
  assert.equal(decodeHlsFmask(1)?.cirrus, true);
  assert.equal(decodeHlsFmask(1)?.clear, false);
  assert.equal(decodeHlsFmask(1 << 1)?.cloud, true);
  assert.equal(decodeHlsFmask(1 << 1)?.clear, false);
  assert.equal(decodeHlsFmask(1 << 2)?.adjacent, true);
  assert.equal(decodeHlsFmask(1 << 3)?.shadow, true);
  assert.equal(decodeHlsFmask(1 << 4)?.snowIce, true);
  assert.equal(decodeHlsFmask(2 << 6)?.aerosol, true);
  assert.equal(decodeHlsFmask(-9999), null);
  assert.equal(decodeHlsFmask(255), null);
});

test('computes NDRE only from clear Sentinel-2 point samples and aggregates means/medians', () => {
  const samples: HlsSample[] = [
    { date: '2026-05-01', pointId: 'p1', product: 'HLSS30.020', layer: 'Fmask', value: 0 },
    { date: '2026-05-01', pointId: 'p1', product: 'HLSS30.020', layer: 'B8A', value: 0.7 },
    { date: '2026-05-01', pointId: 'p1', product: 'HLSS30.020', layer: 'B05', value: 0.3 },
    { date: '2026-05-01', pointId: 'p1', product: 'HLSS30_VI.020', layer: 'NDVI', value: 0.6 },
    { date: '2026-05-01', pointId: 'p2', product: 'HLSS30.020', layer: 'Fmask', value: 1 << 1 },
    { date: '2026-05-01', pointId: 'p2', product: 'HLSS30.020', layer: 'B8A', value: 0.8 },
    { date: '2026-05-01', pointId: 'p2', product: 'HLSS30.020', layer: 'B05', value: 0.2 },
    { date: '2026-05-01', pointId: 'p2', product: 'HLSS30_VI.020', layer: 'NDVI', value: 0.4 },
  ];
  const observations = aggregateHlsSamples(samples, [
    { id: 'p1', latitude: 30, longitude: 31, category: 'field' },
    { id: 'p2', latitude: 30.1, longitude: 31.1, category: 'field' },
  ]);
  assert.equal(observations.length, 1);
  const observation = observations[0]!;
  assert.ok(Math.abs((observation.metrics['NDRE']?.mean ?? 0) - 0.4) < 1e-12);
  assert.ok(Math.abs((observation.metrics['HLSS30_B8A']?.mean ?? 0) - 0.7) < 1e-12);
  assert.equal(observation.metrics['NDVI']?.mean, 0.6);
  assert.equal(observation.metrics['NDVI']?.median, 0.6);
  assert.equal(observation.validPointCount, 1);
  assert.equal(observation.qa.clearPointCount, 1);
  assert.equal(observation.qa.cirrusPointCount, 0);
  assert.equal(observation.qa.cloudPointCount, 1);
  assert.ok(Math.abs((observation.points.find((point) => point.id === 'p1')?.metrics['NDRE'] ?? 0) - 0.4) < 1e-12);
  assert.equal(observation.points.find((point) => point.id === 'p2')?.metrics['NDRE'], undefined);
  assert.equal(observation.points.find((point) => point.id === 'p2')?.metrics['NDVI'], undefined);
});

test('alerts only on large NDVI or NDMI declines across successive valid dates', () => {
  const observations = [
    observation('2026-05-01', 0.72, 0.45),
    observation('2026-05-08', 0.69, 0.43),
    observation('2026-05-20', 0.48, 0.25),
  ];
  const alerts = buildHlsAlerts(observations);
  assert.deepEqual(alerts.get('2026-05-01'), undefined);
  assert.deepEqual(alerts.get('2026-05-08'), undefined);
  assert.equal(alerts.get('2026-05-20')?.length, 2);
  assert.match(alerts.get('2026-05-20')?.[0]?.message ?? '', /فحص الحقل ميدانيًا/);
  assert.match(alerts.get('2026-05-20')?.[0]?.message ?? '', /ليس تشخيصًا/);
  assert.equal(buildHlsAlerts([
    observation('2026-06-01', 0.3, 0.3),
    observation('2026-06-02', 0.2, 0.3),
  ]).size, 0);
});

function observation(date: string, ndvi: number, ndmi: number): HlsObservation {
  return {
    date,
    validPointCount: 1,
    totalPointCount: 1,
    qa: {
      clearPointCount: 1,
      flaggedPointCount: 0,
      cirrusPointCount: 0,
      cloudPointCount: 0,
      adjacentPointCount: 0,
      shadowPointCount: 0,
      snowIcePointCount: 0,
      waterPointCount: 0,
      aerosolPointCount: 0,
    },
    metrics: {
      NDVI: { mean: ndvi, median: ndvi, count: 1 },
      NDMI: { mean: ndmi, median: ndmi, count: 1 },
    },
    points: [],
    alerts: [],
  };
}
