import 'package:agri_app/utils/dxf_export.dart';
import 'package:agri_app/utils/irrigation_calc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('area and water need', () {
    test('unit conversion', () {
      expect(IrrigationCalc.areaToM2(2, AreaUnit.feddan), 8400);
      expect(IrrigationCalc.areaToM2(1, AreaUnit.hectare), 10000);
      expect(IrrigationCalc.areaToM2(50, AreaUnit.squareMeter), 50);
    });

    test('etc = eto x kc', () {
      expect(IrrigationCalc.etc(5, 0.8), closeTo(4, 1e-9));
      expect(IrrigationCalc.etc(0, 0.8), isNull);
    });

    test('gross depth and volumes', () {
      final n = IrrigationCalc.waterNeed(
        areaM2: 4200,
        etcMmDay: 5,
        efficiency: 0.9,
        intervalDays: 2,
      )!;
      expect(n.grossDailyMm, closeTo(5 / 0.9, 1e-9));
      expect(n.grossPerIrrigationMm, closeTo(10 / 0.9, 1e-9));
      expect(n.dailyVolumeM3, closeTo(5 / 0.9 * 4.2, 1e-9));
      expect(n.perIrrigationVolumeM3, closeTo(10 / 0.9 * 4.2, 1e-9));
    });

    test('invalid input returns null', () {
      expect(
          IrrigationCalc.waterNeed(
              areaM2: 0, etcMmDay: 5, efficiency: 0.9, intervalDays: 1),
          isNull);
      expect(
          IrrigationCalc.waterNeed(
              areaM2: -10, etcMmDay: 5, efficiency: 0.9, intervalDays: 1),
          isNull);
      expect(
          IrrigationCalc.waterNeed(
              areaM2: 100, etcMmDay: 5, efficiency: 1.5, intervalDays: 1),
          isNull);
      expect(
          IrrigationCalc.waterNeed(
              areaM2: 100, etcMmDay: 5, efficiency: 0.9, intervalDays: 0.5),
          isNull);
    });
  });

  group('pipes', () {
    test('velocity: 36 m3/h in 100 mm is about 1.27 m/s', () {
      expect(IrrigationCalc.velocity(36, 100), closeTo(1.273, 0.01));
    });

    test('hazen-williams matches the hand calculation', () {
      // Q = 10 m3/h, D = 50 mm, L = 100 m, C = 140
      // hf = 10.67 * 100 * (0.0027778^1.852) / (140^1.852 * 0.05^4.87)
      final hf = IrrigationCalc.hazenWilliamsLoss(
          flowM3h: 10, diameterMm: 50, lengthM: 100, c: 140);
      expect(hf, closeTo(4.5, 0.3));
    });

    test('loss grows with flow and falls with diameter', () {
      double loss(double q, double d) => IrrigationCalc.hazenWilliamsLoss(
          flowM3h: q, diameterMm: d, lengthM: 100);
      expect(loss(20, 63), greaterThan(loss(10, 63)));
      expect(loss(10, 50), greaterThan(loss(10, 63)));
    });

    test('christiansen factor', () {
      expect(IrrigationCalc.christiansenF(1), 1);
      final f = IrrigationCalc.christiansenF(100);
      expect(f, greaterThan(0.34));
      expect(f, lessThan(0.40));
    });

    test('pickDiameter respects the velocity limit', () {
      final c = IrrigationCalc.pickDiameter(flowM3h: 36, lengthM: 100);
      expect(c.ok, isTrue);
      expect(c.velocityMs, lessThanOrEqualTo(1.5));
      // القطر الأصغر منه لازم يكسر الحد
      final idx = IrrigationCalc.standardDiametersMm.indexOf(c.diameterMm);
      if (idx > 0) {
        final smaller = IrrigationCalc.standardDiametersMm[idx - 1];
        expect(IrrigationCalc.velocity(36, smaller), greaterThan(1.5));
      }
    });

    test('pickDiameter flags an impossible flow', () {
      final c = IrrigationCalc.pickDiameter(flowM3h: 100000, lengthM: 100);
      expect(c.ok, isFalse);
      expect(c.diameterMm, IrrigationCalc.standardDiametersMm.last);
    });
  });

  group('drip', () {
    DripResult? run({int sectors = 1, double hours = 12}) =>
        IrrigationCalc.drip(
          areaM2: 4200,
          rowSpacingM: 1,
          plantSpacingM: 0.5,
          emittersPerPlant: 1,
          emitterLph: 4,
          etcMmDay: 5,
          efficiency: 0.9,
          intervalDays: 1,
          availableHours: hours,
          sectors: sectors,
          lateralLengthM: 50,
          lateralDiameterMm: 16,
          operatingHeadM: 10,
        );

    test('plants, emitters and flow', () {
      final r = run()!;
      expect(r.plants, closeTo(8400, 1e-6));
      expect(r.totalEmitters, closeTo(8400, 1e-6));
      expect(r.totalFlowM3h, closeTo(8400 * 4 / 1000, 1e-9));
      expect(r.litersPerPlantPerIrrigation, closeTo(5 / 0.9 * 0.5, 1e-9));
      expect(r.runtimeHoursPerSector, closeTo(5 / 0.9 * 0.5 / 4, 1e-9));
      expect(r.lateralTotalLengthM, closeTo(4200, 1e-9));
    });

    test('sectors divide the flow and are checked against the hours', () {
      final r = run(sectors: 4)!;
      expect(r.sectorFlowM3h, closeTo(8400 * 4 / 1000 / 4, 1e-9));
      expect(r.sectorsOk, isTrue);
      expect(r.maxSectors, greaterThanOrEqualTo(4));
      final tight = run(sectors: 20, hours: 1)!;
      expect(tight.sectorsOk, isFalse);
    });

    test('lateral loss and end flow are consistent', () {
      final r = run()!;
      expect(r.lateralLossM, greaterThan(0));
      expect(r.endEmitterFlowPct, lessThanOrEqualTo(100));
      expect(r.lateralOk, r.lateralLossM <= r.allowedLateralLossM);
    });

    test('invalid input returns null', () {
      expect(
          IrrigationCalc.drip(
            areaM2: 4200,
            rowSpacingM: 0,
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
          ),
          isNull);
    });
  });

  group('sprinkler', () {
    test('application rate, count and runtime', () {
      final r = IrrigationCalc.sprinkler(
        areaM2: 10000,
        sprinklerM3h: 1.2,
        spacingAlongM: 12,
        spacingAcrossM: 12,
        etcMmDay: 6,
        efficiency: 0.75,
        intervalDays: 3,
        availableHours: 12,
        sectors: 2,
        infiltrationMmH: 15,
      )!;
      expect(r.applicationRateMmH, closeTo(1200 / 144, 1e-9));
      expect(r.sprinklers, (10000 / 144).ceil());
      expect(r.runtimeHoursPerSector,
          closeTo(6 / 0.75 * 3 / (1200 / 144), 1e-9));
      expect(r.totalFlowM3h, closeTo(r.sprinklers * 1.2, 1e-9));
      expect(r.sectorFlowM3h, closeTo(r.totalFlowM3h / 2, 1e-9));
      expect(r.infiltrationOk, isTrue);
    });

    test('rate above infiltration is flagged', () {
      final r = IrrigationCalc.sprinkler(
        areaM2: 10000,
        sprinklerM3h: 1.2,
        spacingAlongM: 12,
        spacingAcrossM: 12,
        etcMmDay: 6,
        efficiency: 0.75,
        intervalDays: 3,
        availableHours: 12,
        sectors: 2,
        infiltrationMmH: 5,
      )!;
      expect(r.infiltrationOk, isFalse);
    });
  });

  group('surface and pivot', () {
    test('surface irrigation time', () {
      final r = IrrigationCalc.surface(
        areaM2: 4200,
        etcMmDay: 5,
        efficiency: 0.6,
        intervalDays: 7,
        streamLps: 20,
        availableHours: 24,
      )!;
      final volume = 5 / 0.6 * 7 * 4.2;
      expect(r.irrigationHours, closeTo(volume / (20 * 3.6), 1e-9));
      expect(r.ok, r.irrigationHours <= 24);
    });

    test('pivot area, flow and speed', () {
      final r = IrrigationCalc.pivot(
        radiusM: 400,
        etcMmDay: 6,
        efficiency: 0.85,
        intervalDays: 2,
        hoursPerRotation: 40,
      )!;
      expect(r.areaM2, closeTo(3.14159265 * 400 * 400, 1));
      expect(r.flowLps, closeTo(r.flowM3h / 3.6, 1e-9));
      expect(r.endTowerSpeedMh, closeTo(2 * 3.14159265 * 400 / 40, 1e-3));
      expect(r.fitsInterval, isTrue);
      final slow = IrrigationCalc.pivot(
        radiusM: 400,
        etcMmDay: 6,
        efficiency: 0.85,
        intervalDays: 1,
        hoursPerRotation: 40,
      )!;
      expect(slow.fitsInterval, isFalse);
    });
  });

  group('pump', () {
    test('head and power', () {
      final p = IrrigationCalc.pump(
        flowM3h: 36.72,
        staticLiftM: 20,
        operatingHeadM: 30,
        frictionLossM: 10,
        minorLossPct: 10,
        equipmentLossM: 5,
        pumpEfficiency: 0.65,
        motorEfficiency: 0.9,
      )!;
      expect(p.totalHeadM, closeTo(20 + 30 + 11 + 5, 1e-9));
      expect(p.hydraulicKw, closeTo(36.72 * 66 / 367.2, 1e-9));
      expect(p.shaftKw, closeTo(p.hydraulicKw / 0.65, 1e-9));
      expect(p.motorInputKw, closeTo(p.shaftKw / 0.9, 1e-9));
      expect(p.recommendedMotorKw, closeTo(p.shaftKw * 1.15, 1e-9));
    });

    test('invalid efficiency returns null', () {
      expect(
          IrrigationCalc.pump(
            flowM3h: 10,
            staticLiftM: 0,
            operatingHeadM: 10,
            frictionLossM: 0,
            minorLossPct: 0,
            equipmentLossM: 0,
            pumpEfficiency: 1.2,
            motorEfficiency: 0.9,
          ),
          isNull);
    });
  });

  group('DXF export', () {
    test('number formatting never uses scientific notation', () {
      expect(DxfBuilder.fmt(1e-7), '0');
      expect(DxfBuilder.fmt(12.5), '12.5');
      expect(DxfBuilder.fmt(3), '3');
      expect(DxfBuilder.fmt(double.nan), '0');
    });

    test('file has the standard sections and ends with EOF', () {
      final dxf = IrrigationDxf.drip(
        widthM: 20,
        lengthM: 30,
        rowSpacingM: 1,
        plantSpacingM: 1,
        emittersPerPlant: 1,
      );
      expect(dxf, contains('ENTITIES'));
      expect(dxf, contains('TABLES'));
      expect(dxf.trimRight().endsWith('EOF'), isTrue);
      expect('LATERAL'.allMatches(dxf).length, greaterThanOrEqualTo(20));
    });

    test('layer colors are written as numeric DXF values', () {
      final dxf = (DxfBuilder()..line('TEST', 5, 0, 0, 1, 1)).build();
      expect(dxf, contains('62\n5\n'));
      expect(dxf, isNot(contains('62\n\$color\n')));
    });

    test('non-ASCII text is stripped', () {
      final b = DxfBuilder()..text('NOTES', 7, 0, 0, 1, 'حقل Field 1');
      expect(b.build(), isNot(contains('حقل')));
      expect(b.build(), contains('Field 1'));
    });

    test('large layouts do not draw every emitter', () {
      final dxf = IrrigationDxf.drip(
        widthM: 500,
        lengthM: 500,
        rowSpacingM: 1,
        plantSpacingM: 0.5,
        emittersPerPlant: 1,
      );
      expect(dxf, isNot(contains('EMITTER')));
    });

    test('pivot draws a circle', () {
      final dxf = IrrigationDxf.pivot(radiusM: 400);
      expect(dxf, contains('CIRCLE'));
    });
  });
}
