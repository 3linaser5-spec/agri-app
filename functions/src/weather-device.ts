export interface WeatherDeviceRegistration {
  token: string;
  latitude: number;
  longitude: number;
}

/**
 * Validates an authenticated client's device registration and rounds location
 * before persistence. A null result means the payload must be rejected.
 */
export function parseWeatherDeviceRegistration(
  value: unknown,
): WeatherDeviceRegistration | null {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    return null;
  }

  const data = value as Record<string, unknown>;
  const keys = Object.keys(data).sort();
  if (keys.join(',') !== 'latitude,longitude,token') return null;

  const { token, latitude, longitude } = data;
  if (
    typeof token !== 'string' ||
    token.length < 1 ||
    token.length > 1500 ||
    token.includes('/') ||
    /[\u0000-\u001f\u007f]/.test(token) ||
    typeof latitude !== 'number' ||
    !Number.isFinite(latitude) ||
    latitude < -90 ||
    latitude > 90 ||
    typeof longitude !== 'number' ||
    !Number.isFinite(longitude) ||
    longitude < -180 ||
    longitude > 180
  ) {
    return null;
  }

  return {
    token,
    latitude: Number(latitude.toFixed(2)),
    longitude: Number(longitude.toFixed(2)),
  };
}
