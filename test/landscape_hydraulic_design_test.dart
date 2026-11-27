import 'package:agri_app/models/landscape_design_models.dart';
import 'package:agri_app/services/landscape_hydraulic_design_service.dart';
import 'package:flutter_test/flutter_test.dart';

LandscapeShape _square({
  required String id,
  required double size,
  required String plantId,
  double x = 0,
  double y = 0,
}) =>
    LandscapeShape(
      id: id,
      nameAr: 'مسطح $id',
      plantTypeId: plantId,
      points: [
        PlanPoint(x, y),
        PlanPoint(x + size, y),
        PlanPoint(x + size, y + size),
        PlanPoint(x, y + size),
      ],
    );

LandscapePlan _plan({List<LandscapeShape> shapes = const [], double flow = 120}) => LandscapePlan(
      id: 'p1',
      nameAr: 'حديقة',
      plotWidthM: 30,
      plotHeightM: 20,
      shapes: shapes,
      availableFlowLpm: flow,
    );

void main() {
  group('حساب مساحة اللاندسكيب', () {
    test('مساحة المربع 10×10 تساوي 100 م²', () {
      final shape = _square(id: 'a', size: 10, plantId: 'lawn');
      expect(shape.areaM2, closeTo(100, 0.001));
      expect(shape.widthM, closeTo(10, 0.001));
    });

    test('المساحة اليدوية تسبق المساحة المحسوبة من الرسم', () {
      final plan = _plan(shapes: [_square(id: 'a', size: 10, plantId: 'lawn')])
          .copyWith(areaSource: LandscapeAreaSource.manual, manualAreaM2: 250);
      expect(plan.drawnAreaM2, closeTo(100, 0.001));
      expect(plan.areaM2, 250);
    });

    test('بدون رسم حدود تعمل الخطة بالمساحة المكتوبة فقط', () {
      final plan = _plan().copyWith(areaSource: LandscapeAreaSource.manual, manualAreaM2: 400);
      expect(plan.areaM2, 400);
      expect(plan.shapes, isEmpty);
    });
  });

  group('التصميم الهيدروليكي', () {
    test('مسطح نجيل 10×10 ينتج منطقة واحدة وتصرفًا وخطًا فرعيًا صحيحًا', () {
      final plan = _plan(shapes: [_square(id: 'lawn', size: 10, plantId: 'lawn')]);
      final design = const LandscapeHydraulicDesignService().design(plan);

      expect(design.zones, hasLength(1));
      final zone = design.zones.first;
      // صفوف = 2، رشاشات في الصف = 2، وكلها تعمل معًا: 4 × 14 = 56 لتر/دقيقة.
      expect(zone.designFlowLpm, closeTo(56, 0.001));
      expect(zone.lateralCount, 2);
      expect(zone.requiredPressureM, 25);
      expect(design.pump.headM, greaterThan(25));
      expect(design.pump.motorPowerKw, greaterThan(0));
      expect(design.main.lengthM, greaterThan(0));
    });

    test('كل الأقطار المختارة تحقق حد السرعة', () {
      final plan = _plan(shapes: [
        _square(id: 'lawn', size: 12, plantId: 'lawn'),
        _square(id: 'rose', size: 6, plantId: 'rose', x: 14),
      ]);
      final design = const LandscapeHydraulicDesignService().design(plan);
      expect(design.zones, hasLength(2));
      for (final zone in design.zones) {
        expect(zone.lateral.velocityMps, lessThanOrEqualTo(1.5 + 1e-9));
        expect(zone.submain.velocityMps, lessThanOrEqualTo(1.5 + 1e-9));
      }
      expect(design.main.velocityMps, lessThanOrEqualTo(1.75 + 1e-9));
    });

    test('تصرف مصدر صغير يقسّم المنطقة إلى دورات', () {
      final plan = _plan(
        shapes: [_square(id: 'lawn', size: 40, plantId: 'lawn')],
        flow: 60,
      );
      final zone = const LandscapeHydraulicDesignService().design(plan).zones.first;
      expect(zone.runsPerZone, greaterThan(1));
      expect(zone.lateralsPerRun, lessThan(zone.lateralCount));
      expect(zone.designFlowLpm, lessThanOrEqualTo(60));
    });

    test('النباتات ذات Kc المختلف تعطي مناطق بطبيعة ري مختلفة', () {
      final plan = _plan(shapes: [
        _square(id: 'lawn', size: 8, plantId: 'lawn'),
        _square(id: 'cactus', size: 8, plantId: 'cactus', x: 10),
        _square(id: 'paved', size: 4, plantId: 'paved', x: 20),
      ]);
      final design = const LandscapeHydraulicDesignService().design(plan);
      final methods = design.zones.map((z) => z.methodLabel).toSet();
      expect(design.zones, hasLength(2), reason: 'الممر الصلب لا يدخل حسابات الري');
      expect(methods.length, greaterThan(1));
    });

    test('جدول الكميات يشمل المواسير والنقّاطات والمحابس', () {
      final plan = _plan(shapes: [_square(id: 'lawn', size: 10, plantId: 'lawn')]);
      final design = const LandscapeHydraulicDesignService().design(plan);
      final items = design.billOfMaterials.map((line) => line.itemAr).join(' | ');
      expect(items, contains('ماسورة'));
      expect(items, contains('نقّاطات/رشاشات'));
      expect(items, contains('محابس'));
      expect(design.totalPipeLengthM, greaterThan(0));
    });

    test('المساحة اليدوية بدون مسطحات ترجع تنبيهًا واضحًا', () {
      final plan = _plan().copyWith(areaSource: LandscapeAreaSource.manual, manualAreaM2: 300);
      final design = const LandscapeHydraulicDesignService().design(plan);
      expect(design.zones, isEmpty);
      expect(design.warnings.join(' '), contains('مسطح'));
    });

    test('خطوات التصميم تشرح TDH وقدرة المضخة', () {
      final plan = _plan(shapes: [_square(id: 'olive', size: 12, plantId: 'olive')]);
      final design = const LandscapeHydraulicDesignService().design(plan);
      final steps = design.steps.join(' ');
      expect(steps, contains('TDH'));
      expect(steps, contains('قدرة المضخة'));
      expect(steps, anyOf(contains('هازن'), contains('ETc')));
    });
  });

  group('معادلات الماسورة', () {
    test('السرعة تزيد بانخفاض القطر', () {
      final small = LandscapeHydraulicDesignService.velocityMps(flowLpm: 50, diameterMm: 20);
      final large = LandscapeHydraulicDesignService.velocityMps(flowLpm: 50, diameterMm: 40);
      expect(small, greaterThan(large));
    });

    test('فاقد هازن-ويليامز يتناسب طرديًا مع الطول', () {
      final short = LandscapeHydraulicDesignService.hazenWilliamsLossM(
          flowLpm: 40, diameterMm: 32, lengthM: 10);
      final long = LandscapeHydraulicDesignService.hazenWilliamsLossM(
          flowLpm: 40, diameterMm: 32, lengthM: 20);
      expect(long, closeTo(short * 2, short * 0.001));
      expect(short, greaterThan(0));
    });
  });
}
