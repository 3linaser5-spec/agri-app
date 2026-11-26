import 'package:flutter_test/flutter_test.dart';

import 'package:agri_app/models/weather_forecast.dart';
import 'package:agri_app/services/smart_weather_advice.dart';

WeatherForecastDay day({
  double min = 18,
  double max = 30,
  double rain = 0,
  int? rainProbability,
  double? humidity,
  double? et0,
  int offset = 1,
}) =>
    WeatherForecastDay(
      date: DateTime(2026, 11, 26).add(Duration(days: offset)),
      minimumTemperatureC: min,
      maximumTemperatureC: max,
      precipitationMm: rain,
      weatherCode: rain > 0 ? 61 : 0,
      precipitationProbability: rainProbability,
      meanRelativeHumidityPercent: humidity,
      et0Mm: et0,
    );

WeatherSnapshot snapshot(List<WeatherForecastDay> days) => WeatherSnapshot(
      currentTemperatureC: 28,
      currentHumidityPercent: 60,
      currentWeatherCode: 0,
      days: days,
    );

void main() {
  test('recommends delaying irrigation when rain is expected', () {
    final advice = SmartWeatherAdvisor.build(snapshot([
      day(rain: 12, rainProbability: 80),
      day(offset: 2, rain: 2),
    ]));
    expect(advice.first.kind, FarmAdviceKind.irrigation);
    expect(advice.first.severity, 3);
    expect(advice.first.waterSavingMm, closeTo(12, 1e-9));
    expect(advice.first.message, contains('أوقف'));
  });

  test('treats a high rain probability as rain even with small amounts', () {
    final advice = SmartWeatherAdvisor.irrigationDecision(snapshot([
      day(rain: 0.4, rainProbability: 75),
    ]));
    expect(advice, isNotNull);
    expect(advice!.severity, 3);
  });

  test('falls back to the reference evapotranspiration advice', () {
    final advice = SmartWeatherAdvisor.irrigationDecision(snapshot([
      day(et0: 4),
      day(offset: 2, et0: 5),
      day(offset: 3, et0: 3),
    ]));
    expect(advice, isNotNull);
    expect(advice!.severity, 1);
    expect(advice.message, contains('12.0'));
  });

  test('warns about heat and suggests an earlier irrigation', () {
    final advice = SmartWeatherAdvisor.build(snapshot([day(max: 41)]));
    final heat = advice.firstWhere((item) => item.kind == FarmAdviceKind.heat);
    expect(heat.severity, 2);
    expect(heat.title, contains('موجة حرارة'));
    expect(heat.message, contains('10-15'));
  });

  test('warns about frost when the minimum drops below five degrees', () {
    final advice = SmartWeatherAdvisor.build(
      snapshot([day(min: 3, max: 18)]),
      cropName: 'طماطم',
    );
    final cold = advice.firstWhere((item) => item.kind == FarmAdviceKind.cold);
    expect(cold.title, contains('طماطم'));
  });

  test('flags fungal risk for humid mild weather', () {
    final advice = SmartWeatherAdvisor.build(snapshot([
      day(humidity: 92, min: 16, max: 26),
    ]));
    expect(
      advice.any((item) => item.kind == FarmAdviceKind.fungal),
      isTrue,
    );
  });

  test('suggests a spray window when the weather is calm', () {
    final advice = SmartWeatherAdvisor.build(snapshot([
      day(min: 18, max: 28, humidity: 60),
    ]));
    expect(
      advice.any((item) => item.kind == FarmAdviceKind.spray),
      isTrue,
    );
  });

  test('no spray suggestion while rain is coming', () {
    final advice = SmartWeatherAdvisor.build(snapshot([
      day(rain: 8, rainProbability: 90),
      day(offset: 2, max: 41),
    ]));
    expect(advice.any((item) => item.kind == FarmAdviceKind.spray), isFalse);
    expect(advice.first.severity, 3);
  });

  test('advice is sorted by severity and the notification uses the top item', () {
    final advice = SmartWeatherAdvisor.build(snapshot([
      day(max: 40, min: 3, humidity: 90),
      day(offset: 2, rain: 20, rainProbability: 95),
    ]));
    for (var i = 1; i < advice.length; i++) {
      expect(advice[i - 1].severity, greaterThanOrEqualTo(advice[i].severity));
    }
    expect(
      SmartWeatherAdvisor.notificationBody(advice),
      startsWith(advice.first.title),
    );
  });

  test('an empty forecast produces no advice', () {
    expect(SmartWeatherAdvisor.build(snapshot(const [])), isEmpty);
    expect(SmartWeatherAdvisor.irrigationDecision(snapshot(const [])), isNull);
    expect(
      SmartWeatherAdvisor.notificationBody(const []),
      'لا توجد توصيات طارئة اليوم.',
    );
  });
}
