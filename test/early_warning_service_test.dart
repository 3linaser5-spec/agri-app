import 'package:flutter_test/flutter_test.dart';
import 'package:agri_app/models/my_farm_model.dart';
import 'package:agri_app/models/weather_forecast.dart';
import 'package:agri_app/services/early_warning_service.dart';

void main() {
  group('EarlyWarningService', () {
    test('creates a scouting warning for active crops during humid wet weather', () {
      final warnings = EarlyWarningService.evaluate(
        forecast: [
          _day(humidity: 94, rain: 5, probability: 75),
        ],
        programs: [_program()],
      );

      expect(warnings, hasLength(1));
      expect(warnings.single.level, CropWeatherRiskLevel.elevated);
      expect(warnings.single.crops, contains('قمح'));
      expect(warnings.single.message, contains('ليس تشخيصًا'));
    });

    test('does not create a risk warning without overlapping humidity and rain', () {
      final warnings = EarlyWarningService.evaluate(
        forecast: [
          _day(humidity: 95, rain: 0, probability: 10),
        ],
        programs: [_program()],
      );

      expect(warnings, isEmpty);
    });

    test('does not monitor completed farm programs', () {
      final warnings = EarlyWarningService.evaluate(
        forecast: [
          _day(humidity: 95, rain: 5, probability: 80),
        ],
        programs: [_program(status: 'completed')],
      );

      expect(warnings, isEmpty);
    });
  });
}

WeatherForecastDay _day({
  required double humidity,
  required double rain,
  required int probability,
}) {
  return WeatherForecastDay(
    date: DateTime.now(),
    minimumTemperatureC: 15,
    maximumTemperatureC: 28,
    precipitationMm: rain,
    weatherCode: 61,
    precipitationProbability: probability,
    meanRelativeHumidityPercent: humidity,
  );
}

MyFarmProgram _program({String status = 'active'}) {
  return MyFarmProgram(
    id: 'program-1',
    userId: 'user-1',
    templateId: 'wheat-template',
    templateName: 'قمح',
    templateEmoji: '🌾',
    sectionId: 'field-1',
    sectionName: 'الحقل الشمالي',
    governorate: 'الجيزة',
    climateZone: 'دلتا النيل',
    inputValues: const {},
    tasks: const [],
    materials: const [],
    financial: const {},
    startDate: DateTime(2026, 1, 1),
    createdAt: DateTime(2026, 1, 1),
    status: status,
  );
}
