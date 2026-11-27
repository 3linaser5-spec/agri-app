import '../models/farm_workspace_models.dart';
import '../models/weather_forecast.dart';

/// القرار المقترح لمهمة ري بعد قراءة توقعات الطقس.
enum IrrigationAction { postpone, advance, keep }

/// تعديل مقترح على موعد مهمة ري واحدة.
class IrrigationAdjustment {
  final String taskId;
  final String taskTitle;
  final IrrigationAction action;
  final DateTime originalDueAt;
  final DateTime suggestedDueAt;
  final String headline;
  final String reason;
  final double waterSavingMm;
  final int severity; // 1 معلومة، 2 مهم، 3 عاجل

  const IrrigationAdjustment({
    required this.taskId,
    required this.taskTitle,
    required this.action,
    required this.originalDueAt,
    required this.suggestedDueAt,
    required this.headline,
    required this.reason,
    this.waterSavingMm = 0,
    this.severity = 1,
  });

  /// هل التعديل يحرّك التاريخ (وليس الوقت فقط)؟
  bool get changesDay =>
      originalDueAt.year != suggestedDueAt.year ||
      originalDueAt.month != suggestedDueAt.month ||
      originalDueAt.day != suggestedDueAt.day;

  /// صياغة قصيرة للعرض في البطاقة.
  String get actionLabel => switch (action) {
        IrrigationAction.postpone => 'تأجيل',
        IrrigationAction.advance => 'تقديم',
        IrrigationAction.keep => 'كما هو',
      };
}

/// محوّل توقعات الطقس إلى قرارات ري على مهام المستخدم.
///
/// الطبقة نقية بلا Flutter، وتبني فوق [FarmTask] و[WeatherSnapshot]:
/// - أمطار قادمة على موعد الري ← تأجيل لل يوم التالي لآخر يوم مطر.
/// - حرارة شديدة يوم الري ← تقديم الساعة للسادسة صباحًا لتفادي البخر.
/// - غير ذلك ← لا تغيير (حتى لا نزعج المستخدم بتنبيهات بلا قيمة).
class SmartIrrigationPlanner {
  const SmartIrrigationPlanner._();

  static const double rainMmThreshold = 4;
  static const int rainProbabilityThreshold = 55;
  static const double heatThresholdC = 38;
  static const int lookAheadDays = 4;
  static const int earlyHour = 6;

  static const List<String> _irrigationKeywords = [
    'ري',
    'سقي',
    'رش',
    'ماء',
    'مياه',
    'irrig',
    'water',
  ];

  /// هل المهمة متعلقة بالري؟ النوع صريح، أو عنوان/ملاحظات فيها كلمة ري.
  static bool isIrrigationTask(FarmTask task) {
    if (task.kind == TaskKind.irrigation) return true;
    final text = '${task.title} ${task.notes}'.toLowerCase();
    return _irrigationKeywords.any(text.contains);
  }

