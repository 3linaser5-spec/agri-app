import 'dart:math';

enum AreaUnit { feddan, hectare, squareMeter }

class WaterNeedResult {
  final double grossDailyMm;
  final double grossPerIrrigationMm;
  final double dailyVolumeM3;
  final double perIrrigationVolumeM3;

  const WaterNeedResult({
    required this.grossDailyMm,
    required this.grossPerIrrigationMm,
    required this.dailyVolumeM3,
    required this.perIrrigationVolumeM3,
  });
}

class PipeDiameterResult {
  final int diameterMm;
  final double velocityMs;
  final double frictionLossM;
  final bool ok;

  /// سبب الفشل (null لو ok = true)
  final String? failureReason;

  const PipeDiameterResult({
    required this.diameterMm,
    required this.velocityMs,
    required this.frictionLossM,
    required this.ok,
    this.failureReason,
  });
}

class DripResult {
  final double plants;
  final double totalEmitters;
  final double totalFlowM3h;
  final double sectorFlowM3h;
  final double litersPerPlantPerIrrigation;

  /// زمن التشغيل للدورة الواحدة (كل القطاعات تتشارك نفس القيمة)
  final double runtimeHoursPerCycle;
  final double lateralTotalLengthM;
  final int maxSectors;
  final bool sectorsOk;
  final double lateralLossM;
  final double allowedLateralLossM;
  final double endEmitterFlowPct;
  final bool lateralOk;

  // بيانات الخط الرئيسي وتحت الرئيسي وفواقد الشبكة الكلية
  final double mainLengthM;
  final double subMainLengthM;
  final double mainDiameterMm;
  final double subMainDiameterMm;
  final double mainLossM;
  final double subMainLossM;
  final double totalNetworkLossM;
  final double requiredPumpHeadM;
  final double networkLossPct;
  final bool networkOk;

  const DripResult({
    required this.plants,
    required this.totalEmitters,
    required this.totalFlowM3h,
    required this.sectorFlowM3h,
    required this.litersPerPlantPerIrrigation,
    required this.runtimeHoursPerCycle,
    required this.lateralTotalLengthM,
    required this.maxSectors,
    required this.sectorsOk,
    required this.lateralLossM,
    required this.allowedLateralLossM,
    required this.endEmitterFlowPct,
    required this.lateralOk,
    required this.mainLengthM,
    required this.subMainLengthM,
    required this.mainDiameterMm,
    required this.subMainDiameterMm,
    required this.mainLossM,
    required this.subMainLossM,
    required this.totalNetworkLossM,
    required this.requiredPumpHeadM,
    required this.networkLossPct,
    required this.networkOk,
  });

  /// اسم قديم للتوافق مع الكود القائم
  double get runtimeHoursPerSector => runtimeHoursPerCycle;
}

class SprinklerResult {
  final double applicationRateMmH;
  final int sprinklers;
  final double runtimeHoursPerSector;
  final double totalFlowM3h;
  final double sectorFlowM3h;
  final bool infiltrationOk;
  final bool sectorsOk;

  const SprinklerResult({
    required this.applicationRateMmH,
    required this.sprinklers,
    required this.runtimeHoursPerSector,
    required this.totalFlowM3h,
    required this.sectorFlowM3h,
    required this.infiltrationOk,
    required this.sectorsOk,
  });
}

class SurfaceResult {
  final double irrigationHours;
  final double perIrrigationVolumeM3;
  final bool ok;

  const SurfaceResult({
    required this.irrigationHours,
    required this.perIrrigationVolumeM3,
    required this.ok,
  });
}

class PivotResult {
  final double areaM2;
  final double flowM3h;
  final double flowLps;
  final double endTowerSpeedMh;
  final double grossPerApplicationMm;
  final bool fitsInterval;

  const PivotResult({
    required this.areaM2,
    required this.flowM3h,
    required this.flowLps,
    required this.endTowerSpeedMh,
    required this.grossPerApplicationMm,
    required this.fitsInterval,
  });

  /// اسم قديم للتوافق
  double get grossPerRotationMm => grossPerApplicationMm;
}

class PumpResult {
  final double totalHeadM;
  final double hydraulicKw;
  final double shaftKw;
  final double motorInputKw;
  final double recommendedMotorKw;
  final double standardMotorKw;

