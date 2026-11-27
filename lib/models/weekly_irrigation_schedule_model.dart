/// نتيجة الجدول الأسبوعي المقترح للري: قرار لكل يوم مع الكميات.
///
/// الحساب يعتمد على معادلة FAO-56 المبسطة: ETc = Kc × ET0، ثم خصم المطر الفعّال،
/// ثم القسمة على كفاءة نظام الري للحصول على الكمية الإجمالية المطلوبة.
library;

/// قرار الري المقترح ليوم واحد.
enum IrrigationDayDecision { irrigate, reduce, skip }

extension IrrigationDayDecisionLabel on IrrigationDayDecision {
  String get label => switch (this) {
        IrrigationDayDecision.irrigate => 'اسقِ',
        IrrigationDayDecision.reduce => 'قلّل أو أجّل',
        IrrigationDayDecision.skip => 'لا تحتاج ري',
      };
}

/// احتياج يوم واحد داخل الجدول الأسبوعي.
class WeeklyIrrigationDay {
  const WeeklyIrrigationDay({
    required this.date,
    required this.et0Mm,
    required this.rainMm,
    required this.cropEtMm,
    required this.netNeedMm,
    required this.grossNeedMm,
    required this.volumeM3,
    required this.decision,
    required this.reason,
    this.minutes,
  });

  final DateTime date;
  final double et0Mm;
  final double rainMm;
  final double cropEtMm;
  final double netNeedMm;
  final double grossNeedMm;
  final double volumeM3;
  final IrrigationDayDecision decision;
  final String reason;

  /// مدة الري بالدقائق، وتكون null لو معدل تصريف المضخة غير محدد.
  final int? minutes;

  String get dayName {
    const names = [
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    return names[date.weekday - 1];
  }

  String get dateLabel => '${date.day}/${date.month}';
}

/// الجدول الأسبوعي كامل مع ملخص الأسبوع.
class WeeklyIrrigationSchedule {
  const WeeklyIrrigationSchedule({
    required this.days,
    required this.cropName,
    required this.methodName,
    required this.stageLabel,
    required this.areaM2,
    required this.kc,
    required this.efficiencyPercent,
    this.pumpFlowM3PerHour,
  });

  final List<WeeklyIrrigationDay> days;
  final String cropName;
  final String methodName;
  final String stageLabel;
  final double areaM2;
  final double kc;
  final double efficiencyPercent;
  final double? pumpFlowM3PerHour;

  bool get isEmpty => days.isEmpty;

  double get totalVolumeM3 => days.fold(0.0, (sum, day) => sum + day.volumeM3);

  double get totalGrossMm => days.fold(0.0, (sum, day) => sum + day.grossNeedMm);

  double get totalRainMm => days.fold(0.0, (sum, day) => sum + day.rainMm);

  int get irrigationDays =>
      days.where((day) => day.decision != IrrigationDayDecision.skip).length;

  int? get totalMinutes {
    if (days.every((day) => day.minutes == null)) return null;
    return days.fold(0, (sum, day) => sum + (day.minutes ?? 0));
  }
}
