import 'package:agri_app/utils/irrigation_calc.dart';
import 'package:agri_app/utils/dxf_export.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IrrigationCalc', () {
    test('areaToM2', () {
      expect(IrrigationCalc.areaToM2(1, AreaUnit.feddan), 4200);
      expect(IrrigationCalc.areaToM2(1, AreaUnit.hectare), 10000);
      expect(IrrigationCalc.areaToM2(500, AreaUnit.squareMeter), 500);
    });

    test('etc', () {
      expect(IrrigationCalc.etc(5, 0.8), 4);
      expect(IrrigationCalc.etc(0, 0.8), isNull);
    });

    test('velocity', () {
      expect(IrrigationCalc.velocity(36, 100), closeTo(1.273, 0.01));
    });

    test('drip', () {
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
      );
      expect(r, isNotNull);
      expect(r!.plants, 8400);
    });

    test('DXF export', () {
      final dxf = IrrigationDxf.drip(
        widthM: 20,
        lengthM: 30,
        rowSpacingM: 1,
        plantSpacingM: 1,
        emittersPerPlant: 1,
      );
      expect(dxf, contains('ENTITIES'));
      expect(dxf.trimRight().endsWith('EOF'), isTrue);
    });
  });
}
