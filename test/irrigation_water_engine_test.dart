import 'package:agri_app/engines/irrigation_water_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IrrigationWaterEngine', () {
    test('calculates ETc, stress factors, efficiency, and weekly volume', () {
      final result = IrrigationWaterEngine.calculate(
        etoMmDay: 5,
        kc: 0.8,
        salinityFactor: 0.9,
        droughtFactor: 0.95,
        efficiency: 0.8,
        areaM2: 100,
        flowRateLpm: 10,
        deviceCount: 2,
      );

      expect(result.etcMmDay, closeTo(4, 1e-10));
      expect(result.adjustedEtcMmDay, closeTo(3.42, 1e-10));
      expect(result.netDailyMm, closeTo(3.42, 1e-10));
      expect(result.grossDailyMm, closeTo(4.275, 1e-10));
      expect(result.grossWeeklyMm, closeTo(29.925, 1e-10));
      expect(result.dailyVolumeM3, closeTo(0.4275, 1e-10));
      expect(result.weeklyVolumeM3, closeTo(2.9925, 1e-10));
    });

    test('converts volume to runtime using flow and device count', () {
      final result = IrrigationWaterEngine.calculate(
        etoMmDay: 4,
        kc: 1,
        areaM2: 100,
        efficiency: 1,
        flowRateLpm: 5,
        deviceCount: 2,
      );

      // 400 L/day / (5 L/min * 2 devices) = 40 minutes.
      expect(result.dailyVolumeLitres, 400);
      expect(result.dailyRuntimeMinutes, 40);
      expect(result.weeklyRuntimeMinutes, 280);
    });

    test('rejects invalid values', () {
      expect(
        () => IrrigationWaterEngine.calculateEtc(etoMmDay: 5, kc: 3),
        throwsArgumentError,
      );
      expect(
        () => IrrigationWaterEngine.calculate(
          etoMmDay: 5,
          kc: 0.8,
          areaM2: 100,
          efficiency: 0,
          flowRateLpm: 10,
        ),
        throwsArgumentError,
      );
      expect(
        () => IrrigationWaterEngine.calculate(
          etoMmDay: 5,
          kc: 0.8,
          areaM2: 100,
          efficiency: 0.8,
          flowRateLpm: 10,
          deviceCount: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => IrrigationWaterEngine.calculate(
          etoMmDay: double.nan,
          kc: 0.8,
          areaM2: 100,
          efficiency: 0.8,
          flowRateLpm: 10,
        ),
        throwsArgumentError,
      );
    });
  });
}
