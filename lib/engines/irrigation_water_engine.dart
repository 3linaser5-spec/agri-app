/// محرك مستقل لحساب الاحتياج المائي وزمن تشغيل شبكة الري.
///
/// جميع الأطوال والمساحات بوحدات SI، مع استخدام mm للمطر/الاحتياج، m²
/// للمساحة، m³ وL/min للتدفق والزمن بالدقائق.
library;

class IrrigationWaterResult {
  final double etcMmDay;
  final double adjustedEtcMmDay;
  final double netDailyMm;
  final double grossDailyMm;
  final double grossWeeklyMm;
  final double dailyVolumeM3;
  final double weeklyVolumeM3;
  final double dailyVolumeLitres;
  final double weeklyVolumeLitres;
  final double dailyRuntimeMinutes;
  final double weeklyRuntimeMinutes;

  const IrrigationWaterResult({
    required this.etcMmDay,
    required this.adjustedEtcMmDay,
    required this.netDailyMm,
    required this.grossDailyMm,
    required this.grossWeeklyMm,
    required this.dailyVolumeM3,
    required this.weeklyVolumeM3,
    required this.dailyVolumeLitres,
    required this.weeklyVolumeLitres,
    required this.dailyRuntimeMinutes,
    required this.weeklyRuntimeMinutes,
  });

  Map<String, double> toJson() => {
        'etc_mm_day': etcMmDay,
        'adjusted_etc_mm_day': adjustedEtcMmDay,
        'net_daily_mm': netDailyMm,
        'gross_daily_mm': grossDailyMm,
        'gross_weekly_mm': grossWeeklyMm,
        'daily_volume_m3': dailyVolumeM3,
        'weekly_volume_m3': weeklyVolumeM3,
        'daily_volume_litres': dailyVolumeLitres,
        'weekly_volume_litres': weeklyVolumeLitres,
        'daily_runtime_minutes': dailyRuntimeMinutes,
        'weekly_runtime_minutes': weeklyRuntimeMinutes,
      };
}

/// حسابات الاحتياج المائي دون اعتماد على Flutter أو نماذج التطبيق.
class IrrigationWaterEngine {
  IrrigationWaterEngine._();

  static const int daysPerWeek = 7;

  /// ETc = ETo × Kc.
  static double calculateEtc({required num etoMmDay, required num kc}) {
    final eto = _positive(etoMmDay, 'etoMmDay');
    final coefficient = _range(kc, 'kc', 0, 2.5);
    return eto * coefficient;
  }

  /// يحسب الاحتياج اليومي والأسبوعي وزمن التشغيل.
  ///
  /// معاملات الملوحة والجفاف معاملات نسبية بين 0 و1، حيث 1 يعني عدم
  /// خفض الاحتياج. الكفاءة بين (0, 1] وتمثل كفاءة التطبيق في الحقل.
  static IrrigationWaterResult calculate({
    required num etoMmDay,
    required num kc,
    required num areaM2,
    required num efficiency,
    num salinityFactor = 1,
    num droughtFactor = 1,
    required num flowRateLpm,
    int deviceCount = 1,
  }) {
    final eto = _positive(etoMmDay, 'etoMmDay');
    final coefficient = _range(kc, 'kc', 0, 2.5);
    final area = _positive(areaM2, 'areaM2');
    final applicationEfficiency = _range(efficiency, 'efficiency', 1e-12, 1);
    final salinity = _range(salinityFactor, 'salinityFactor', 0, 1);
    final drought = _range(droughtFactor, 'droughtFactor', 0, 1);
    final flow = _positive(flowRateLpm, 'flowRateLpm');
    if (deviceCount < 1) {
      throw ArgumentError.value(deviceCount, 'deviceCount', 'must be at least 1');
    }

    final etc = eto * coefficient;
    final adjusted = etc * salinity * drought;
    final grossDaily = adjusted / applicationEfficiency;
    final grossWeekly = grossDaily * daysPerWeek;
    // 1 mm over 1 m² = 1 litre; 1000 litres = 1 m³.
    final dailyLitres = grossDaily * area;
    final weeklyLitres = grossWeekly * area;
    final litresPerMinute = flow * deviceCount;

    return IrrigationWaterResult(
      etcMmDay: etc,
      adjustedEtcMmDay: adjusted,
      netDailyMm: adjusted,
      grossDailyMm: grossDaily,
      grossWeeklyMm: grossWeekly,
      dailyVolumeM3: dailyLitres / 1000,
      weeklyVolumeM3: weeklyLitres / 1000,
      dailyVolumeLitres: dailyLitres,
      weeklyVolumeLitres: weeklyLitres,
      dailyRuntimeMinutes: dailyLitres / litresPerMinute,
      weeklyRuntimeMinutes: weeklyLitres / litresPerMinute,
    );
  }

  /// اسم وصفي بديل مناسب للاستدعاءات التي تركز على المتطلبات.
  static IrrigationWaterResult calculateRequirement({
    required num etoMmDay,
    required num kc,
    required num areaM2,
    required num efficiency,
    num salinityFactor = 1,
    num droughtFactor = 1,
    required num flowRateLpm,
    int deviceCount = 1,
  }) => calculate(
        etoMmDay: etoMmDay,
        kc: kc,
        areaM2: areaM2,
        efficiency: efficiency,
        salinityFactor: salinityFactor,
        droughtFactor: droughtFactor,
        flowRateLpm: flowRateLpm,
        deviceCount: deviceCount,
      );

  static double _positive(num value, String field) {
    _finite(value, field);
    if (value <= 0) {
      throw ArgumentError.value(value, field, 'must be greater than zero');
    }
    return value.toDouble();
  }

  static double _range(num value, String field, double minimum, double maximum) {
    _finite(value, field);
    if (value < minimum || value > maximum) {
      throw ArgumentError.value(
        value,
        field,
        'must be between $minimum and $maximum',
      );
    }
    return value.toDouble();
  }

  static void _finite(num value, String field) {
    if (!value.toDouble().isFinite) {
      throw ArgumentError.value(value, field, 'must be finite');
    }
  }
}
