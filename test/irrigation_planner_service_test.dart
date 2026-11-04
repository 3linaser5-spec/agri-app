import 'package:agri_app/models/weather_forecast.dart';
import 'package:agri_app/services/irrigation_planner_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IrrigationPlannerService', () {
    test('estimates gross water after effective rain and irrigation efficiency', () {
      final estimates = IrrigationPlannerService.estimateWeek(
        forecast: [
          _day(DateTime(2026, 11, 4), et0: 5, rain: 2),
        ],
        areaM2: 4200,
        kc: 0.8,
        efficiencyPercent: 90,
      );

      expect(estimates, hasLength(1));
      expect(estimates.single.cropEtMm, 4);
      expect(estimates.single.effectiveRainMm, 1.4);
      expect(estimates.single.netNeedMm, closeTo(2.6, 1e-9));
      expect(estimates.single.grossNeedMm, closeTo(2.8888889, 1e-6));
      expect(estimates.single.volumeM3, closeTo(12.133333, 1e-5));
    });

    test('does not produce negative irrigation need after heavy rain', () {
      final estimates = IrrigationPlannerService.estimateWeek(
        forecast: [_day(DateTime(2026, 11, 4), et0: 3, rain: 20)],
        areaM2: 4200,
        kc: 0.5,
        efficiencyPercent: 75,
      );

      expect(estimates.single.netNeedMm, 0);
      expect(estimates.single.volumeM3, 0);
    });

    test('skips days without ET0 and uses no more than seven forecast days', () {
      final days = List<WeatherForecastDay>.generate(
        9,
        (index) => _day(
          DateTime(2026, 11, 4 + index),
          et0: index == 2 ? null : 4,
          rain: 0,
        ),
      );
      final estimates = IrrigationPlannerService.estimateWeek(
        forecast: days,
        areaM2: 4200,
        kc: 1,
        efficiencyPercent: 90,
      );

      expect(estimates, hasLength(6));
      expect(estimates.last.date, DateTime(2026, 11, 10));
    });

    test('guesses common crop names in Arabic', () {
      expect(IrrigationCropProfile.guess('برنامج قمح'), isNotNull);
      expect(IrrigationCropProfile.guess('محصول طماطم'),
          IrrigationCropProfile.profiles.firstWhere((item) => item.id == 'tomato'));
      expect(IrrigationCropProfile.guess('برنامج غير معروف'), isNull);
    });
  });
}

WeatherForecastDay _day(DateTime date, {required double? et0, required double rain}) =>
    WeatherForecastDay(
      date: date,
      minimumTemperatureC: 20,
      maximumTemperatureC: 30,
      precipitationMm: rain,
      weatherCode: 0,
      et0Mm: et0,
    );
