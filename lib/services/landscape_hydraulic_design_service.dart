/// محرك التصميم الهيدروليكي لتنسيق المواقع.
///
/// الترتيب المتّبع هو نفسه ترتيب مهندس الري:
/// 1) حساب احتياج كل مسطح من النباتات (ETc = ETo × Kc) وتصرف النقّاطات.
/// 2) تقسيم المسطحات إلى مناطق ري متوافقة مع تصرف المصدر.
/// 3) اختيار الخطوط الفرعية (اللترالات) بحيث لا تتجاوز السرعة الحد المسموح.
/// 4) اختيار الخط الرئيسي وفق تصرف أكبر مجموعة مناطق تعمل معًا.
/// 5) حساب مضخة نقطة التشغيل (تصرف + TDH) وقدرتها.
///
/// فاقد الاحتكاك بمعادلة هازن-ويليامز: hf = 10.67·L·Q^1.852 / (C^1.852·D^4.87)
library;

import 'dart:math' as math;

import '../models/landscape_design_models.dart';

/// أقطار المواسير المتاحة في السوق (مم).
const List<double> landscapePipeDiametersMm = [
  16, 20, 25, 32, 40, 50, 63, 75, 90, 110, 140, 160, 200,
];

class LandscapeDesignSettings {
  /// البخر-نتح المرجعي اليومي (مم/يوم) — يقدّر من الطقس أو يُدخل يدويًا.
  final double etoMmDay;

  /// كفاءة تطبيق المياه في الحقل (0–1).
  final double applicationEfficiency;

  /// كفاءة المضخة الكلية (0–1).
  final double pumpEfficiency;

  /// أقصى سرعة مسموحة في الخطوط الفرعية (م/ث).
  final double maxLateralVelocityMps;

  /// أقصى سرعة مسموحة في الخط الرئيسي (م/ث).
  final double maxMainVelocityMps;

  /// فاقد الفلتر والعداد (متر عمود ماء).
  final double filterLossM;

  /// معامل الوصلات والمحابس كنسبة من فاقد الاحتكاك.
  final double fittingsFactor;

  /// أقصى زمن ري يومي مقبول (دقائق) — إن تجاوزه النظام يحذّر بزيادة المناطق.
  final double maxDailyRuntimeMinutes;

  const LandscapeDesignSettings({
    this.etoMmDay = 6,
    this.applicationEfficiency = 0.85,
    this.pumpEfficiency = 0.65,
    this.maxLateralVelocityMps = 1.5,
    this.maxMainVelocityMps = 1.75,
    this.filterLossM = 5,
    this.fittingsFactor = 0.10,
    this.maxDailyRuntimeMinutes = 480,
  });

  LandscapeDesignSettings copyWith({
    double? etoMmDay,
    double? applicationEfficiency,
    double? pumpEfficiency,
    double? maxLateralVelocityMps,
    double? maxMainVelocityMps,
    double? filterLossM,
    double? fittingsFactor,
    double? maxDailyRuntimeMinutes,
  }) =>
      LandscapeDesignSettings(
        etoMmDay: etoMmDay ?? this.etoMmDay,
        applicationEfficiency: applicationEfficiency ?? this.applicationEfficiency,
        pumpEfficiency: pumpEfficiency ?? this.pumpEfficiency,
        maxLateralVelocityMps: maxLateralVelocityMps ?? this.maxLateralVelocityMps,
        maxMainVelocityMps: maxMainVelocityMps ?? this.maxMainVelocityMps,
        filterLossM: filterLossM ?? this.filterLossM,
        fittingsFactor: fittingsFactor ?? this.fittingsFactor,
        maxDailyRuntimeMinutes: maxDailyRuntimeMinutes ?? this.maxDailyRuntimeMinutes,
      );
}

/// قطعة ماسورة في الشبكة بعد اختيار قطرها.
class HydraulicPipeSegment {
  final String id;
  final String fromAr;
  final String toAr;

