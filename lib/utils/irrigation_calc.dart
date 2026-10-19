import 'dart:math' as math;

/// وحدات المساحة المدعومة في حاسبة الري.
enum AreaUnit { feddan, hectare, squareMeter }

/// حسابات هيدروليكية لتصميم شبكات الري (تنقيط، رش، سطحي، محوري).
///
/// كل الدوال هنا نقية (بدون واجهة ولا قاعدة بيانات) وبترجع null لو
/// المدخلات غير صالحة، عشان تتختبر بسهولة وما تكسرش التطبيق.
class IrrigationCalc {
  IrrigationCalc._();

  static const double feddanM2 = 4200;
  static const double hectareM2 = 10000;

  /// الأقطار التجارية الشائعة (مم) - بتتعامل معاها كقطر داخلي تقريبي.
  static const List<double> standardDiametersMm = <double>[
    16, 20, 25, 32, 40, 50, 63, 75, 90, 110, 125, 160, 200, 250, 315,
  ];

  /// التحقق من أن القيمة موجبة ومحدودة (ليست NaN ولا Infinity)
  static bool _pos(double v) => v.isFinite && v > 0;

  static double areaToM2(double value, AreaUnit unit) {
    if (!_pos(value)) return 0;
    switch (unit) {
      case AreaUnit.feddan:
        return value * feddanM2;
      case AreaUnit.hectare:
        return value * hectareM2;
      case AreaUnit.squareMeter:
        return value;
    }
  }

  // ───────────────────── احتياج المياه ─────────────────────

  /// ETc = ETo × Kc (مم/يوم).
  static double? etc(double eto, double kc) {
    if (!_pos(eto) || !_pos(kc)) return null;
    return eto * kc;
  }

  static WaterNeed? waterNeed({
    required double areaM2,
    required double etcMmDay,
    required double efficiency,
    required double intervalDays,
  }) {
    if (!_pos(areaM2) || !_pos(etcMmDay) || !_pos(intervalDays)) return null;
    if (!_pos(efficiency) || efficiency > 1) return null;
    if (intervalDays < 1) return null;
    
    final grossDaily = etcMmDay / efficiency;
    final perIrrigation = grossDaily * intervalDays;
    
    return WaterNeed(
      grossDailyMm: grossDaily,
      grossPerIrrigationMm: perIrrigation,
      dailyVolumeM3: grossDaily * areaM2 / 1000,
      perIrrigationVolumeM3: perIrrigation * areaM2 / 1000,
    );
  }

  // ───────────────────── الأنابيب ─────────────────────

  /// سرعة المياه في الأنبوب (م/ث).
  static double velocity(double flowM3h, double diameterMm) {
    if (!_pos(flowM3h) || !_pos(diameterMm)) return 0;
    final d = diameterMm / 1000;
    return (flowM3h / 3600) / (math.pi * d * d / 4);
  }

  /// فاقد الضغط بمعادلة هازن-ويليامز (متر ماء).
  static double hazenWilliamsLoss({
    required double flowM3h,
    required double diameterMm,
    required double lengthM,
    double c = 140,
  }) {
    if (!_pos(flowM3h) || !_pos(diameterMm) || !_pos(lengthM) || !_pos(c)) {
      return 0;
    }
    final q = flowM3h / 3600;
    final d = diameterMm / 1000;
    final num top = 10.67 * lengthM * math.pow(q, 1.852);
    final num bottom = math.pow(c, 1.852) * math.pow(d, 4.87);
    return (top / bottom).toDouble();
  }

  /// معامل كريستيانسن للأنابيب ذات المخارج المتعددة.
  static double christiansenF(int outlets) {
    if (outlets <= 1) return 1;
    const m = 1.852;
    final n = outlets.toDouble();
    return 1 / (m + 1) + 1 / (2 * n) + math.sqrt(m - 1) / (6 * n * n);
  }

