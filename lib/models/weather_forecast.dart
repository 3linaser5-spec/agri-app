class WeatherForecastDay {
  const WeatherForecastDay({
    required this.date,
    required this.minimumTemperatureC,
    required this.maximumTemperatureC,
    required this.precipitationMm,
    required this.weatherCode,
    this.precipitationProbability,
  });

  final DateTime date;
  final double minimumTemperatureC;
  final double maximumTemperatureC;
  final double precipitationMm;
  final int weatherCode;
  final int? precipitationProbability;

  factory WeatherForecastDay.fromApi(Map<String, dynamic> daily, int index) {
    final times = _listAt(daily, 'time');
    if (index >= times.length || times[index] is! String) {
      throw const FormatException('Missing daily weather date');
    }
    final minimumTemperature = _doubleAt(daily, 'temperature_2m_min', index);
    final maximumTemperature = _doubleAt(daily, 'temperature_2m_max', index);
    if (minimumTemperature == null || maximumTemperature == null) {
      throw const FormatException('Missing daily temperature values');
    }

    return WeatherForecastDay(
      date: DateTime.parse(times[index] as String),
      minimumTemperatureC: minimumTemperature,
      maximumTemperatureC: maximumTemperature,
      precipitationMm: _doubleAt(daily, 'precipitation_sum', index) ?? 0,
      precipitationProbability:
          _intAt(daily, 'precipitation_probability_max', index),
      weatherCode: _intAt(daily, 'weather_code', index) ?? -1,
    );
  }

  factory WeatherForecastDay.fromJson(Map<String, dynamic> json) {
    return WeatherForecastDay(
      date: DateTime.parse(json['date'] as String),
      minimumTemperatureC: (json['min_c'] as num).toDouble(),
      maximumTemperatureC: (json['max_c'] as num).toDouble(),
      precipitationMm: (json['rain_mm'] as num).toDouble(),
      precipitationProbability: (json['rain_probability'] as num?)?.toInt(),
      weatherCode: (json['weather_code'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'min_c': minimumTemperatureC,
        'max_c': maximumTemperatureC,
        'rain_mm': precipitationMm,
        'rain_probability': precipitationProbability,
        'weather_code': weatherCode,
      };

  String get conditionLabel => weatherDescription(weatherCode);

  String get dayName {
    const names = [
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    return names[date.weekday - 1];
  }

  static List<dynamic> _listAt(Map<String, dynamic> map, String key) {
    final value = map[key];
    return value is List ? value : const [];
  }

  static double? _doubleAt(Map<String, dynamic> map, String key, int index) {
    final values = _listAt(map, key);
    if (index >= values.length) return null;
    final value = values[index];
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }

  static int? _intAt(Map<String, dynamic> map, String key, int index) {
    final value = _doubleAt(map, key, index);
    return value?.round();
  }
}

class WeatherAlert {
  const WeatherAlert({
    required this.kind,
    required this.title,
    required this.message,
  });

  final WeatherAlertKind kind;
  final String title;
  final String message;
}

enum WeatherAlertKind { rain, heat, cold }

class WeatherSnapshot {
  const WeatherSnapshot({
    required this.currentTemperatureC,
    required this.currentHumidityPercent,
    required this.currentWeatherCode,
    required this.days,
  });

  final double currentTemperatureC;
  final int currentHumidityPercent;
  final int currentWeatherCode;
  final List<WeatherForecastDay> days;

  factory WeatherSnapshot.fromApiJson(Map<String, dynamic> json) {
    final current = json['current'];
    final daily = json['daily'];
    if (current is! Map<String, dynamic> || daily is! Map<String, dynamic>) {
      throw const FormatException('Weather response is missing current or daily data');
    }

    final timeValues = daily['time'];
    if (timeValues is! List || timeValues.isEmpty) {
      throw const FormatException('Weather response contains no daily forecast');
    }

    final days = List<WeatherForecastDay>.generate(
      timeValues.length,
      (index) => WeatherForecastDay.fromApi(daily, index),
      growable: false,
    );

    final temperature = current['temperature_2m'];
    final humidity = current['relative_humidity_2m'];
    final weatherCode = current['weather_code'];
    if (temperature is! num || humidity is! num || weatherCode is! num) {
      throw const FormatException('Weather response contains invalid current conditions');
    }

    return WeatherSnapshot(
      currentTemperatureC: temperature.toDouble(),
      currentHumidityPercent: humidity.round(),
      currentWeatherCode: weatherCode.round(),
      days: days,
    );
  }

  factory WeatherSnapshot.fromJson(Map<String, dynamic> json) {
    final rawDays = json['days'];
    if (rawDays is! List || rawDays.isEmpty) {
      throw const FormatException('Cached forecast contains no days');
    }
    return WeatherSnapshot(
      currentTemperatureC: (json['current_temp_c'] as num).toDouble(),
      currentHumidityPercent: (json['current_humidity'] as num).toInt(),
      currentWeatherCode: (json['current_weather_code'] as num).toInt(),
      days: rawDays
          .whereType<Map>()
          .map((day) => WeatherForecastDay.fromJson(
                Map<String, dynamic>.from(day),
              ))
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => {
        'current_temp_c': currentTemperatureC,
        'current_humidity': currentHumidityPercent,
        'current_weather_code': currentWeatherCode,
        'days': days.map((day) => day.toJson()).toList(growable: false),
      };

  String get currentCondition => weatherDescription(currentWeatherCode);

  List<WeatherAlert> get alerts => buildWeatherAlerts(days);
}

List<WeatherAlert> buildWeatherAlerts(List<WeatherForecastDay> days) {
  final nearTerm = days.take(3).toList(growable: false);
  final alerts = <WeatherAlert>[];

  WeatherForecastDay? rainDay;
  for (final day in nearTerm) {
    final probability = day.precipitationProbability ?? 0;
    if (probability >= 60 || day.precipitationMm >= 5) {
      if (rainDay == null ||
          probability > (rainDay.precipitationProbability ?? 0) ||
          day.precipitationMm > rainDay.precipitationMm) {
        rainDay = day;
      }
    }
  }
  if (rainDay != null) {
    final chance = rainDay.precipitationProbability;
    final chanceText = chance == null ? '' : ' (احتمال ${chance}٪)';
    alerts.add(WeatherAlert(
      kind: WeatherAlertKind.rain,
      title: 'أمطار متوقعة ${_arabicDateLabel(rainDay.date)}',
      message:
          'كمية متوقعة ${rainDay.precipitationMm.toStringAsFixed(1)} مم$chanceText. راجع مواعيد الري والرش.',
    ));
  }

  WeatherForecastDay? hotDay;
  for (final day in nearTerm) {
    if (day.maximumTemperatureC >= 38 &&
        (hotDay == null || day.maximumTemperatureC > hotDay.maximumTemperatureC)) {
      hotDay = day;
    }
  }
  if (hotDay != null) {
    alerts.add(WeatherAlert(
      kind: WeatherAlertKind.heat,
      title: 'حرارة مرتفعة ${_arabicDateLabel(hotDay.date)}',
      message:
          'العظمى المتوقعة ${hotDay.maximumTemperatureC.toStringAsFixed(0)}°م. يُفضّل تجنّب الرش وقت الظهيرة.',
    ));
  }

  WeatherForecastDay? coldDay;
  for (final day in nearTerm) {
    if (day.minimumTemperatureC <= 5 &&
        (coldDay == null || day.minimumTemperatureC < coldDay.minimumTemperatureC)) {
      coldDay = day;
    }
  }
  if (coldDay != null) {
    alerts.add(WeatherAlert(
      kind: WeatherAlertKind.cold,
      title: 'برودة شديدة ${_arabicDateLabel(coldDay.date)}',
      message:
          'الصغرى المتوقعة ${coldDay.minimumTemperatureC.toStringAsFixed(0)}°م. راقب المحاصيل الحساسة للبرد.',
    ));
  }

  return alerts;
}

String _arabicDateLabel(DateTime date) {
  final today = DateTime.now();
  if (date.year == today.year && date.month == today.month && date.day == today.day) {
    return 'اليوم';
  }
  final tomorrow = today.add(const Duration(days: 1));
  if (date.year == tomorrow.year &&
      date.month == tomorrow.month &&
      date.day == tomorrow.day) {
    return 'غدًا';
  }
  const names = [
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];
  return names[date.weekday - 1];
}

String weatherDescription(int code) {
  if (code == 0) return 'صحو';
  if (code <= 3) return 'غائم جزئيًا';
  if (code == 45 || code == 48) return 'شبورة أو ضباب';
  if (code >= 51 && code <= 57) return 'رذاذ';
  if (code >= 61 && code <= 67) return 'أمطار';
  if (code >= 71 && code <= 77) return 'ثلوج';
  if (code >= 80 && code <= 82) return 'زخات مطر';
  if (code == 85 || code == 86) return 'زخات ثلج';
  if (code >= 95) return 'عواصف رعدية';
  return 'حالة جوية متغيرة';
}
