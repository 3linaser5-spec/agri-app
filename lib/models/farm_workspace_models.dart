/// نماذج مساحة عمل المزرعة: المواقع والقطع، المهام والتذكيرات، سجل المحاصيل
/// ومصاريفها.
///
/// لا تعتمد هذه الطبقة على Flutter أو Firebase، والتواريخ تُخزَّن كنصوص
/// ISO-8601 حتى يمكن استخدام نفس النموذج في Firestore والتخزين المحلي
/// (العمل بدون إنترنت) والاختبارات.
library;

/// نوع مهمة المزرعة؛ يحدد كيف تتعامل التوصيات الذكية معها (الري مثلًا
/// يتأجل تلقائيًا عند توقع أمطار، والرش يتجنب الحرارة العالية).
enum TaskKind {
  general('عامة'),
  irrigation('ري'),
  fertilizing('تسميد'),
  spraying('رش'),
  harvest('حصاد');

  const TaskKind(this.label);
  final String label;

  static TaskKind fromName(Object? value) {
    final name = value?.toString() ?? '';
    for (final kind in TaskKind.values) {
      if (kind.name == name) return kind;
    }
    return TaskKind.general;
  }
}

/// تكرار مهمة المزرعة.
enum TaskRepeat {
  none('مرة واحدة'),
  daily('يوميًا'),
  weekly('أسبوعيًا'),
  biweekly('كل أسبوعين'),
  monthly('شهريًا');

  const TaskRepeat(this.label);
  final String label;

  static TaskRepeat fromName(Object? value) {
    final name = value?.toString() ?? '';
    for (final repeat in TaskRepeat.values) {
      if (repeat.name == name) return repeat;
    }
    return TaskRepeat.none;
  }
}

DateTime? _parseDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