  /// أصغر قطر تجاري يحقق حد السرعة (وحد الفاقد لو اتحدد).
  static PipeChoice pickDiameter({
    required double flowM3h,
    required double lengthM,
    double maxVelocityMs = 1.5,
    double? maxLossM,
    double c = 140,
  }) {
    // حماية لو التدفق أو الطول مش صالحين
    if (!_pos(flowM3h) || !_pos(lengthM)) {
      return const PipeChoice(
        diameterMm: 0,
        velocityMs: 0,
        lossM: 0,
        ok: false,
      );
    }

    for (final d in standardDiametersMm) {
      final v = velocity(flowM3h, d);
      final loss = hazenWilliamsLoss(
          flowM3h: flowM3h, diameterMm: d, lengthM: lengthM, c: c);
      final ok = v <= maxVelocityMs && (maxLossM == null || loss <= maxLossM);
      
      if (ok) {
        return PipeChoice(diameterMm: d, velocityMs: v, lossM: loss, ok: true);
      }
    }
    
    // لو مفيش قطر حقق الشروط، نرجع أكبر قطر مع ok = false
    final largest = standardDiametersMm.last;
    return PipeChoice(
      diameterMm: largest,
      velocityMs: velocity(flowM3h, largest),
      lossM: hazenWilliamsLoss(
          flowM3h: flowM3h, diameterMm: largest, lengthM: lengthM, c: c),
      ok: false,
    );
  }

  // ───────────────────── الري بالتنقيط ─────────────────────

  static DripResult? drip({
    required double areaM2,
    required double rowSpacingM,
    required double plantSpacingM,
    required int emittersPerPlant,
    required double emitterLph,
    required double etcMmDay,
    required double efficiency,
    required double intervalDays,
    required double availableHours,
    required int sectors,
    required double lateralLengthM,
    required double lateralDiameterMm,
    required double operatingHeadM,
  }) {
    if (!_pos(rowSpacingM) ||
        !_pos(plantSpacingM) ||
        !_pos(emitterLph) ||
        !_pos(availableHours) ||
        !_pos(lateralLengthM) ||
        !_pos(lateralDiameterMm) ||
        !_pos(operatingHeadM) ||
        emittersPerPlant < 1 ||
        sectors < 1) {
      return null;
    }
    final need = waterNeed(
      areaM2: areaM2,
      etcMmDay: etcMmDay,
      efficiency: efficiency,
      intervalDays: intervalDays,
    );
    if (need == null) return null;

    final plants = areaM2 / (rowSpacingM * plantSpacingM);
    final totalEmitters = plants * emittersPerPlant;
    final litersPerPlant =
        need.grossPerIrrigationMm * rowSpacingM * plantSpacingM;
    final runtime = litersPerPlant / (emittersPerPlant * emitterLph);
    final totalFlow = totalEmitters * emitterLph / 1000;

    // حماية من القسمة على صفر أو قيم غير منطقية
    final emittersPerLateralRaw = lateralLengthM / plantSpacingM * emittersPerPlant;
    final emittersPerLateral = math.max(1, emittersPerLateralRaw.round());

    final lateralFlow = emittersPerLateral * emitterLph / 1000;
    final lateralLoss = hazenWilliamsLoss(
          flowM3h: lateralFlow,
          diameterMm: lateralDiameterMm,
          lengthM: lateralLengthM,
          c: 150,
        ) *
        christiansenF(emittersPerLateral);
        
    // التباين المسموح 20% من ضغط التشغيل، نصيب الخط الفرعي منه 55%
    final allowedLoss = 0.2 * operatingHeadM * 0.55;
    final endFlowPct =
        math.sqrt(math.max(0, operatingHeadM - lateralLoss) / operatingHeadM) *
            100;

    return DripResult(
      need: need,
      plants: plants,
      totalEmitters: totalEmitters,
      litersPerPlantPerIrrigation: litersPerPlant,
      runtimeHoursPerSector: runtime,
      maxSectors: (availableHours / runtime).floor(),
      sectorsOk: sectors * runtime <= availableHours + 1e-9,
      totalFlowM3h: totalFlow,
      sectorFlowM3h: totalFlow / sectors,
      lateralFlowM3h: lateralFlow,
      lateralLossM: lateralLoss,
      allowedLateralLossM: allowedLoss,
      lateralOk: lateralLoss <= allowedLoss,
      endEmitterFlowPct: endFlowPct,
      lateralTotalLengthM: areaM2 / rowSpacingM,
    );
  }

