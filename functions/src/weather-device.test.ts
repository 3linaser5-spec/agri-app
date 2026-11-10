import assert from 'node:assert/strict';
import test from 'node:test';
import { parseWeatherDeviceRegistration } from './weather-device';

test('accepts an exact registration payload and rounds coordinates', () => {
  assert.deepEqual(
    parseWeatherDeviceRegistration({
      token: 'fcm-registration-token',
      latitude: 30.0444,
      longitude: 31.2357,
    }),
    {
      token: 'fcm-registration-token',
      latitude: 30.04,
      longitude: 31.24,
    },
  );
});

test('rejects malformed payloads and paths in the token', () => {
  assert.equal(parseWeatherDeviceRegistration(null), null);
  assert.equal(parseWeatherDeviceRegistration({ token: 'x' }), null);
  assert.equal(
    parseWeatherDeviceRegistration({
      token: 'invalid/path',
      latitude: 30,
      longitude: 31,
    }),
    null,
  );
  assert.equal(
    parseWeatherDeviceRegistration({
      token: 'valid-token',
      latitude: 30,
      longitude: 31,
      uid: 'caller-controlled',
    }),
    null,
  );
});

test('rejects non-finite and out-of-range coordinates', () => {
  assert.equal(
    parseWeatherDeviceRegistration({
      token: 'valid-token',
      latitude: Number.NaN,
      longitude: 31,
    }),
    null,
  );
  assert.equal(
    parseWeatherDeviceRegistration({
      token: 'valid-token',
      latitude: 91,
      longitude: 31,
    }),
    null,
  );
  assert.equal(
    parseWeatherDeviceRegistration({
      token: 'valid-token',
      latitude: 30,
      longitude: -181,
    }),
    null,
  );
});
