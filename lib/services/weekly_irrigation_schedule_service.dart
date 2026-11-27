import '../models/weather_forecast.dart';
import '../models/weekly_irrigation_schedule_model.dart';
import 'irrigation_planner_service.dart';

/// يبني جدول ري أسبوعي مقترح من توقعات الطقس (ET0 والمطر) مع قرار واضح لكل يوم.
///
/// الأرقام إرشادية ومبنية على معاملات FAO-56 النموذجية؛ لا تغني عن قياس رطوبة
/// التربة في الحقل، ولا تحدد توقيت الري الفعلي.
class WeeklyIrrigationScheduleService {
  WeeklyIrrigationScheduleService._();

  /// كفاءة أنظمة الري الشائعة (٪).
  static const Map<String, double> methodEfficiency = {
    'تنقيط': 90,
    'رش': 75,
    'محوري': 85,
    'سطحي': 60,
    'غمر': 55,
  };

  /// مساحة الفدان بالمتر المربع.
  static const double squareMetersPerFeddan = 4200;

  static double efficiencyFor(String method) {
    final normalized = _normalize(method);
    for (final entry in methodEfficiency.entries) {
      if (normalized.contains(_normalize(entry.key))) return entry.value;
    }
    return 75;
  }

  static WeeklyIrrigationSchedule build({
    required List<WeatherForecastDay> forecast,
    required double areaM2,
    required IrrigationCropProfile crop,
    required IrrigationGrowthStage stage,
    required double efficiencyPercent,
    double effectiveRainFraction = 0.7,
    double? pumpFlowM3PerHour,
  }) {
    final estimates = IrrigationPlannerService.estimateWeek(
      forecast: forecast,
      areaM2: areaM2,
      kc: crop.kcFor(stage),
      efficiencyPercent: efficiencyPercent,
      effectiveRainFraction: effectiveRainFraction,
    );

    final rainProbability = <String, int>{};
    for (final day in forecast) {
      rainProbability[_dateKey(day.date)] = day.precipitationProbability ?? 0;
    }

    final days = <WeeklyIrrigationDay>[];
    for (final estimate in estimates) {
      final probability = rainProbability[_dateKey(estimate.date)] ?? 0;
      final decision = _decisionFor(estimate, probability);
      final minutes = pumpFlowM3PerHour != null && pumpFlowM3PerHour > 0
          ? ((estimate.volumeM3 / pumpFlowM3PerHour) * 60).round()
          : null;
      days.add(WeeklyIrrigationDay(
        date: estimate.date,
        et0Mm: estimate.et0Mm,
        rainMm: estimate.rainMm,
        cropEtMm: estimate.cropEtMm,
        netNeedMm: estimate.netNeedMm,
        grossNeedMm: estimate.grossNeedMm,
        volumeM3: estimate.volumeM3,
        decision: decision.$1,
        reason: decision.$2,
        minutes: minutes,
      ));
    }

    return WeeklyIrrigationSchedule(
      days: days,
      cropName: crop.name,
      methodName: _methodLabel(efficiencyPercent),
      stageLabel: stage.label,
      areaM2: areaM2,
      kc: crop.kcFor(stage),
      efficiencyPercent: efficiencyPercent,
      pumpFlowM3PerHour: pumpFlowM3PerHour,
    );
  }

  static (IrrigationDayDecision, String) _decisionFor(
    IrrigationDayEstimate estimate,
    int rainProbability,
  ) {
    if (estimate.netNeedMm <= 0.5) {
      return (
        IrrigationDayDecision.skip,
        estimate.rainMm >= 1
            ? 'المطر المتوقع يغطي احتياج المحصول'
            : 'الاحتياج ضعيف جدًا في هذا اليوم',
      );
    }
    if (rainProbability >= 60 && estimate.rainMm >= 3) {
      return (
        IrrigationDayDecision.reduce,
        'احتمال مطر $rainProbability٪ — الأفضل تأجيل الري',
      );
    }
    if (estimate.grossNeedMm < 2) {
      return (
        IrrigationDayDecision.reduce,
        'احتياج بسيط، ريّة خفيفة تكفي',
      );
    }
    return (
      IrrigationDayDecision.irrigate,
      'احتياج صافي ${estimate.netNeedMm.toStringAsFixed(1)} مم',
    );
  }

  static String _methodLabel(double efficiencyPercent) {
    for (final entry in methodEfficiency.entries) {
      if (entry.value == efficiencyPercent) return entry.key;
    }
    return 'ري بكفاءة ${efficiencyPercent.toStringAsFixed(0)}٪';
  }

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
      .replaceAll(RegExp(r'[\u0623\u0625\u0622\u0671]'), 'ا')
      .replaceAll('ى', 'ي')
      .trim();
}