  // ───────────────────── الري بالرش ─────────────────────

  static SprinklerResult? sprinkler({
    required double areaM2,
    required double sprinklerM3h,
    required double spacingAlongM,
    required double spacingAcrossM,
    required double etcMmDay,
    required double efficiency,
    required double intervalDays,
    required double availableHours,
    required int sectors,
    double? infiltrationMmH,
  }) {
    if (!_pos(sprinklerM3h) ||
        !_pos(spacingAlongM) ||
        !_pos(spacingAcrossM) ||
        !_pos(availableHours) ||
        sectors < 1) {
      return null;
    }
    if (infiltrationMmH != null && !_pos(infiltrationMmH)) return null;
    final need = waterNeed(
      areaM2: areaM2,
      etcMmDay: etcMmDay,
      efficiency: efficiency,
      intervalDays: intervalDays,
    );
    if (need == null) return null;

    final cell = spacingAlongM * spacingAcrossM;
    final rate = sprinklerM3h * 1000 / cell;
    final runtime = need.grossPerIrrigationMm / rate;
    final count = (areaM2 / cell).ceil();
    final totalFlow = count * sprinklerM3h;
    
    return SprinklerResult(
      need: need,
      applicationRateMmH: rate,
      runtimeHoursPerSector: runtime,
      maxSectors: (availableHours / runtime).floor(),
      sectorsOk: sectors * runtime <= availableHours + 1e-9,
      sprinklers: count,
      totalFlowM3h: totalFlow,
      sectorFlowM3h: totalFlow / sectors,
      infiltrationOk: infiltrationMmH == null || rate <= infiltrationMmH,
    );
  }

  // ───────────────────── الري السطحي ─────────────────────

  static SurfaceResult? surface({
    required double areaM2,
    required double etcMmDay,
    required double efficiency,
    required double intervalDays,
    required double streamLps,
    required double availableHours,
  }) {
    if (!_pos(streamLps) || !_pos(availableHours)) return null;
    final need = waterNeed(
      areaM2: areaM2,
      etcMmDay: etcMmDay,
      efficiency: efficiency,
      intervalDays: intervalDays,
    );
    if (need == null) return null;
    
    final flowM3h = streamLps * 3.6;
    final hours = need.perIrrigationVolumeM3 / flowM3h;
    
    return SurfaceResult(
      need: need,
      flowM3h: flowM3h,
      irrigationHours: hours,
      ok: hours <= availableHours,
    );
  }

  // ───────────────────── الري المحوري ─────────────────────

  static PivotResult? pivot({
    required double radiusM,
    required double etcMmDay,
    required double efficiency,
    required double intervalDays,
    required double hoursPerRotation,
  }) {
    if (!_pos(radiusM) || !_pos(hoursPerRotation)) return null;
    
    final area = math.pi * radiusM * radiusM;
    final need = waterNeed(
      areaM2: area,
      etcMmDay: etcMmDay,
      efficiency: efficiency,
      intervalDays: intervalDays,
    );
    if (need == null) return null;
    
    final flowM3h = need.perIrrigationVolumeM3 / hoursPerRotation;
    
    return PivotResult(
      need: need,
      areaM2: area,
      flowM3h: flowM3h,
      flowLps: flowM3h / 3.6,
      endTowerSpeedMh: 2 * math.pi * radiusM / hoursPerRotation,
      fitsInterval: hoursPerRotation <= intervalDays * 24,
    );
  }

  // ───────────────────── المضخة ─────────────────────

