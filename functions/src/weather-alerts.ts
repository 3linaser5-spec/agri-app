export type WeatherAlertKind = 'rain' | 'heat' | 'cold';

export interface WeatherPushAlert {
  kind: WeatherAlertKind;
  key: string;
  date: string;
  title: string;
  body: string;
}

interface ForecastDay {
  date: string;
  probability: number | null;
  precipitationMm: number;
  maximumTemperatureC: number;
  minimumTemperatureC: number;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function numericAt(values: unknown, index: number): number | null {
  if (!Array.isArray(values)) return null;
  const value = values[index];
  if (typeof value !== 'number' || !Number.isFinite(value)) return null;
  return value;
}

function dateAt(values: unknown, index: number): string | null {
  if (!Array.isArray(values)) return null;
  const value = values[index];
  return typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value)
    ? value
    : null;
}

function dateOffset(date: string, days: number): string {
  const [year, month, day] = date.split('-').map(Number);
  return new Date(Date.UTC(year, month - 1, day + days))
    .toISOString()
    .slice(0, 10);
}

function cairoTodayIso(now: Date = new Date()): string {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Africa/Cairo',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(now);
  const part = (type: string) => parts.find((item) => item.type === type)?.value;
  return `${part('year')}-${part('month')}-${part('day')}`;
}

function arabicDateLabel(date: string, today: string): string {
  if (date === today) return 'اليوم';
  if (date === dateOffset(today, 1)) return 'غدًا';
  const utcDate = new Date(`${date}T12:00:00.000Z`);
  return new Intl.DateTimeFormat('ar-EG', {
    weekday: 'long',
    timeZone: 'UTC',
  }).format(utcDate);
}

/**
 * Produces the same three-day rain/heat/cold warnings as the Flutter weather
 * model. It intentionally returns at most one alert per type per forecast scan.
 */
export function buildWeatherPushAlerts(
  payload: unknown,
  todayIso: string = cairoTodayIso(),
): WeatherPushAlert[] {
  if (!isRecord(payload) || !isRecord(payload['daily'])) return [];
  const daily = payload['daily'];
  const dates = daily['time'];
  if (!Array.isArray(dates)) return [];

  const availableDays = Math.min(dates.length, 3);
  const days: ForecastDay[] = [];
  for (let index = 0; index < availableDays; index += 1) {
    const date = dateAt(dates, index);
    const maximum = numericAt(daily['temperature_2m_max'], index);
    const minimum = numericAt(daily['temperature_2m_min'], index);
    const precipitation = numericAt(daily['precipitation_sum'], index);
    if (date === null || maximum === null || minimum === null || precipitation === null) {
      continue;
    }
    days.push({
      date,
      probability: numericAt(daily['precipitation_probability_max'], index),
      precipitationMm: precipitation,
      maximumTemperatureC: maximum,
      minimumTemperatureC: minimum,
    });
  }

  const alerts: WeatherPushAlert[] = [];
  let rainDay: ForecastDay | null = null;
  for (const day of days) {
    const probability = day.probability ?? 0;
    if (probability >= 60 || day.precipitationMm >= 5) {
      if (
        rainDay === null ||
        probability > (rainDay.probability ?? 0) ||
        day.precipitationMm > rainDay.precipitationMm
      ) {
        rainDay = day;
      }
    }
  }

  if (rainDay !== null) {
    const chance = rainDay.probability;
    const chanceText = chance === null ? '' : ` (احتمال ${chance}٪)`;
    const label = arabicDateLabel(rainDay.date, todayIso);
    alerts.push({
      kind: 'rain',
      key: `rain:${rainDay.date}`,
      date: rainDay.date,
      title: `أمطار متوقعة ${label}`,
      body: `كمية متوقعة ${rainDay.precipitationMm.toFixed(1)} مم${chanceText}. راجع مواعيد الري والرش.`,
    });
  }

  const hotDay = days
    .filter((day) => day.maximumTemperatureC >= 38)
    .reduce<ForecastDay | null>(
      (best, day) =>
        best === null || day.maximumTemperatureC > best.maximumTemperatureC
          ? day
          : best,
      null,
    );
  if (hotDay !== null) {
    alerts.push({
      kind: 'heat',
      key: `heat:${hotDay.date}`,
      date: hotDay.date,
      title: `حرارة مرتفعة ${arabicDateLabel(hotDay.date, todayIso)}`,
      body: `العظمى المتوقعة ${hotDay.maximumTemperatureC.toFixed(0)}°م. يُفضّل تجنّب الرش وقت الظهيرة.`,
    });
  }

  const coldDay = days
    .filter((day) => day.minimumTemperatureC <= 5)
    .reduce<ForecastDay | null>(
      (best, day) =>
        best === null || day.minimumTemperatureC < best.minimumTemperatureC
          ? day
          : best,
      null,
    );
  if (coldDay !== null) {
    alerts.push({
      kind: 'cold',
      key: `cold:${coldDay.date}`,
      date: coldDay.date,
      title: `برودة شديدة ${arabicDateLabel(coldDay.date, todayIso)}`,
      body: `الصغرى المتوقعة ${coldDay.minimumTemperatureC.toFixed(0)}°م. راقب المحاصيل الحساسة للبرد.`,
    });
  }

  return alerts;
}