  /// lateral / submain / main
  final String role;
  final double flowLpm;
  final double lengthM;
  final double diameterMm;
  final double velocityMps;
  final double frictionHeadM;

  const HydraulicPipeSegment({
    required this.id,
    required this.fromAr,
    required this.toAr,
    required this.role,
    required this.flowLpm,
    required this.lengthM,
    required this.diameterMm,
    required this.velocityMps,
    required this.frictionHeadM,
  });

  String get roleLabelAr => switch (role) {
        'lateral' => 'خط فرعي',
        'submain' => 'خط تحت رئيسي',
        _ => 'خط رئيسي',
      };
}

/// تصميم منطقة ري واحدة (مسطح واحد أو مجموعة مسطحات بنفس النبات).
class LandscapeZoneDesign {
  final String shapeId;
  final String nameAr;
  final String plantName;
  final String methodLabel;
  final double areaM2;
  final double deviceCount;
  final double applicationRateMmH;
  final double dailyVolumeLitres;
  final double runtimeMinutes;

  /// عدد الخطوط الفرعية وكم خط يعمل في الدورة الواحدة.
  final int lateralCount;
  final int lateralsPerRun;
  final int runsPerZone;

  /// تصرف الدورة الواحدة — هو التصرف التصميمي للمنطقة.
  final double designFlowLpm;

  final HydraulicPipeSegment lateral;
  final HydraulicPipeSegment submain;

  /// الضغط المطلوب عند النقّاطة (متر).
  final double requiredPressureM;

  /// أقصى فرق ضغط داخل المنطقة كنسبة من الضغط التشغيلي (معيار التصميم).
  final double pressureVariationPercent;

  const LandscapeZoneDesign({
    required this.shapeId,
    required this.nameAr,
    required this.plantName,
    required this.methodLabel,
    required this.areaM2,
    required this.deviceCount,
    required this.applicationRateMmH,
    required this.dailyVolumeLitres,
    required this.runtimeMinutes,
    required this.lateralCount,
    required this.lateralsPerRun,
    required this.runsPerZone,
    required this.designFlowLpm,
    required this.lateral,
    required this.submain,
    required this.requiredPressureM,
    required this.pressureVariationPercent,
  });

  double get totalLateralLengthM => lateral.lengthM * lateralCount;
}

/// بند في جدول الكميات.
class LandscapeBoqLine {
  final String itemAr;
  final String unitAr;
  final double quantity;
  const LandscapeBoqLine({required this.itemAr, required this.unitAr, required this.quantity});
}

class LandscapePumpDesign {
  final double flowLpm;
  final double headM;
  final double hydraulicPowerKw;

  /// القدرة المطلوبة على عمود المحرك مع هامش 15%.
  final double motorPowerKw;
  final double efficiency;
  const LandscapePumpDesign({
    required this.flowLpm,
    required this.headM,
    required this.hydraulicPowerKw,
    required this.motorPowerKw,
    required this.efficiency,
  });

  /// أقرب قدرة موتور قياسية (حصان).
  double get recommendedHp => (motorPowerKw / 0.7457).ceilToDouble();
}

class LandscapeHydraulicDesign {
  final List<LandscapeZoneDesign> zones;
  final HydraulicPipeSegment main;
  final LandscapePumpDesign pump;
  final double totalAreaM2;
  final double totalDailyVolumeM3;
  final double totalPipeLengthM;
  final int mainValveCount;

  /// المناطق التي تعمل معًا في نفس الوقت وفق تصرف المصدر.
  final List<String> simultaneousZones;

  final List<LandscapeBoqLine> billOfMaterials;
  final List<String> warnings;

  /// شرح خطوة بخطوة بالمعادلات والقواعد المستخدمة.
  final List<String> steps;

  const LandscapeHydraulicDesign({
    required this.zones,
    required this.main,
    required this.pump,
    required this.totalAreaM2,
    required this.totalDailyVolumeM3,
    required this.totalPipeLengthM,
    required this.mainValveCount,
    required this.simultaneousZones,
    required this.billOfMaterials,
    required this.warnings,
    required this.steps,
  });

