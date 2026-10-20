import 'package:agri_app/utils/irrigation_calc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('area and water need', () {
    test('unit conversion', () {
      expect(IrrigationCalc.areaToM2(2, AreaUnit.feddan), 8400);
    });

    test('etc = eto x kc', () {
      expect(IrrigationCalc.etc(5, 0.8), closeTo(4, 1e-9));
    });
  });

  group('pipes', () {
    test('velocity', () {
      expect(IrrigationCalc.velocity(36, 100), closeTo(1.273, 0.01));
    });
  });

  group('drip', () {
    test('plants', () {
      final r = IrrigationCalc.drip(
        areaM2: 4200,
        rowSpacingM: 1,
        plantSpacingM: 0.5,
        emittersPerPlant: 1,
        emitterLph: 4,
        etcMmDay: 5,
        efficiency: 0.9,
        intervalDays: 1,
        availableHours: 12,
        sectors: 1,
        lateralLengthM: 50,
        lateralDiameterMm: 16,
        operatingHeadM: 10,
      )!;
      expect(r.plants, closeTo(8400, 1e-6));
    });
  });
}
