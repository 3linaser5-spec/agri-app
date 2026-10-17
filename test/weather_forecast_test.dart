import 'package:flutter_test/flutter_test.dart';
import 'package:agri_app/models/weather_forecast.dart';

void main() {
  group('WeatherSnapshot.fromApiJson', () {
    test('parses current conditions and a seven-day forecast', () {
      final snapshot = WeatherSnapshot.fromApiJson(_sampleApiResponse());

      expect(snapshot.currentTemperatureC, 31.5);
      expect(snapshot.currentHumidityPercent, 48);
      expect(snapshot.currentCondition, 'صحو');
      expect(snapshot.days, hasLength(7));
      expect(snapshot.days.first.maximumTemperatureC, 39);
      expect(snapshot.days.first.minimumTemperatureC, 22);
      expect(snapshot.days.first.precipitationProbability, 68);
      expect(snapshot.days.first.precipitationMm, 7.2);
    });

    test('round-trips a cached forecast', () {
      final original = WeatherSnapshot.fromApiJson(_sampleApiResponse());
      final restored = WeatherSnapshot.fromJson(original.toJson());

      expect(restored.currentTemperatureC, original.currentTemperatureC);
      expect(restored.currentHumidityPercent, original.currentHumidityPercent);
      expect(restored.days, hasLength(original.days.length));
      expect(restored.days.first.date, original.days.first.date);
      expect(restored.days.first.precipitationProbability, 68);
    });

    test('rejects a response missing daily forecasts', () {
      expect(
        () => WeatherSnapshot.fromApiJson({
          'current': {
            'temperature_2m': 25,
            'relative_humidity_2m': 50,
            'weather_code': 1,
          },
          'daily': {'time': []},
        }),
        throwsFormatException,
      );
    });
  });

  group('buildWeatherAlerts', () {
    test('creates rain and heat alerts within the next three days', () {
      final snapshot = WeatherSnapshot.fromApiJson(_sampleApiResponse());

      expect(snapshot.alerts.map((alert) => alert.kind), contains(WeatherAlertKind.rain));
      expect(snapshot.alerts.map((alert) => alert.kind), contains(WeatherAlertKind.heat));
      expect(snapshot.alerts.first.message, contains('68٪'));
    });

    test('returns no alerts for mild dry conditions', () {
      final snapshot = WeatherSnapshot.fromApiJson(_sampleApiResponse(mild: true));

      expect(snapshot.alerts, isEmpty);
    });
  });
}

Map<String, dynamic> _sampleApiResponse({bool mild = false}) {
  final today = DateTime.now();
  final dates = List<String>.generate(
    7,
    (index) => DateTime(today.year, today.month, today.day + index)
        .toIso8601String()
        .substring(0, 10),
  );
  return {
    'current': {
      'temperature_2m': 31.5,
      'relative_humidity_2m': 48,
      'weather_code': 0,
    },
    'daily': {
      'time': dates,
      'temperature_2m_max': mild ? List<double>.filled(7, 27) : [39, 36, 34, 33, 32, 31, 30],
      'temperature_2m_min': mild ? List<double>.filled(7, 18) : [22, 20, 19, 18, 18, 17, 17],
      'precipitation_probability_max': mild ? List<int>.filled(7, 10) : [68, 20, 15, 10, 10, 5, 5],
      'precipitation_sum': mild ? List<double>.filled(7, 0) : [7.2, 0, 0, 0, 0, 0, 0],
      'weather_code': List<int>.filled(7, 0),
    },
  };
}
