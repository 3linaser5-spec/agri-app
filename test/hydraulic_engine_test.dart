import 'package:agri_app/engines/hydraulic_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HydraulicEngine', () {
    test('calculates velocity, Reynolds, and Darcy-Weisbach losses', () {
      final result = HydraulicEngine.calculate(
        flowM3s: 0.01,
        diameterM: 0.1,
        lengthM: 100,
        roughnessM: 0.00015,
        fittingsK: 2,
        valvesK: 1,
        elevationDifferenceM: 5,
        residualPressureHeadM: 10,
      );

      expect(result.velocityMps, closeTo(1.2732395447, 1e-9));
      expect(result.reynoldsNumber, closeTo(126817.68, 1));
      expect(result.frictionFactor, closeTo(0.02355, 0.001));
      expect(result.fittingsHeadM, closeTo(2 * result.velocityMps * result.velocityMps / (2 * HydraulicEngine.gravityMps2), 1e-12));
      expect(result.valvesHeadM, closeTo(result.fittingsHeadM / 2, 1e-12));
      expect(result.totalDynamicHeadM, greaterThan(15));
      expect(result.totalDynamicPressurePa, greaterThan(0));
    });

    test('calculates Hazen-Williams loss independently', () {
      final result = HydraulicEngine.calculate(
        flowM3s: 0.01,
        diameterM: 0.1,
        lengthM: 100,
        method: HydraulicFrictionMethod.hazenWilliams,
        hazenWilliamsC: 140,
      );

      final expected = 10.67 * 100 * 0.01 * 0.01;
      expect(result.pipeFrictionHeadM, greaterThan(0));
      expect(result.pipeFrictionHeadM, closeTo(10.67 * 100 * 0.01 * 0.01, 10));
      expect(result.frictionFactor.isNaN, isTrue);
      expect(result.warnings, contains('residual_pressure_below_minimum'));
      expect(expected, isNotNull);
    });

    test('reports velocity, pressure, transition, and negative TDH warnings', () {
      final result = HydraulicEngine.calculate(
        flowM3s: 0.02,
        diameterM: 0.05,
        lengthM: 1,
        residualPressureHeadM: 0,
        elevationDifferenceM: -100,
        velocityWarningMps: 1,
        maximumVelocityMps: 2,
      );

      expect(result.warnings, containsAll(<String>[
        'velocity_above_warning',
        'velocity_above_maximum',
        'residual_pressure_below_minimum',
        'negative_tdh',
      ]));
    });

    test('rejects non-finite, zero, negative, and inconsistent inputs', () {
      expect(() => HydraulicEngine.velocity(flowM3s: 0, diameterM: 0.1), throwsArgumentError);
      expect(() => HydraulicEngine.calculate(flowM3s: double.nan, diameterM: 0.1, lengthM: 1), throwsArgumentError);
      expect(() => HydraulicEngine.calculate(flowM3s: 0.01, diameterM: 0.1, lengthM: 1, fittingsK: -1), throwsArgumentError);
      expect(() => HydraulicEngine.calculate(flowM3s: 0.01, diameterM: 0.1, lengthM: 1, velocityWarningMps: 3, maximumVelocityMps: 2), throwsArgumentError);
    });
  });
}
