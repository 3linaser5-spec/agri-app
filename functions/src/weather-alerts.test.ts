import assert from 'node:assert/strict';
import test from 'node:test';
import { buildWeatherPushAlerts } from './weather-alerts';

const today = '2026-10-18';

function forecast(overrides: Partial<Record<string, unknown>> = {}) {
  return {
    daily: {
      time: ['2026-10-18', '2026-10-19', '2026-10-20', '2026-10-21'],
      temperature_2m_max: [30, 39, 41, 45],
      temperature_2m_min: [18, 4, 2, -1],
      precipitation_probability_max: [10, 75, 20, 100],
      precipitation_sum: [0, 3, 8, 30],
      ...overrides,
    },
  };
}

test('creates one alert per type from the most significant of the next three days', () => {
  const alerts = buildWeatherPushAlerts(forecast(), today);
  assert.deepEqual(alerts.map((alert) => alert.kind), ['rain', 'heat', 'cold']);
  assert.equal(alerts[0]?.date, '2026-10-20');
  assert.equal(alerts[0]?.key, 'rain:2026-10-20');
  assert.equal(alerts[1]?.date, '2026-10-20');
  assert.equal(alerts[2]?.date, '2026-10-20');
  assert.match(alerts[0]?.body ?? '', /8\.0 مم/);
});

test('does not create warnings below the app thresholds', () => {
  const alerts = buildWeatherPushAlerts(
    forecast({
      temperature_2m_max: [37.9, 37, 36],
      temperature_2m_min: [5.1, 6, 7],
      precipitation_probability_max: [59, 20, 40],
      precipitation_sum: [4.9, 0, 4.99],
    }),
    today,
  );
  assert.deepEqual(alerts, []);
});

test('ignores severe weather outside the three-day warning window', () => {
  const alerts = buildWeatherPushAlerts(
    forecast({
      temperature_2m_max: [30, 31, 32, 50],
      temperature_2m_min: [15, 14, 13, -5],
      precipitation_probability_max: [0, 0, 0, 100],
      precipitation_sum: [0, 0, 0, 50],
    }),
    today,
  );
  assert.deepEqual(alerts, []);
});

test('ignores malformed or incomplete API responses safely', () => {
  assert.deepEqual(buildWeatherPushAlerts(null, today), []);
  assert.deepEqual(buildWeatherPushAlerts({ daily: { time: ['bad'] } }, today), []);
});
