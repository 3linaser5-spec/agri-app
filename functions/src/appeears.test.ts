import assert from 'node:assert/strict';
import test from 'node:test';
import { buildHlsAreaRequest, parseHlsStatisticsCsv } from './appeears';

test('builds a closed GeoJSON polygon and requests both NASA HLS-VI NDVI products', () => {
  const result = buildHlsAreaRequest(
    [
      { lat: 24.1, lng: 32.8 },
      { lat: 24.1, lng: 32.9 },
      { lat: 24.2, lng: 32.9 },
    ],
    'nabati-field-test',
    new Date('2026-11-06T15:00:00.000Z'),
  );

  const ring = result.params.geo.features[0]!.geometry.coordinates[0]!;
  assert.deepEqual(ring[0], ring[ring.length - 1]);
  assert.deepEqual(result.params.layers, [
    { product: 'HLSS30_VI.020', layer: 'NDVI' },
    { product: 'HLSL30_VI.020', layer: 'NDVI' },
  ]);
  assert.equal(result.params.dates[0]?.startDate, '08-08-2026');
  assert.equal(result.params.dates[0]?.endDate, '11-06-2026');
});

test('parses AppEEARS date rows and applies the HLS scale factor when needed', () => {
  const csv = [
    'File Name,Date,Layer,Mean,Standard Deviation,Count',
    'HLS-VI.S30.T36QWM.2026276T082021.v2.0.NDVI.tif,2026-10-03,NDVI,6432,1200,15',
    'HLS-VI.L30.T36QWM.2026279T080000.v2.0.NDVI.tif,2026-10-06,NDVI,0.51,0.09,12',
  ].join('\n');
  const samples = parseHlsStatisticsCsv(csv);

  assert.equal(samples.length, 2);
  assert.equal(samples[0]?.mean, 0.6432);
  assert.ok(Math.abs((samples[0]?.stDev ?? 0) - 0.12) < 1e-9);
  assert.equal(samples[0]?.sampleCount, 15);
  assert.equal(samples[0]?.from, '2026-10-03T00:00:00.000Z');
  assert.equal(samples[1]?.mean, 0.51);
});

test('extracts acquisition day from HLS granule names if the CSV has no date column', () => {
  const csv = [
    'Granule Name,Mean,Count',
    'HLS-VI.S30.T36QWM.2026276T082021.v2.0.NDVI.tif,4500,9',
  ].join('\n');
  const samples = parseHlsStatisticsCsv(csv);
  assert.equal(samples.length, 1);
  assert.equal(samples[0]?.mean, 0.45);
  assert.equal(samples[0]?.from, '2026-10-03T00:00:00.000Z');
});

test('ignores non-NDVI layers and out-of-range fill values', () => {
  const csv = [
    'Date,Layer,Mean,Count',
    '2026-10-03,NDVI,-19999,0',
    '2026-10-03,QA,9500,1',
    '2026-10-04,NDVI,0.62,8',
  ].join('\n');
  const samples = parseHlsStatisticsCsv(csv);
  assert.equal(samples.length, 1);
  assert.equal(samples[0]?.mean, 0.62);
});

test('rejects malformed statistics files rather than storing unverified output', () => {
  assert.throws(
    () => parseHlsStatisticsCsv('Date,Maximum\n2026-10-03,0.7'),
    /no mean column/,
  );
});