  bool get hasWarnings => warnings.isNotEmpty;
}

class LandscapeHydraulicDesignService {
  const LandscapeHydraulicDesignService();

  /// فاقد الاحتكاك بالمتر حسب هازن-ويليامز (C=140 للبولي إيثيلين/PVC).
  static double hazenWilliamsLossM({
    required double flowLpm,
    required double diameterMm,
    required double lengthM,
    double c = 140,
  }) {
    if (flowLpm <= 0 || diameterMm <= 0 || lengthM <= 0) return 0;
    final q = flowLpm / 60000; // m³/s
    final d = diameterMm / 1000; // m
    return 10.67 * lengthM * math.pow(q, 1.852) / (math.pow(c, 1.852) * math.pow(d, 4.87));
  }

  static double velocityMps({required double flowLpm, required double diameterMm}) {
    if (flowLpm <= 0 || diameterMm <= 0) return 0;
    final q = flowLpm / 60000;
    final d = diameterMm / 1000;
    return q / (math.pi * d * d / 4);
  }

  LandscapeHydraulicDesign design(
    LandscapePlan plan, {
    LandscapeDesignSettings settings = const LandscapeDesignSettings(),
  }) {
    final zones = <LandscapeZoneDesign>[];
    final warnings = <String>[];
    final steps = <String>[];
    final source = plan.waterSourcePoint;

    steps.add(
      'احتياج المياه اليومي: ETc = ETo × Kc = ${settings.etoMmDay.toStringAsFixed(1)} مم/يوم × معامل كل نبات، '
      'ثم صافي ÷ كفاءة التطبيق ${(settings.applicationEfficiency * 100).round()}٪.',
    );

    for (final shape in plan.shapes) {
      final type = shape.plantType;
      if (type == null || !type.needsIrrigation) continue;
      final area = shape.areaM2;
      if (area < 1) continue;

      final longSide = math.max(shape.widthM, shape.heightM);
      final shortSide = math.min(shape.widthM, shape.heightM);
      if (longSide <= 0 || shortSide <= 0) continue;

      // شبكة النقّاطات/الرشاشات: صفوف × نقّاطات في الصف.
      final rows = math.max(1, (shortSide / type.lateralSpacingM).ceil());
      final perRow = math.max(1, (longSide / type.spacingM).ceil());
      final devices = rows * perRow;

      final lateralFlowLpm = perRow * type.emitterFlowLpm;
      final lateralLengthM = longSide + 1.5; // + وصلة المحبس
      final lateral = _sizePipe(
        id: 'lateral-${shape.id}',
        fromAr: 'محبس ${shape.nameAr}',
        toAr: 'نهاية الخط',
        role: 'lateral',
        flowLpm: lateralFlowLpm,
        lengthM: lateralLengthM,
        maxVelocityMps: settings.maxLateralVelocityMps,
        onError: (message) => warnings.add('${shape.nameAr}: $message'),
      );

      // تقسيم التشغيل حسب تصرف المصدر: كم نقّاطة تعمل في الوقت نفسه.
      final totalDevices = rows * perRow;
      final runCapacity = math.max(type.emitterFlowLpm, plan.availableFlowLpm);
      final maxDevicesPerRun = math.max(1, (runCapacity / type.emitterFlowLpm).floor());
      final runsPerZone = math.max(1, (totalDevices / maxDevicesPerRun).ceil());
      final devicesPerRun = math.max(1, totalDevices ~/ runsPerZone);
      final lateralsPerRun = math.max(1, math.min(rows, (devicesPerRun / perRow).ceil()));
      final designFlowLpm = devicesPerRun * type.emitterFlowLpm;

      final submainLengthM = math.max(3.0, source.distanceTo(shape.centroid) * 1.2);
      final submain = _sizePipe(
        id: 'submain-${shape.id}',
        fromAr: 'الخط الرئيسي',
        toAr: 'محبس ${shape.nameAr}',
        role: 'submain',
        flowLpm: designFlowLpm,
        lengthM: submainLengthM,
        maxVelocityMps: settings.maxLateralVelocityMps,
        onError: (message) => warnings.add('${shape.nameAr}: $message'),
      );

      final dailyLitres = area * type.kc * settings.etoMmDay / settings.applicationEfficiency;
      final runtimeMinutes = designFlowLpm > 0 ? dailyLitres / designFlowLpm : 0.0;
      if (runtimeMinutes > settings.maxDailyRuntimeMinutes) {
        warnings.add(
          '${shape.nameAr}: زمن الري اليومي ${runtimeMinutes.round()} دقيقة يتجاوز الحد '
          '${settings.maxDailyRuntimeMinutes.round()} دقيقة — زوّد النقّاطات أو قسّم المنطقة.',
        );
      }

      final pressureVariation = lateral.frictionHeadM + submain.frictionHeadM;
      zones.add(
        LandscapeZoneDesign(
          shapeId: shape.id,
          nameAr: shape.nameAr,
          plantName: type.nameAr,
          methodLabel: type.method.labelAr,
          areaM2: area,
          deviceCount: devices.toDouble(),
          applicationRateMmH: area > 0 ? (designFlowLpm * 60 / area) : 0,
          dailyVolumeLitres: dailyLitres,
          runtimeMinutes: runtimeMinutes,
          lateralCount: rows,
          lateralsPerRun: lateralsPerRun,
          runsPerZone: runsPerZone,
          designFlowLpm: designFlowLpm,
          lateral: lateral,
          submain: submain,
          requiredPressureM: type.method.requiredPressureM,
          pressureVariationPercent: type.method.requiredPressureM > 0
              ? pressureVariation / type.method.requiredPressureM * 100
              : 0,
        ),
      );

      if (pressureVariation > type.method.requiredPressureM * 0.2) {
        warnings.add(
          '${shape.nameAr}: فرق الضغط بين أول وآخر نقّاطة ${pressureVariation.toStringAsFixed(1)} م '
          '(أكثر من 20٪ من ضغط التشغيل) — كبّر قطر الخط أو قصّر طوله.',
        );
      }
    }

    if (zones.isEmpty) {
      return LandscapeHydraulicDesign(
        zones: const [],
        main: _emptySegment(),
        pump: const LandscapePumpDesign(flowLpm: 0, headM: 0, hydraulicPowerKw: 0, motorPowerKw: 0, efficiency: 0),
        totalAreaM2: plan.areaM2,
        totalDailyVolumeM3: 0,
        totalPipeLengthM: 0,
        mainValveCount: 0,
        simultaneousZones: const [],
        billOfMaterials: const [],
        warnings: const ['أضف مسطحًا واحدًا على الأقل واختر له نباتًا يحتاج ريًا.'],
        steps: steps,
      );
    }

    // ترتيب المناطق من الأكبر تصرفًا لتجميع ما يمكن تشغيله معًا.
    final sorted = [...zones]..sort((a, b) => b.designFlowLpm.compareTo(a.designFlowLpm));
    final simultaneous = <String>[];
    var concurrentFlow = 0.0;
    for (final zone in sorted) {
      if (concurrentFlow + zone.designFlowLpm <= plan.availableFlowLpm) {
        simultaneous.add(zone.nameAr);
        concurrentFlow += zone.designFlowLpm;
      }
    }
    if (simultaneous.isEmpty) {
      simultaneous.add(sorted.first.nameAr);
      concurrentFlow = sorted.first.designFlowLpm;
    }
    if (sorted.length > simultaneous.length) {
      steps.add(
        'تصرف المصدر ${plan.availableFlowLpm.toStringAsFixed(0)} لتر/دقيقة لا يكفي لتشغيل كل المناطق معًا، '
        'لذلك يعمل ${simultaneous.length} منطقة في الدورة الواحدة والباقي بالتتابع.',
      );
    } else {
      steps.add('تصرف المصدر يكفي لتشغيل كل المناطق معًا، والخط الرئيسي يُصمّم على مجموع التصرفات.');
    }

    final farthest = zones.map((z) => source.distanceTo(_centroidOf(plan, z.shapeId))).fold<double>(0, math.max);
    final mainLengthM = math.max(5.0, farthest * 1.15 + 5);
    final main = _sizePipe(
      id: 'main',
      fromAr: 'المضخة/المصدر',
      toAr: 'أبعد نقطة تفرّع',
      role: 'main',
      flowLpm: concurrentFlow,
      lengthM: mainLengthM,
      maxVelocityMps: settings.maxMainVelocityMps,
      onError: warnings.add,
    );
    steps.add(
      'الخط الرئيسي: طول ≈ ${mainLengthM.toStringAsFixed(1)} م، تصرف ${concurrentFlow.toStringAsFixed(0)} لتر/دقيقة، '
      'قطر ${main.diameterMm.toStringAsFixed(0)} مم بسرعة ${main.velocityMps.toStringAsFixed(2)} م/ث '
      '(الحد ${settings.maxMainVelocityMps} م/ث).',
    );

    // نقطة التشغيل: أسوأ منطقة من حيث الضغط المطلوب + الفواقد.
    final critical = zones.reduce((a, b) =>
        (a.requiredPressureM + a.submain.frictionHeadM + a.lateral.frictionHeadM) >=
                (b.requiredPressureM + b.submain.frictionHeadM + b.lateral.frictionHeadM)
            ? a
            : b);
    final criticalLoss = critical.submain.frictionHeadM + critical.lateral.frictionHeadM;
    final valveLossM = 1.0;
    final subtotal = plan.staticLiftM +
        critical.requiredPressureM +
        criticalLoss +
        main.frictionHeadM +
        settings.filterLossM +
        valveLossM;
    final headM = subtotal * (1 + settings.fittingsFactor);
    final hydraulicKw = 998.2 * 9.80665 * (concurrentFlow / 60000) * headM / 1000;
    final pumpKw = settings.pumpEfficiency > 0 ? hydraulicKw / settings.pumpEfficiency : 0.0;
    final pump = LandscapePumpDesign(
      flowLpm: concurrentFlow,
      headM: headM,
      hydraulicPowerKw: hydraulicKw,
      motorPowerKw: pumpKw * 1.15,
      efficiency: settings.pumpEfficiency,
    );

    steps
      ..add(
        'المنطقة الحرجة للضغط: ${critical.nameAr} — تحتاج ${critical.requiredPressureM.toStringAsFixed(0)} م '
        'عند النقّاطة + ${criticalLoss.toStringAsFixed(1)} م فواقد خطوطها.',
      )
      ..add(
        'TDH = منسوب ثابت ${plan.staticLiftM.toStringAsFixed(1)} + ضغط تشغيل ${critical.requiredPressureM.toStringAsFixed(0)} '
        '+ فواقد ${criticalLoss.toStringAsFixed(1)} + رئيسي ${main.frictionHeadM.toStringAsFixed(1)} '
        '+ فلتر ${settings.filterLossM.toStringAsFixed(0)} + محبس 1.0 = ${headM.toStringAsFixed(1)} م '
        '(بعد هامش وصلات ${(settings.fittingsFactor * 100).round()}٪).',
      )
      ..add(
        'قدرة المضخة = ρ·g·Q·H / الكفاءة = ${pumpKw.toStringAsFixed(2)} كيلوواط، '
        'والموتور المقترح ${pump.motorPowerKw.toStringAsFixed(2)} كيلوواط (${pump.recommendedHp.toStringAsFixed(0)} حصان).',
      );

    if (plan.availableFlowLpm <= 0) {
      warnings.add('تصرف المصدر غير محدد؛ أدخل أقصى تصرف متاح لضبط عدد المناطق.');
    }
    if (critical.pressureVariationPercent > 20) {
      warnings.add('المنطقة ${critical.nameAr} تحتاج إعادة توزيع للضغط (فرق أكبر من 20٪).');
    }

    final totalDailyLitres = zones.fold<double>(0, (s, z) => s + z.dailyVolumeLitres);
    final totalPipe = zones.fold<double>(0, (s, z) => s + z.totalLateralLengthM + z.submain.lengthM) + main.lengthM;

    // جدول الكميات مجمّعًا حسب القطر.
    final pipeLengths = <double, double>{};
    void addPipe(double diameter, double length) =>
        pipeLengths[diameter] = (pipeLengths[diameter] ?? 0) + length;
    for (final zone in zones) {
      addPipe(zone.lateral.diameterMm, zone.totalLateralLengthM);
      addPipe(zone.submain.diameterMm, zone.submain.lengthM);
    }
    addPipe(main.diameterMm, main.lengthM);

    final boq = <LandscapeBoqLine>[
      for (final entry in (pipeLengths.keys.toList()..sort()))
        LandscapeBoqLine(
          itemAr: 'ماسورة ${entry.toStringAsFixed(0)} مم',
          unitAr: 'متر',
          quantity: pipeLengths[entry]!,
        ),
      LandscapeBoqLine(
        itemAr: 'نقّاطات/رشاشات',
        unitAr: 'قطعة',
        quantity: zones.fold<double>(0, (s, z) => s + z.deviceCount),
      ),
      LandscapeBoqLine(itemAr: 'محابس مناطق', unitAr: 'قطعة', quantity: zones.length.toDouble()),
      LandscapeBoqLine(itemAr: 'فلتر + وحدة تسميد', unitAr: 'طقم', quantity: 1),
    ];

    return LandscapeHydraulicDesign(
      zones: List.unmodifiable(zones),
      main: main,
      pump: pump,
      totalAreaM2: plan.areaM2,
      totalDailyVolumeM3: totalDailyLitres / 1000,
      totalPipeLengthM: totalPipe,
      mainValveCount: zones.length,
      simultaneousZones: List.unmodifiable(simultaneous),
      billOfMaterials: List.unmodifiable(boq),
      warnings: List.unmodifiable(warnings),
      steps: List.unmodifiable(steps),
    );
  }

