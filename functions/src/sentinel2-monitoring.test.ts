import assert from 'node:assert/strict';
import test from 'node:test';
import {
  aggregateSentinel2Samples,
  buildSentinel2StatisticsRequest,
  parseSentinel2Stats,
  toUtmCoordinate,
  type Sentinel2PointSample,
} from './sentinel2-monitoring';
import type { HlsPoint } from './hls-analysis';

const fieldPoints: HlsPoint[] = [
  { id: 'p1', latitude: 30.0444, longitude: 31.2357, category: 'field' },
  { id: 'p2', latitude: 30.045, longitude: 31.236, category: 'field' },
  { id: 'p3', latitude: 30.046, longitude: 31.237, category: 'field' },
];

test('projects an agricultural point in Cairo to the correct northern UTM zone', () => {
  const projected = toUtmCoordinate(30.0444, 31.2357);
  assert.equal(projected.epsg, 32636);
  assert.ok(projected.easting > 300_000 && projected.easting < 400_000);
  assert.ok(projected.northing > 3_000_000 && projected.northing < 4_000_000);
});

test('rejects coordinates outside the UTM latitude range used for Sentinel-2 point jobs', () => {
  assert.throws(() => toUtmCoordinate(85, 0));
  assert.throws(() => toUtmCoordinate(10, 181));
});

test('builds daily Statistics API requests with a projected 10 m sample footprint', () => {
  const request = buildSentinel2StatisticsRequest(
    fieldPoints[0]!,
    new Date('2026-06-01T00:00:00.000Z'),
    new Date('2026-06-02T00:00:00.000Z'),
  );
  const input = request['input'] as Record<string, unknown>;
  const bounds = input['bounds'] as Record<string, unknown>;
  const properties = bounds['properties'] as Record<string, unknown>;
  const aggregation = request['aggregation'] as Record<string, unknown>;
  const timeRange = aggregation['timeRange'] as Record<string, unknown>;

  assert.equal(properties['crs'], 'http://www.opengis.net/def/crs/EPSG/0/32636');
  assert.equal(aggregation['resx'], 10);
  assert.equal(aggregation['resy'], 10);
  assert.equal((aggregation['aggregationInterval'] as Record<string, unknown>)['of'], 'P1D');
  assert.equal(timeRange['from'], '2026-06-01T00:00:00Z');
  assert.equal(timeRange['to'], '2026-06-03T00:00:00Z');
});

test('parses 10 m statistics, derived indices, and reflectance bands from the API response', () => {
  const means = [0.62, 0.55, 0.31, 0.28, -0.12, 0.04, 0.08, 0.12, 0.51];
  const bands = Object.fromEntries(means.map((mean, index) => [
    `B${index}`,
    { stats: { mean, sampleCount: 1, noDataCount: 0 } },
  ]));
  const parsed = parseSentinel2Stats({
    status: 'OK',
    data: [{
      interval: { from: '2026-06-01T00:00:00Z', to: '2026-06-02T00:00:00Z' },
      outputs: { metrics: { bands } },
    }],
  }, fieldPoints[0]!);

  assert.equal(parsed.length, 1);
  assert.equal(parsed[0]?.date, '2026-06-01');
  assert.equal(parsed[0]?.indices['NDVI_10M'], 0.62);
  assert.equal(parsed[0]?.indices['NDWI_MCF_10M'], -0.12);
  assert.equal(parsed[0]?.bands['S2_10M_B02'], 0.04);
  assert.equal(parsed[0]?.bands['S2_10M_B08'], 0.51);
});

test('skips intervals without clear pixels and rejects malformed provider responses', () => {
  const cloudy = parseSentinel2Stats({
    status: 'OK',
    data: [{
      interval: { from: '2026-06-01T00:00:00Z' },
      outputs: { metrics: { bands: { B0: { stats: { sampleCount: 1, noDataCount: 1 } } } } },
    }],
  }, fieldPoints[0]!);
  assert.deepEqual(cloudy, []);
  assert.throws(() => parseSentinel2Stats({ status: 'FAILED' }, fieldPoints[0]!));
});

test('aggregates daily point samples and preserves unique 10 m metrics', () => {
  const samples: Sentinel2PointSample[] = [
    {
      date: '2026-06-01', pointId: 'p1', latitude: 30.0444, longitude: 31.2357,
      indices: { NDVI_10M: 0.4, EVI_10M: 0.3 }, bands: { S2_10M_B08: 0.5 },
    },
    {
      date: '2026-06-01', pointId: 'p2', latitude: 30.045, longitude: 31.236,
      indices: { NDVI_10M: 0.6, EVI_10M: 0.5 }, bands: { S2_10M_B08: 0.7 },
    },
  ];
  const result = aggregateSentinel2Samples(samples, fieldPoints);
  assert.equal(result.length, 1);
  assert.equal(result[0]?.validPointCount, 2);
  assert.equal(result[0]?.totalPointCount, 3);
  assert.equal(result[0]?.metrics['NDVI_10M']?.mean, 0.5);
  assert.equal(result[0]?.metrics['NDVI_10M']?.median, 0.5);
  assert.equal(result[0]?.metrics['NDVI_10M']?.count, 2);
  assert.equal(result[0]?.bands['S2_10M_B08']?.mean, 0.6);
});