  static DateTime _dayStart(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static bool _isRainy(WeatherForecastDay day) =>
      day.precipitationMm >= rainMmThreshold ||
      (day.precipitationProbability ?? 0) >= rainProbabilityThreshold;

  /// قرار مهمة واحدة، أو `null` لو لا يوجد ما يستدعي التغيير.
  static IrrigationAdjustment? adjust(
    FarmTask task,
    WeatherSnapshot snapshot,
    DateTime now,
  ) {
    if (task.done || snapshot.days.isEmpty) return null;
    if (!isIrrigationTask(task)) return null;

    final today = _dayStart(now);
    final dueDay = _dayStart(task.dueAt);
    final horizon = today.add(const Duration(days: lookAheadDays));
    // المهام البعيدة جدًا لا تُعاد جدولتها الآن؛ نراجعها عند اقتراب موعدها.
    if (dueDay.isAfter(horizon)) return null;

    final window = snapshot.days
        .where((day) => !_dayStart(day.date).isBefore(today))
        .where((day) => !_dayStart(day.date).isAfter(horizon))
        .toList(growable: false);
    final rainyDays = window.where(_isRainy).toList(growable: false);

    if (rainyDays.isNotEmpty) {
      final lastRain = rainyDays
          .map((day) => _dayStart(day.date))
          .reduce((a, b) => a.isAfter(b) ? a : b);
      if (!dueDay.isAfter(lastRain)) {
        final suggested = DateTime(
          lastRain.year,
          lastRain.month,
          lastRain.day + 1,
          task.dueAt.hour,
          task.dueAt.minute,
        );
        final saving = rainyDays
            .where((day) => !_dayStart(day.date).isAfter(lastRain))
            .fold<double>(0, (sum, day) => sum + day.precipitationMm)
            .clamp(0, 60)
            .toDouble();
        final firstRain = rainyDays.first;
        return IrrigationAdjustment(
          taskId: task.id,
          taskTitle: task.title,
          action: IrrigationAction.postpone,
          originalDueAt: task.dueAt,
          suggestedDueAt: suggested,
          headline: 'أجّل الري — أمطار قادمة',
          reason:
              'متوقع ${firstRain.precipitationMm.toStringAsFixed(1)} مم مطر'
              '${firstRain.precipitationProbability == null ? '' : ' (احتمال ${firstRain.precipitationProbability}٪)'}'
              '. التأجيل حتى ${suggested.day}/${suggested.month} يوفّر '
              '${saving.toStringAsFixed(1)} مم من مياه الري ويقلل رطوبة التربة الزائدة.',
          waterSavingMm: saving,
          severity: 3,
        );
      }
    }

    // لا أمطار مؤثرة: هل موعد الري في يوم شديد الحرارة؟
    WeatherForecastDay? hotDay;
    for (final day in window) {
      if (_dayStart(day.date) != dueDay) continue;
      if (day.maximumTemperatureC >= heatThresholdC) hotDay = day;
    }
    if (hotDay != null && task.dueAt.hour > earlyHour) {
      final suggested = DateTime(
        dueDay.year,
        dueDay.month,
        dueDay.day,
        earlyHour,
        task.dueAt.minute,
      );
      return IrrigationAdjustment(
        taskId: task.id,
        taskTitle: task.title,
        action: IrrigationAction.advance,
        originalDueAt: task.dueAt,
        suggestedDueAt: suggested,
        headline: 'قدّم الري للصباح الباكر',
        reason:
            'العظمى ${hotDay.maximumTemperatureC.toStringAsFixed(0)}°م يوم الري. '
            'التقديم للساعة $earlyHour صباحًا يقلل البخر ويحمي الجذور، '
            'مع زيادة الماء 10-15٪.',
        severity: 2,
      );
    }

    return null;
  }

  /// كل التعديلات المفيدة لمجموعة مهام، مرتّبة بالأهمية ثم بالتاريخ.
  static List<IrrigationAdjustment> plan(
    Iterable<FarmTask> tasks,
    WeatherSnapshot snapshot,
    DateTime now,
  ) {
    final adjustments = <IrrigationAdjustment>[];
    for (final task in tasks) {
      final adjustment = adjust(task, snapshot, now);
      if (adjustment != null) adjustments.add(adjustment);
    }
    adjustments.sort((a, b) {
      final bySeverity = b.severity.compareTo(a.severity);
      if (bySeverity != 0) return bySeverity;
      return a.suggestedDueAt.compareTo(b.suggestedDueAt);
    });
    return List.unmodifiable(adjustments);
  }

  static double totalWaterSaving(Iterable<IrrigationAdjustment> adjustments) =>
      adjustments.fold<double>(0, (sum, item) => sum + item.waterSavingMm);

  /// أفضل تعديل واحد للعرض المختصر في أعلى الشاشة.
  static IrrigationAdjustment? topAdjustment(
    Iterable<IrrigationAdjustment> adjustments,
  ) {
    if (adjustments.isEmpty) return null;
    return adjustments.first;
  }
}
