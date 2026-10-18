import { createHash } from 'node:crypto';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { getMessaging, type Message } from 'firebase-admin/messaging';
import { initializeApp } from 'firebase-admin/app';
import { logger } from 'firebase-functions';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { buildWeatherPushAlerts, type WeatherPushAlert } from './weather-alerts';

initializeApp();

const db = getFirestore();
const WEATHER_COLLECTION = 'weather_push_devices';
const STATE_COLLECTION = 'weather_push_state';
const INVALID_TOKEN_CODES = new Set([
  'messaging/invalid-registration-token',
  'messaging/registration-token-not-registered',
]);

interface WeatherDevice {
  uid: string;
  token: string;
  latitude: number;
  longitude: number;
  ref: FirebaseFirestore.DocumentReference;
}

interface LocationGroup {
  latitude: number;
  longitude: number;
  devices: WeatherDevice[];
}

function isValidCoordinate(latitude: number, longitude: number): boolean {
  return (
    Number.isFinite(latitude) &&
    Number.isFinite(longitude) &&
    latitude >= -90 &&
    latitude <= 90 &&
    longitude >= -180 &&
    longitude <= 180
  );
}

function readDevices(): Promise<FirebaseFirestore.QuerySnapshot> {
  return db.collectionGroup(WEATHER_COLLECTION).get();
}

function dateKeyFromAlertKey(key: string): string | null {
  const match = /^(rain|heat|cold):(\d{4}-\d{2}-\d{2})$/.exec(key);
  return match?.[2] ?? null;
}

function recentAlertKeys(value: unknown, todayIso: string): Set<string> {
  if (!Array.isArray(value)) return new Set<string>();
  const retentionStart = new Date(`${todayIso}T12:00:00.000Z`);
  retentionStart.setUTCDate(retentionStart.getUTCDate() - 7);
  const minimumDate = retentionStart.toISOString().slice(0, 10);
  return new Set(
    value.filter(
      (item): item is string =>
        typeof item === 'string' &&
        dateKeyFromAlertKey(item) !== null &&
        (dateKeyFromAlertKey(item) as string) >= minimumDate,
    ),
  );
}

async function fetchForecast(latitude: number, longitude: number): Promise<unknown> {
  const url = new URL('https://api.open-meteo.com/v1/forecast');
  url.searchParams.set('latitude', latitude.toFixed(2));
  url.searchParams.set('longitude', longitude.toFixed(2));
  url.searchParams.set(
    'daily',
    'temperature_2m_max,temperature_2m_min,precipitation_probability_max,precipitation_sum',
  );
  url.searchParams.set('forecast_days', '3');
  url.searchParams.set('timezone', 'auto');

  const response = await fetch(url, { signal: AbortSignal.timeout(15_000) });
  if (!response.ok) {
    throw new Error(`Weather provider returned HTTP ${response.status}`);
  }
  return response.json() as Promise<unknown>;
}