  static PumpResult? pump({
    required double flowM3h,
    required double staticLiftM,
    required double operatingHeadM,
    required double frictionLossM,
    required double minorLossPct,
    required double equipmentLossM,
    required double pumpEfficiency,
    required double motorEfficiency,
  }) {
    if (!_pos(flowM3h) ||
        !_pos(pumpEfficiency) ||
        pumpEfficiency > 1 ||
        !_pos(motorEfficiency) ||
        motorEfficiency > 1) {
      return null;
    }
    if (staticLiftM < 0 ||
        operatingHeadM < 0 ||
        frictionLossM < 0 ||
        minorLossPct < 0 ||
        equipmentLossM < 0) {
      return null;
    }
    
    final head = staticLiftM +
        operatingHeadM +
        frictionLossM * (1 + minorLossPct / 100) +
        equipmentLossM;
        
    final hydraulicKw = flowM3h * head / 367.2;
    final shaftKw = hydraulicKw / pumpEfficiency;
    final inputKw = shaftKw / motorEfficiency;
    
    return PumpResult(
      totalHeadM: head,
      hydraulicKw: hydraulicKw,
      shaftKw: shaftKw,
      motorInputKw: inputKw,
      recommendedMotorKw: shaftKw * 1.15,
      recommendedMotorHp: shaftKw * 1.15 * 1.341,
    );
  }
}

// ───────────────────── Data Classes ─────────────────────

class WaterNeed {
  final double grossDailyMm;
  final double grossPerIrrigationMm;
  final double dailyVolumeM3;
  final double perIrrigationVolumeM3;
  
  const WaterNeed({
    required this.grossDailyMm,
    required this.grossPerIrrigationMm,
    required this.dailyVolumeM3,
    required this.perIrrigationVolumeM3,
  });
}

class PipeChoice {
  final double diameterMm;
  final double velocityMs;
  final double lossM;
  final bool ok;
  
  const PipeChoice({
    required this.diameterMm,
    required this.velocityMs,
    required this.lossM,
    required this.ok,
  });
}

class DripResult {
  final WaterNeed need;
  final double plants;
  final double totalEmitters;
  final double litersPerPlantPerIrrigation;
  final double runtimeHoursPerSector;
  final int maxSectors;
  final bool sectorsOk;
  final double totalFlowM3h;
  final double sectorFlowM3h;
  final double lateralFlowM3h;
  final double lateralLossM;
  final double allowedLateralLossM;
  final bool lateralOk;
  final double endEmitterFlowPct;
  final double lateralTotalLengthM;
  
  const DripResult({
    required this.need,
    required this.plants,
    required this.totalEmitters,
    required this.litersPerPlantPerIrrigation,
    required this.runtimeHoursPerSector,
    required this.maxSectors,
    required this.sectorsOk,
    required this.totalFlowM3h,
    required this.sectorFlowM3h,
    required this.lateralFlowM3h,
    required this.lateralLossM,
    required this.allowedLateralLossM,
    required this.lateralOk,
    required this.endEmitterFlowPct,
    required this.lateralTotalLengthM,
  });
}

class SprinklerResult {
  final WaterNeed need;
  final double applicationRateMmH;
  final double runtimeHoursPerSector;
  final int maxSectors;
  final bool sectorsOk;
  final int sprinklers;
  final double totalFlowM3h;
  final double sectorFlowM3h;
  final bool infiltrationOk;
  
  const SprinklerResult({
    required this.need,
    required this.applicationRateMmH,
    required this.runtimeHoursPerSector,
    required this.maxSectors,
    required this.sectorsOk,
    required this.sprinklers,
    required this.totalFlowM3h,
    required this.sectorFlowM3h,
    required this.infiltrationOk,
  });
}

class SurfaceResult {
  final WaterNeed need;
  final double flowM3h;
  final double irrigationHours;
  final bool ok;
  
  const SurfaceResult({
    required this.need,
    required this.flowM3h,
    required this.irrigationHours,
    required this.ok,
  });
}

class PivotResult {
  final WaterNeed need;
  final double areaM2;
  final double flowM3h;
  final double flowLps;
  final double endTowerSpeedMh;
  final bool fitsInterval;
  
  const PivotResult({
    required this.need,
    required this.areaM2,
    required this.flowM3h,
    required this.flowLps,
    required this.endTowerSpeedMh,
    required this.fitsInterval,
  });
}

class PumpResult {
  final double totalHeadM;
  final double hydraulicKw;
  final double shaftKw;
  final double motorInputKw;
  final double recommendedMotorKw;
  final double recommendedMotorHp;
  
  const PumpResult({
    required this.totalHeadM,
    required this.hydraulicKw,
    required this.shaftKw,
    required this.motorInputKw,
    required this.recommendedMotorKw,
    required this.recommendedMotorHp,
  });
}