  /// يختار أصغر قطر لا تتجاوز سرعته الحد المسموح.
  HydraulicPipeSegment _sizePipe({
    required String id,
    required String fromAr,
    required String toAr,
    required String role,
    required double flowLpm,
    required double lengthM,
    required double maxVelocityMps,
    required void Function(String message) onError,
  }) {
    var chosen = landscapePipeDiametersMm.first;
    var velocity = velocityMps(flowLpm: flowLpm, diameterMm: chosen);
    for (final diameter in landscapePipeDiametersMm) {
      final v = velocityMps(flowLpm: flowLpm, diameterMm: diameter);
      if (v <= maxVelocityMps) {
        chosen = diameter;
        velocity = v;
        break;
      }
    }
    if (velocity > maxVelocityMps) {
      onError(
        'التصرف ${flowLpm.toStringAsFixed(0)} لتر/دقيقة يحتاج قطرًا أكبر من '
        '${chosen.toStringAsFixed(0)} مم أو تقسيمًا إضافيًا.',
      );
    }
    final friction = hazenWilliamsLossM(flowLpm: flowLpm, diameterMm: chosen, lengthM: lengthM);
    return HydraulicPipeSegment(
      id: id,
      fromAr: fromAr,
      toAr: toAr,
      role: role,
      flowLpm: flowLpm,
      lengthM: lengthM,
      diameterMm: chosen,
      velocityMps: velocity,
      frictionHeadM: friction,
    );
  }

  PlanPoint _centroidOf(LandscapePlan plan, String shapeId) {
    for (final shape in plan.shapes) {
      if (shape.id == shapeId) return shape.centroid;
    }
    return plan.waterSourcePoint;
  }

  HydraulicPipeSegment _emptySegment() => const HydraulicPipeSegment(
        id: 'none',
        fromAr: '-',
        toAr: '-',
        role: 'main',
        flowLpm: 0,
        lengthM: 0,
        diameterMm: 0,
        velocityMps: 0,
        frictionHeadM: 0,
      );
}
