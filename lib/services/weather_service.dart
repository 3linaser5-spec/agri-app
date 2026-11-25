import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/weather_forecast.dart';

class WeatherService {
  const WeatherService._();

  static Future<WeatherSnapshot> fetch({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.https(
      'api.open-meteo.com',
      '/v1/forecast',
      {
        'latitude': latitude.toStringAsFixed(5),
        'longitude': longitude.toStringAsFixed(5),
        'current': 'temperature_2m,relative_humidity_2m,weather_code',
        'hourly': 'relative_humidity_2m',
        'daily':
            'weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,precipitation_sum,et0_fao_evapotranspiration',
        'forecast_days': '7',
        'timezone': 'auto',
      },
    );

    final response = await Dio()
        .getUri<String>(
          uri,
          options: Options(
            headers: const {'Accept': 'application/json'},
            responseType: ResponseType.plain,
            validateStatus: (_) => true,
          ),
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw WeatherServiceException(
        'تعذر جلب توقعات الطقس (HTTP ${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.data ?? '');
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('استجابة الطقس ليست JSON صالحًا');
    }
    return WeatherSnapshot.fromApiJson(decoded);
  }
}

class WeatherServiceException implements Exception {
  const WeatherServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