async function deliverWeatherAlerts(
  device: WeatherDevice,
  alerts: WeatherPushAlert[],
  todayIso: string,
): Promise<boolean> {
  const stateRef = db
    .collection('users')
    .doc(device.uid)
    .collection(STATE_COLLECTION)
    .doc(createHash('sha256').update(device.token).digest('hex'));
  const state = await stateRef.get();
  const sentKeys = recentAlertKeys(state.get('sentKeys'), todayIso);
  const pending = alerts.filter((alert) => !sentKeys.has(alert.key));
  if (pending.length === 0) return false;

  const title =
    pending.length === 1 ? pending[0]!.title : 'تنبيهات جوية للمزرعة';
  const body = pending
    .map((alert) => `${alert.title}: ${alert.body}`)
    .join(' • ')
    .slice(0, 3500);
  const message: Message = {
    token: device.token,
    notification: { title, body },
    data: {
      type: 'weather_alert',
      kinds: pending.map((alert) => alert.kind).join(','),
      dates: pending.map((alert) => alert.date).join(','),
    },
    android: {
      priority: 'high',
      notification: { channelId: 'weather_alerts' },
    },
  };

  try {
    await getMessaging().send(message);
    for (const alert of pending) sentKeys.add(alert.key);
    await stateRef.set(
      {
        sentKeys: [...sentKeys],
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    return true;
  } catch (error) {
    const code =
      typeof error === 'object' && error !== null && 'code' in error
        ? String((error as { code: unknown }).code)
        : '';
    if (INVALID_TOKEN_CODES.has(code)) {
      await device.ref.delete();
      await stateRef.delete();
      logger.info('Removed an invalid weather token registration');
      return false;
    }
    logger.warn('Failed to send a weather push message', { code });
    return false;
  }
}

async function processLocationGroup(
  group: LocationGroup,
  todayIso: string,
): Promise<number> {
  let forecast: unknown;
  try {
    forecast = await fetchForecast(group.latitude, group.longitude);
  } catch (error) {
    logger.warn('Weather forecast request failed for a location group', {
      deviceCount: group.devices.length,
      error: error instanceof Error ? error.message : String(error),
    });
    return 0;
  }

  const alerts = buildWeatherPushAlerts(forecast, todayIso);
  if (alerts.length === 0) return 0;

  let delivered = 0;
  for (let start = 0; start < group.devices.length; start += 20) {
    const batch = group.devices.slice(start, start + 20);
    const results = await Promise.all(
      batch.map((device) => deliverWeatherAlerts(device, alerts, todayIso)),
    );
    delivered += results.filter(Boolean).length;
  }
  return delivered;
}

/**
 * Sends personalized weather notifications to opted-in installations every
 * three hours. The server reads FCM tokens and approximate coordinates only from
 * owner-scoped Firestore registrations; clients cannot write delivery state.
 */
export const dispatchWeatherPushAlerts = onSchedule(
  {
    schedule: 'every 3 hours',
    timeZone: 'Africa/Cairo',
    region: 'europe-west1',
    timeoutSeconds: 540,
    maxInstances: 1,
    concurrency: 1,
  },
  async () => {
    const snapshot = await readDevices();
    const groups = new Map<string, LocationGroup>();

    for (const document of snapshot.docs) {
      const segments = document.ref.path.split('/');
      if (
        segments.length !== 4 ||
        segments[0] !== 'users' ||
        segments[2] !== WEATHER_COLLECTION
      ) {
        continue;
      }

      const data = document.data();
      const token = data['token'];
      const latitude = data['latitude'];
      const longitude = data['longitude'];
      if (
        data['enabled'] !== true ||
        typeof token !== 'string' ||
        token !== document.id ||
        typeof latitude !== 'number' ||
        typeof longitude !== 'number' ||
        !isValidCoordinate(latitude, longitude)
      ) {
        continue;
      }

      // Two-decimal coordinates reduce sensitive precision and group nearby farms.
      const roundedLatitude = Number(latitude.toFixed(2));
      const roundedLongitude = Number(longitude.toFixed(2));
      const groupKey = `${roundedLatitude},${roundedLongitude}`;
      const device: WeatherDevice = {
        uid: segments[1]!,
        token,
        latitude: roundedLatitude,
        longitude: roundedLongitude,
        ref: document.ref,
      };
      const existing = groups.get(groupKey);
      if (existing) {
        existing.devices.push(device);
      } else {
        groups.set(groupKey, {
          latitude: roundedLatitude,
          longitude: roundedLongitude,
          devices: [device],
        });
      }
    }

    const todayIso = new Intl.DateTimeFormat('en-CA', {
      timeZone: 'Africa/Cairo',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    })
      .formatToParts(new Date())
      .reduce<Record<string, string>>((result, part) => {
        result[part.type] = part.value;
        return result;
      }, {});
    const today = `${todayIso['year']}-${todayIso['month']}-${todayIso['day']}`;
    const locationGroups = [...groups.values()];
    let delivered = 0;

    // Bound concurrency so a large number of distinct locations cannot flood
    // Open-Meteo or FCM in a single scheduled invocation.
    for (let start = 0; start < locationGroups.length; start += 4) {
      const batch = locationGroups.slice(start, start + 4);
      const results = await Promise.all(
        batch.map((group) => processLocationGroup(group, today)),
      );
      delivered += results.reduce((total, count) => total + count, 0);
    }

    logger.info('Weather push scan completed', {
      registeredDevices: [...groups.values()].reduce(
        (total, group) => total + group.devices.length,
        0,
      ),
      roundedLocations: groups.size,
      deliveredMessages: delivered,
    });
  },
);