String _asText(Object? value, [String fallback = '']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

double _asDouble(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  final parsed = double.tryParse(value?.toString() ?? '');
  return parsed ?? fallback;
}

/// موقع/مزرعة رئيسية (يمكن للمستخدم امتلاك أكثر من مزرعة).
class FarmSite {
  final String id;
  final String ownerId;
  final String name;
  final String governorate;
  final String notes;
  final DateTime createdAt;

  const FarmSite({
    required this.id,
    required this.ownerId,
    required this.name,
    this.governorate = '',
    this.notes = '',
    required this.createdAt,
  });

  factory FarmSite.fromMap(String id, Map<String, dynamic> data) => FarmSite(
        id: id,
        ownerId: _asText(data['owner_id']),
        name: _asText(data['name'], 'مزرعة بدون اسم'),
        governorate: _asText(data['governorate']),
        notes: _asText(data['notes']),
        createdAt: _parseDate(data['created_at']) ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'owner_id': ownerId,
        'name': name,
        'governorate': governorate,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };
}

/// قطعة أرض داخل موقع، ولها محصولها ومساحتها.
class FarmPlot {
  final String id;
  final String ownerId;
  final String siteId;
  final String name;
  final String crop;
  final double areaFeddan;
  final String irrigationMethod;
  final DateTime createdAt;

  const FarmPlot({
    required this.id,
    required this.ownerId,
    required this.siteId,
    required this.name,
    this.crop = '',
    this.areaFeddan = 0,
    this.irrigationMethod = '',
    required this.createdAt,
  });

  factory FarmPlot.fromMap(String id, Map<String, dynamic> data) => FarmPlot(
        id: id,
        ownerId: _asText(data['owner_id']),
        siteId: _asText(data['site_id']),
        name: _asText(data['name'], 'قطعة بدون اسم'),
        crop: _asText(data['crop']),
        areaFeddan: _asDouble(data['area_feddan']),
        irrigationMethod: _asText(data['irrigation_method']),
        createdAt: _parseDate(data['created_at']) ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'owner_id': ownerId,
        'site_id': siteId,
        'name': name,
        'crop': crop,
        'area_feddan': areaFeddan,
        'irrigation_method': irrigationMethod,
        'created_at': createdAt.toIso8601String(),
      };
}

/// مهمة مزرعة مع تذكير وإمكانية تكرار.
class FarmTask {
  final String id;
  final String ownerId;
  final String? plotId;
  final String? siteId;
  final String title;
  final String notes;
  final DateTime dueAt;
  final TaskRepeat repeat;
  final TaskKind kind;
  final bool done;
  final bool reminderEnabled;
  final DateTime? lastCompletedAt;

  /// من أُنشئت له المهمة (عامل/مشرف). فارغ للمهام الشخصية.
  final String? assignedToUid;
  final String? assignedToName;
  final String? assignedByUid;

  /// كل من يحق له رؤية المهمة وتحديثها؛ تشمل المالك والمسنَد إليه.
  final List<String> memberUids;

  const FarmTask({
    required this.id,
    required this.ownerId,
    this.plotId,
    this.siteId,
    required this.title,
    this.notes = '',
    required this.dueAt,
    this.repeat = TaskRepeat.none,
    this.kind = TaskKind.general,
    this.done = false,
    this.reminderEnabled = true,
    this.lastCompletedAt,
    this.assignedToUid,
    this.assignedToName,
    this.assignedByUid,
    this.memberUids = const [],
  });

  factory FarmTask.fromMap(String id, Map<String, dynamic> data) {
    final rawMembers = data['member_uids'];
    return FarmTask(
      id: id,
      ownerId: _asText(data['owner_id']),
      plotId: _asText(data['plot_id']).isEmpty ? null : _asText(data['plot_id']),
      siteId: _asText(data['site_id']).isEmpty ? null : _asText(data['site_id']),
      title: _asText(data['title'], 'مهمة'),
      notes: _asText(data['notes']),
      dueAt: _parseDate(data['due_at']) ?? DateTime.now(),
      repeat: TaskRepeat.fromName(data['repeat']),
      kind: TaskKind.fromName(data['kind']),
      done: data['done'] == true,
      reminderEnabled: data['reminder_enabled'] != false,
      lastCompletedAt: _parseDate(data['last_completed_at']),
      assignedToUid: _asText(data['assigned_to_uid']).isEmpty
          ? null
          : _asText(data['assigned_to_uid']),
      assignedToName: _asText(data['assigned_to_name']).isEmpty
          ? null
          : _asText(data['assigned_to_name']),
      assignedByUid: _asText(data['assigned_by_uid']).isEmpty
          ? null
          : _asText(data['assigned_by_uid']),
      memberUids: rawMembers is List
          ? rawMembers
              .map((value) => value.toString().trim())
              .where((value) => value.isNotEmpty)
              .toList(growable: false)
          : const [],
    );
  }

  Map<String, dynamic> toMap() => {
        'owner_id': ownerId,
        'plot_id': plotId,
        'site_id': siteId,
        'title': title,
        'notes': notes,
        'due_at': dueAt.toIso8601String(),
        'repeat': repeat.name,
        'kind': kind.name,
        'done': done,
        'reminder_enabled': reminderEnabled,
        'last_completed_at': lastCompletedAt?.toIso8601String(),
        'assigned_to_uid': assignedToUid,
        'assigned_to_name': assignedToName,
        'assigned_by_uid': assignedByUid,
        'member_uids': memberUids,
      };

  FarmTask copyWith({
    String? plotId,
    String? siteId,
    String? title,
    String? notes,
    DateTime? dueAt,
    TaskRepeat? repeat,
    TaskKind? kind,
    bool? done,
    bool? reminderEnabled,
    DateTime? lastCompletedAt,
    String? assignedToUid,
    String? assignedToName,
    String? assignedByUid,
    List<String>? memberUids,
  }) =>
      FarmTask(
        id: id,
        ownerId: ownerId,
        plotId: plotId ?? this.plotId,
        siteId: siteId ?? this.siteId,
        title: title ?? this.title,
        notes: notes ?? this.notes,
        dueAt: dueAt ?? this.dueAt,
        repeat: repeat ?? this.repeat,
        kind: kind ?? this.kind,
        done: done ?? this.done,
        reminderEnabled: reminderEnabled ?? this.reminderEnabled,
        lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
        assignedToUid: assignedToUid ?? this.assignedToUid,
        assignedToName: assignedToName ?? this.assignedToName,
        assignedByUid: assignedByUid ?? this.assignedByUid,
        memberUids: memberUids ?? this.memberUids,
      );

  /// هل المهمة مسنَدة إلى [uid]؟
  bool isAssignedTo(String? uid) =>
      uid != null && uid.isNotEmpty && assignedToUid == uid;

  /// اسم من تُنفذه المهمة، أو «لي» للمهام الشخصية.
  String get assigneeLabel =>
      (assignedToName == null || assignedToName!.trim().isEmpty)
          ? 'مهمة شخصية'
          : assignedToName!.trim();

  bool isOverdue(DateTime now) =>
      !done && dueAt.isBefore(DateTime(now.year, now.month, now.day));

  bool isDueToday(DateTime now) =>
      dueAt.year == now.year && dueAt.month == now.month && dueAt.day == now.day;

  /// الموعد التالي لمهمة متكررة بعد إنجازها، أو `null` للمهام التي لا تتكرر.
  DateTime? nextOccurrenceAfter(DateTime reference) {
    if (repeat == TaskRepeat.none) return null;
    final base = DateTime(
      reference.year,
      reference.month,
      reference.day,
      dueAt.hour,
      dueAt.minute,
    );
    switch (repeat) {
      case TaskRepeat.daily:
        return base.add(const Duration(days: 1));
      case TaskRepeat.weekly:
        return base.add(const Duration(days: 7));
      case TaskRepeat.biweekly:
        return base.add(const Duration(days: 14));
      case TaskRepeat.monthly:
        final month = base.month + 1;
        final year = base.year + (month > 12 ? 1 : 0);
        final normalizedMonth = month > 12 ? month - 12 : month;
        final lastDay = DateTime(year, normalizedMonth + 1, 0).day;
        return DateTime(
          year,
          normalizedMonth,
          base.day > lastDay ? lastDay : base.day,
          base.hour,
          base.minute,
        );
      case TaskRepeat.none:
        return null;
    }
  }

  /// المهام القادمة المتوقعة خلال [days] يومًا (بما فيها المهمة نفسها إن كانت
  /// غير منجزة)، وتُستخدم لعرض «مهام الأسبوع».
  List<DateTime> upcomingOccurrences(DateTime now, {int days = 7}) {
    final limit = DateTime(now.year, now.month, now.day).add(Duration(days: days));
    final result = <DateTime>[];
    final dayStart = DateTime(now.year, now.month, now.day);
    var cursor =
        DateTime(dueAt.year, dueAt.month, dueAt.day, dueAt.hour, dueAt.minute);
    if (cursor.isBefore(dayStart)) {
      // المهام المتأخرة تُعرض في قائمة المتأخرات، وهنا نبدأ من أول موعد قادم.
      var guard = 0;
      while (cursor.isBefore(dayStart) && guard++ < 400) {
        final next = nextOccurrenceAfter(cursor);
        if (next == null) return const [];
        cursor = next;
      }
    }
    var guard = 0;
    while (!cursor.isAfter(limit) && guard++ < 400) {
      result.add(cursor);
      final next = nextOccurrenceAfter(cursor);
      if (next == null) break;
      cursor = next;
    }
    return result;
  }
}

/// بند مصروف داخل موسم محصول.
class CropExpense {
  final String label;
  final double amount;
  final DateTime date;

  const CropExpense({
    required this.label,
    required this.amount,
    required this.date,
  });

  factory CropExpense.fromMap(Map<String, dynamic> data) => CropExpense(
        label: _asText(data['label'], 'مصروف'),
        amount: _asDouble(data['amount']),
        date: _parseDate(data['date']) ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'label': label,
        'amount': amount,
        'date': date.toIso8601String(),
      };
}

/// موسم محصول على قطعة أرض: من الزراعة للحصاد، بالإنتاج والتكاليف والإيراد.
class CropSeason {
  final String id;
  final String ownerId;
  final String? plotId;
  final String crop;
  final String variety;
  final double areaFeddan;
  final DateTime plantingDate;
  final DateTime? harvestDate;
  final double expectedYieldKg;
  final double? actualYieldKg;
  final double pricePerKg;
  final List<CropExpense> expenses;
  final String notes;

  const CropSeason({
    required this.id,
    required this.ownerId,
    this.plotId,
    required this.crop,
    this.variety = '',
    this.areaFeddan = 1,
    required this.plantingDate,
    this.harvestDate,
    this.expectedYieldKg = 0,
    this.actualYieldKg,
    this.pricePerKg = 0,
    this.expenses = const [],
    this.notes = '',
  });

  factory CropSeason.fromMap(String id, Map<String, dynamic> data) {
    final rawExpenses = data['expenses'];
    return CropSeason(
      id: id,
      ownerId: _asText(data['owner_id']),
      plotId: _asText(data['plot_id']).isEmpty ? null : _asText(data['plot_id']),
      crop: _asText(data['crop'], 'محصول'),
      variety: _asText(data['variety']),
      areaFeddan: _asDouble(data['area_feddan'], 1),
      plantingDate: _parseDate(data['planting_date']) ?? DateTime.now(),
      harvestDate: _parseDate(data['harvest_date']),
      expectedYieldKg: _asDouble(data['expected_yield_kg']),
      actualYieldKg: data['actual_yield_kg'] == null
          ? null
          : _asDouble(data['actual_yield_kg']),
      pricePerKg: _asDouble(data['price_per_kg']),
      expenses: rawExpenses is List
          ? rawExpenses
              .whereType<Map>()
              .map((e) => CropExpense.fromMap(Map<String, dynamic>.from(e)))
              .toList(growable: false)
          : const [],
      notes: _asText(data['notes']),
    );
  }

  Map<String, dynamic> toMap() => {
        'owner_id': ownerId,
        'plot_id': plotId,
        'crop': crop,
        'variety': variety,
        'area_feddan': areaFeddan,
        'planting_date': plantingDate.toIso8601String(),
        'harvest_date': harvestDate?.toIso8601String(),
        'expected_yield_kg': expectedYieldKg,
        'actual_yield_kg': actualYieldKg,
        'price_per_kg': pricePerKg,
        'expenses': expenses.map((e) => e.toMap()).toList(growable: false),
        'notes': notes,
      };

  CropSeason copyWith({
    String? crop,
    String? variety,
    double? areaFeddan,
    DateTime? harvestDate,
    double? expectedYieldKg,
    double? actualYieldKg,
    double? pricePerKg,
    List<CropExpense>? expenses,
    String? notes,
  }) =>
      CropSeason(
        id: id,
        ownerId: ownerId,
        plotId: plotId,
        crop: crop ?? this.crop,
        variety: variety ?? this.variety,
        areaFeddan: areaFeddan ?? this.areaFeddan,
        plantingDate: plantingDate,
        harvestDate: harvestDate ?? this.harvestDate,
        expectedYieldKg: expectedYieldKg ?? this.expectedYieldKg,
        actualYieldKg: actualYieldKg ?? this.actualYieldKg,
        pricePerKg: pricePerKg ?? this.pricePerKg,
        expenses: expenses ?? this.expenses,
        notes: notes ?? this.notes,
      );

  /// الإنتاج المعتمد في الحسابات: الفعلي إن سُجّل، وإلا المتوقع.
  double get effectiveYieldKg => actualYieldKg ?? expectedYieldKg;

  double get totalExpenses =>
      expenses.fold<double>(0, (sum, expense) => sum + expense.amount);

  double get revenue => effectiveYieldKg * pricePerKg;

  double get netProfit => revenue - totalExpenses;

  double get safeAreaFeddan => areaFeddan > 0 ? areaFeddan : 0;

  /// المحصول بالكيلو لكل فدان.
  double get yieldPerFeddan =>
      safeAreaFeddan == 0 ? 0 : effectiveYieldKg / safeAreaFeddan;

  double get profitPerFeddan =>
      safeAreaFeddan == 0 ? 0 : netProfit / safeAreaFeddan;

  /// هامش الربح كنسبة من الإيراد (0-1)، وصفر لو لا يوجد إيراد بعد.
  double get marginRatio {
    if (revenue <= 0) return 0;
    return (netProfit / revenue).clamp(-1.0, 1.0);
  }

  /// عدد الأيام من الزراعة حتى الحصاد (أو اليوم الحالي للموسم الجاري).
  int daysInSeason(DateTime now) {
    final end = harvestDate ?? now;
    return end.difference(plantingDate).inDays.clamp(0, 100000);
  }

  /// إجمالي تكلفة الفدان.
  double get costPerFeddan =>
      safeAreaFeddan == 0 ? 0 : totalExpenses / safeAreaFeddan;
}

/// ملخص أرباح مجموعة مواسم.
class CropProfitSummary {
  final int seasons;
  final double areaFeddan;
  final double revenue;
  final double expenses;
  final double yieldKg;

  const CropProfitSummary({
    this.seasons = 0,
    this.areaFeddan = 0,
    this.revenue = 0,
    this.expenses = 0,
    this.yieldKg = 0,
  });

  double get netProfit => revenue - expenses;

  double get profitPerFeddan =>
      areaFeddan == 0 ? 0 : netProfit / areaFeddan;

  double get marginRatio => revenue <= 0 ? 0 : netProfit / revenue;

  factory CropProfitSummary.fromSeasons(Iterable<CropSeason> seasons) {
    var count = 0;
    var area = 0.0;
    var revenue = 0.0;
    var expenses = 0.0;
    var yieldKg = 0.0;
    for (final season in seasons) {
      count++;
      area += season.safeAreaFeddan;
      revenue += season.revenue;
      expenses += season.totalExpenses;
      yieldKg += season.effectiveYieldKg;
    }
    return CropProfitSummary(
      seasons: count,
      areaFeddan: area,
      revenue: revenue,
      expenses: expenses,
      yieldKg: yieldKg,
    );
  }
}
