import assert from 'node:assert/strict';
import test from 'node:test';
import { HLS_INDEX_KEYS, buildHlsAreaRequest, buildHlsZones, parseHlsStatisticsCsv } from './appeears';

const square = [
  { lat: 24.1, lng: 32.8 },
  { lat: 24.1, lng: 32.9 },
  { lat: 24.2, lng: 32.9 },
  { lat: 24.2, lng: 32.8 },
];

test('builds a closed GeoJSON feature collection covering every HLS-VI index', () => {
  const result = buildHlsAreaRequest(square, 'nabati-field-test', new Date('2026-11-06T15:00:00.000Z'));

  assert.equal(result.params.layers.length, HLS_INDEX_KEYS.length * 2);
  assert.deepEqual(
    result.params.layers.map((layer) => layer.layer),
    [...HLS_INDEX_KEYS, ...HLS_INDEX_KEYS],
  );
  const features = result.params.geo.features;
  assert.ok(features.length >= 1);
  for (const feature of features) {
    const ring = feature.geometry.coordinates[0]!;
    assert.deepEqual(ring[0], ring[ring.length - 1]);
    assert.equal(feature.properties.zoneId, feature.id);
  }
  assert.equal(result.params.dates[0]?.startDate, '08-08-2026');
  assert.equal(result.params.dates[0]?.endDate, '11-06-2026');
});

test('splits a field into numbered interior zones without gaps', () => {
  const zones = buildHlsZones(square);
  assert.ok(zones.length > 1);
  assert.deepEqual(
    zones.map((zone) => zone.id),
    zones.map((_, index) => `Z${String(index + 1).padStart(2, '0')}`),
  );
  for (const zone of zones) {
    assert.ok(zone.vertices.length >= 3);
    assert.ok(zone.center.lat >= 24.1 && zone.center.lat <= 24.2);
    assert.ok(zone.center.lng >= 32.8 && zone.center.lng <= 32.9);
  }
});

test('parses every index row and applies the HLS scale factor when needed', () => {
  const csv = [
    'Date,Layer,Mean,Standard Deviation,Count',
    '2026-10-03,NDVI,6432,1200,15',
    '2026-10-03,EVI,0.42,0.09,12',
    '2026-10-03,NDMI,3100,800,12',
    '2026-10-03,TVI,45,7,12',
  ].join('\n');
  const samples = parseHlsStatisticsCsv(csv);

  assert.equal(samples.length, 4);
  assert.equal(samples[0]?.index, 'NDVI');
  assert.equal(samples[0]?.mean, 0.6432);
  assert.ok(Math.abs((samples[0]?.stDev ?? 0) - 0.12) < 1e-9);
  assert.equal(samples[0]?.sampleCount, 15);
  assert.equal(samples[0]?.from, '2026-10-03T00:00:00.000Z');
  assert.equal(samples[1]?.mean, 0.42);
  assert.equal(samples[2]?.mean, 0.31);
  assert.equal(samples[3]?.mean, 0.45);
});

test('keeps the area id so weak zones stay distinguishable inside one field', () => {
  const csv = [
    'AID,Date,Layer,Mean,Count',
    'aid0001,2026-10-03,NDVI,0.62,9',
    'aid0002,2026-10-03,NDVI,0.28,9',
  ].join('\n');
  const samples = parseHlsStatisticsCsv(csv);
  assert.deepEqual(
    samples.map((sample) => sample.zoneId),
    ['Z01', 'Z02'],
  );
});

test('falls back to the feature id embedded in the statistics file name', () => {
  const csv = ['Date,Layer,Mean,Count', '2026-10-04,NDVI,0.5,6'].join('\n');
  const samples = parseHlsStatisticsCsv(csv, 'HLSS30-VI-020-Statistics-aid0003.csv');
  assert.equal(samples[0]?.zoneId, 'Z03');
});

test('extracts acquisition day from HLS granule names if the CSV has no date column', () => {
  const csv = ['Granule Name,Mean,Count', 'HLS-VI.S30.T36QWM.2026276T082021.v2.0.NDVI.tif,4500,9'].join('\n');
  const samples = parseHlsStatisticsCsv(csv);
  assert.equal(samples.length, 1);
  assert.equal(samples[0]?.mean, 0.45);
  assert.equal(samples[0]?.from, '2026-10-03T00:00:00.000Z');
});

test('ignores quality rows and out-of-range fill values', () => {
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
  assert.throws(() => parseHlsStatisticsCsv('Date,Maximum\n2026-10-03,0.7'), /no mean column/);
});