  double get recommendedMotorHp => recommendedMotorKw * 1.34102;
  double get standardMotorHp => standardMotorKw * 1.34102;

  const PumpResult({
    required this.totalHeadM,
    required this.hydraulicKw,
    required this.shaftKw,
    required this.motorInputKw,
    required this.recommendedMotorKw,
    required this.standardMotorKw,
  });
}

class IrrigationCalc {
  static const List<int> standardDiametersMm = [
    16, 20, 25, 32, 40, 50, 63, 75, 90, 110,
    125, 140, 160, 200, 225, 250, 315,
  ];

  /// قدرات الموتورات القياسية (kW)
  static const List<double> standardMotorKw = [
    0.37, 0.55, 0.75, 1.1, 1.5, 2.2, 3.0, 4.0, 5.5,
    7.5, 11.0, 15.0, 18.5, 22.0, 30.0, 37.0, 45.0,
    55.0, 75.0, 90.0, 110.0, 132.0, 160.0, 200.0,
  ];

  static double areaToM2(double value, AreaUnit unit) {
    if (value <= 0) return 0;
    switch (unit) {
      case AreaUnit.feddan:
        return value * 4200.0;
      case AreaUnit.hectare:
        return value * 10000.0;
      case AreaUnit.squareMeter:
        return value;
    }
  }

  static double? etc(double etoMmDay, double kc) {
    if (etoMmDay <= 0 || kc <= 0) return null;
    return etoMmDay * kc;
  }

  static WaterNeedResult? waterNeed({
    required double areaM2,
    required double etcMmDay,
    required double efficiency,
    required double intervalDays,
  }) {
    if (areaM2 <= 0 ||
        etcMmDay <= 0 ||
        efficiency <= 0 ||
        efficiency > 1.0 ||
        intervalDays < 1.0) {
      return null;
    }

    final grossDailyMm = etcMmDay / efficiency;
    final grossPerIrrigationMm = grossDailyMm * intervalDays;
    final dailyVolumeM3 = (grossDailyMm / 1000.0) * areaM2;
    final perIrrigationVolumeM3 = (grossPerIrrigationMm / 1000.0) * areaM2;

    return WaterNeedResult(
      grossDailyMm: grossDailyMm,
      grossPerIrrigationMm: grossPerIrrigationMm,
      dailyVolumeM3: dailyVolumeM3,
      perIrrigationVolumeM3: perIrrigationVolumeM3,
    );
  }

  static double velocity(double flowM3h, double diameterMm) {
    if (flowM3h <= 0 || diameterMm <= 0) return 0;
    final qM3s = flowM3h / 3600.0;
    final dM = diameterMm / 1000.0;
    final areaM2 = pi * dM * dM / 4.0;
    return qM3s / areaM2;
  }

  static double hazenWilliamsLoss({
    required double flowM3h,
    required double diameterMm,
    required double lengthM,
    double c = 150.0,
  }) {
    if (flowM3h <= 0 || diameterMm <= 0 || lengthM <= 0 || c <= 0) return 0;
    final qM3s = flowM3h / 3600.0;
    final dM = diameterMm / 1000.0;
    return 10.67 *
        lengthM *
        pow(qM3s, 1.852) /
        (pow(c, 1.852) * pow(dM, 4.87));
  }

  static double christiansenF(int outlets, {double m = 1.852}) {
    if (outlets <= 1) return 1.0;
    return (1.0 / (m + 1.0)) +
        (1.0 / (2.0 * outlets)) +
        (sqrt(m - 1.0) / (6.0 * outlets * outlets));
  }

  static PipeDiameterResult pickDiameter({
    required double flowM3h,
    required double lengthM,
    double maxVelocityMs = 1.5,
    double? maxFrictionLossM,
    double c = 150.0,
  }) {
    if (flowM3h <= 0) {
      return PipeDiameterResult(
        diameterMm: standardDiametersMm.first,
        velocityMs: 0,
        frictionLossM: 0,
        ok: false,
        failureReason: 'flow must be > 0',
      );
    }
    if (lengthM <= 0) {
      return PipeDiameterResult(
        diameterMm: standardDiametersMm.first,
        velocityMs: 0,
        frictionLossM: 0,
        ok: false,
        failureReason: 'length must be > 0',
      );
    }

    for (final d in standardDiametersMm) {
      final dd = d.toDouble();
      final v = velocity(flowM3h, dd);
      if (v > maxVelocityMs) continue;

      final hf = hazenWilliamsLoss(
        flowM3h: flowM3h,
        diameterMm: dd,
        lengthM: lengthM,
        c: c,
      );
      if (maxFrictionLossM != null && hf > maxFrictionLossM) continue;

      return PipeDiameterResult(
        diameterMm: d,
        velocityMs: v,
        frictionLossM: hf,
        ok: true,
      );
    }

    final largest = standardDiametersMm.last;
    return PipeDiameterResult(
      diameterMm: largest,
      velocityMs: velocity(flowM3h, largest.toDouble()),
      frictionLossM: hazenWilliamsLoss(
        flowM3h: flowM3h,
        diameterMm: largest.toDouble(),
        lengthM: lengthM,
        c: c,
      ),
      ok: false,
      failureReason: maxFrictionLossM != null
          ? 'no diameter meets velocity and friction limits'
          : 'no diameter meets velocity limit',
    );
  }

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
    double? mainLengthM,
    double? subMainLengthM,
    double? mainDiameterMm,
    double? subMainDiameterMm,
  }) {
    if (areaM2 <= 0 ||
        rowSpacingM <= 0 ||
        plantSpacingM <= 0 ||
        emittersPerPlant <= 0 ||
        emitterLph <= 0 ||
        etcMmDay <= 0 ||
        efficiency <= 0 ||
        efficiency > 1.0 ||
        intervalDays < 1.0 ||
        availableHours <= 0 ||
        sectors <= 0 ||
        lateralLengthM <= 0 ||
        lateralDiameterMm <= 0 ||
        operatingHeadM <= 0) {
      return null;
    }

    if ((mainLengthM != null && mainLengthM <= 0) ||
        (subMainLengthM != null && subMainLengthM <= 0) ||
        (mainDiameterMm != null && mainDiameterMm <= 0) ||
        (subMainDiameterMm != null && subMainDiameterMm <= 0)) {
      return null;
    }

    final plants = areaM2 / (rowSpacingM * plantSpacingM);
    final totalEmitters = plants * emittersPerPlant;
    final totalFlowM3h = (totalEmitters * emitterLph) / 1000.0;
    final sectorFlowM3h = totalFlowM3h / sectors;

    final grossDepthMm = (etcMmDay / efficiency) * intervalDays;
    final plantAreaM2 = rowSpacingM * plantSpacingM;
    final litersPerPlantPerIrrigation = grossDepthMm * plantAreaM2;

    final plantFlowLph = emittersPerPlant * emitterLph;
    final runtimeHoursPerCycle = litersPerPlantPerIrrigation / plantFlowLph;

    final lateralTotalLengthM = areaM2 / rowSpacingM;

    final maxSectors = max(1, (availableHours / runtimeHoursPerCycle).floor());
    final sectorsOk = (runtimeHoursPerCycle * sectors) <= availableHours;

    // 1. حساب فواقد الخرطوم الفرعي (Lateral)
    final emittersPerLateral = max(
      1,
      (lateralLengthM / plantSpacingM).floor() * emittersPerPlant,
    );
    final lateralFlowM3h = (emittersPerLateral * emitterLph) / 1000.0;
    final fFactor = christiansenF(emittersPerLateral);
    final lateralLossM = hazenWilliamsLoss(
          flowM3h: lateralFlowM3h,
          diameterMm: lateralDiameterMm,
          lengthM: lateralLengthM,
          c: 140.0,
        ) *
        fFactor;

    final allowedLateralLossM = operatingHeadM * 0.20;
    final endHeadM = max(0.0, operatingHeadM - lateralLossM);
    final endEmitterFlowPct =
        (sqrt(endHeadM / operatingHeadM) * 100.0).clamp(0.0, 100.0);
    final lateralOk = lateralLossM <= allowedLateralLossM;

    // 2. حساب أطوال وأقطار وفواقد الخط الرئيسي (Main) وتحت الرئيسي (Sub-main)
    final effectiveMainLengthM = mainLengthM ?? sqrt(areaM2);
    final effectiveSubMainLengthM =
        subMainLengthM ?? max(1.0, areaM2 / (lateralLengthM * sectors));

    final effectiveMainDiameterMm = mainDiameterMm ??
        pickDiameter(
          flowM3h: sectorFlowM3h,
          lengthM: effectiveMainLengthM,
        ).diameterMm.toDouble();

    final effectiveSubMainDiameterMm = subMainDiameterMm ??
        pickDiameter(
          flowM3h: sectorFlowM3h,
          lengthM: effectiveSubMainLengthM,
        ).diameterMm.toDouble();

    final mainLossM = hazenWilliamsLoss(
      flowM3h: sectorFlowM3h,
      diameterMm: effectiveMainDiameterMm,
      lengthM: effectiveMainLengthM,
      c: 150.0,
    );

    final subMainOutlets =
        max(1, (effectiveSubMainLengthM / rowSpacingM).floor());
    final subMainF = christiansenF(subMainOutlets);
    final subMainLossM = hazenWilliamsLoss(
          flowM3h: sectorFlowM3h,
          diameterMm: effectiveSubMainDiameterMm,
          lengthM: effectiveSubMainLengthM,
          c: 150.0,
        ) *
        subMainF;

    final totalNetworkLossM = lateralLossM + mainLossM + subMainLossM;
    final requiredPumpHeadM = operatingHeadM + totalNetworkLossM;
    final networkLossPct = (totalNetworkLossM / operatingHeadM) * 100.0;
    final networkOk = lateralOk && (networkLossPct <= 30.0);

    return DripResult(
      plants: plants,
      totalEmitters: totalEmitters,
      totalFlowM3h: totalFlowM3h,
      sectorFlowM3h: sectorFlowM3h,
      litersPerPlantPerIrrigation: litersPerPlantPerIrrigation,
      runtimeHoursPerCycle: runtimeHoursPerCycle,
      lateralTotalLengthM: lateralTotalLengthM,
      maxSectors: maxSectors,
      sectorsOk: sectorsOk,
      lateralLossM: lateralLossM,
      allowedLateralLossM: allowedLateralLossM,
      endEmitterFlowPct: endEmitterFlowPct,
      lateralOk: lateralOk,
      mainLengthM: effectiveMainLengthM,
      subMainLengthM: effectiveSubMainLengthM,
      mainDiameterMm: effectiveMainDiameterMm,
      subMainDiameterMm: effectiveSubMainDiameterMm,
      mainLossM: mainLossM,
      subMainLossM: subMainLossM,
      totalNetworkLossM: totalNetworkLossM,
      requiredPumpHeadM: requiredPumpHeadM,
      networkLossPct: networkLossPct,
      networkOk: networkOk,
    );
  }

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
    required double infiltrationMmH,
  }) {
    if (areaM2 <= 0 ||
        sprinklerM3h <= 0 ||
        spacingAlongM <= 0 ||
        spacingAcrossM <= 0 ||
        etcMmDay <= 0 ||
        efficiency <= 0 ||
        efficiency > 1.0 ||
        intervalDays < 1.0 ||
        availableHours <= 0 ||
        sectors <= 0 ||
        infiltrationMmH <= 0) {
      return null;
    }

    final sprinklerAreaM2 = spacingAlongM * spacingAcrossM;
    final applicationRateMmH = (sprinklerM3h * 1000.0) / sprinklerAreaM2;
    final sprinklers = (areaM2 / sprinklerAreaM2).ceil();

    final grossPerIrrigationMm = (etcMmDay / efficiency) * intervalDays;
    final runtimeHoursPerSector = grossPerIrrigationMm / applicationRateMmH;

    final totalFlowM3h = sprinklers * sprinklerM3h;
    final sectorFlowM3h = totalFlowM3h / sectors;

    final infiltrationOk = applicationRateMmH <= infiltrationMmH;
    final sectorsOk = (runtimeHoursPerSector * sectors) <= availableHours;

    return SprinklerResult(
      applicationRateMmH: applicationRateMmH,
      sprinklers: sprinklers,
      runtimeHoursPerSector: runtimeHoursPerSector,
      totalFlowM3h: totalFlowM3h,
      sectorFlowM3h: sectorFlowM3h,
      infiltrationOk: infiltrationOk,
      sectorsOk: sectorsOk,
    );
  }

  static SurfaceResult? surface({
    required double areaM2,
    required double etcMmDay,
    required double efficiency,
    required double intervalDays,
    required double streamLps,
    required double availableHours,
  }) {
    if (areaM2 <= 0 ||
        etcMmDay <= 0 ||
        efficiency <= 0 ||
        efficiency > 1.0 ||
        intervalDays < 1.0 ||
        streamLps <= 0 ||
        availableHours <= 0) {
      return null;
    }

    final need = waterNeed(
      areaM2: areaM2,
      etcMmDay: etcMmDay,
      efficiency: efficiency,
      intervalDays: intervalDays,
    );
    if (need == null) return null;

    final streamM3h = streamLps * 3.6;
    final irrigationHours = need.perIrrigationVolumeM3 / streamM3h;

    return SurfaceResult(
      irrigationHours: irrigationHours,
      perIrrigationVolumeM3: need.perIrrigationVolumeM3,
      ok: irrigationHours <= availableHours,
    );
  }

  static PivotResult? pivot({
    required double radiusM,
    required double etcMmDay,
    required double efficiency,
    required double intervalDays,
    required double hoursPerRotation,
  }) {
    if (radiusM <= 0 ||
        etcMmDay <= 0 ||
        efficiency <= 0 ||
        efficiency > 1.0 ||
        intervalDays < 1.0 ||
        hoursPerRotation <= 0) {
      return null;
    }

    final areaM2 = pi * radiusM * radiusM;
    final need = waterNeed(
      areaM2: areaM2,
      etcMmDay: etcMmDay,
      efficiency: efficiency,
      intervalDays: intervalDays,
    );
    if (need == null) return null;

    final flowM3h = need.perIrrigationVolumeM3 / hoursPerRotation;
    final flowLps = flowM3h / 3.6;
    final endTowerSpeedMh = (2.0 * pi * radiusM) / hoursPerRotation;
    final fitsInterval = hoursPerRotation <= (intervalDays * 24.0);

    return PivotResult(
      areaM2: areaM2,
      flowM3h: flowM3h,
      flowLps: flowLps,
      endTowerSpeedMh: endTowerSpeedMh,
      grossPerApplicationMm: need.grossPerIrrigationMm,
      fitsInterval: fitsInterval,
    );
  }

  /// رفع القيمة لأقرب قدرة موتور قياسية متاحة (أو لأقرب 10 كيلوواط للقدرات الأكبر من 200)
  static double nextStandardMotorKw(double requiredKw) {
    if (requiredKw <= 0) return standardMotorKw.first;
    for (final s in standardMotorKw) {
      if (s >= requiredKw) return s;
    }
    return (requiredKw / 10.0).ceil() * 10.0;
  }

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
    if (flowM3h <= 0 ||
        staticLiftM < 0 ||
        operatingHeadM < 0 ||
        frictionLossM < 0 ||
        minorLossPct < 0 ||
        equipmentLossM < 0 ||
        pumpEfficiency <= 0 ||
        pumpEfficiency > 1.0 ||
        motorEfficiency <= 0 ||
        motorEfficiency > 1.0) {
      return null;
    }

    final minorLossM = frictionLossM * (minorLossPct / 100.0);
    final totalHeadM = staticLiftM +
        operatingHeadM +
        frictionLossM +
        minorLossM +
        equipmentLossM;

    final hydraulicKw = (flowM3h * totalHeadM) / 367.2;
    final shaftKw = hydraulicKw / pumpEfficiency;
    final motorInputKw = shaftKw / motorEfficiency;

    final recommendedMotorKw = shaftKw * 1.15;
    final stdMotorKw = nextStandardMotorKw(recommendedMotorKw);

    return PumpResult(
      totalHeadM: totalHeadM,
      hydraulicKw: hydraulicKw,
      shaftKw: shaftKw,
      motorInputKw: motorInputKw,
      recommendedMotorKw: recommendedMotorKw,
      standardMotorKw: stdMotorKw,
    );
  }
}
