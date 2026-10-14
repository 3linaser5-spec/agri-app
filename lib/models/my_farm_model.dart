import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/safe_parse.dart';

class MyFarmProgram {
  final String id;
  final String userId;
  final String templateId;
  final String templateName;
  final String templateEmoji;
  final String sectionId;
  final String sectionName;
  final String governorate;
  final String climateZone;
  final Map<String, dynamic> inputValues;
  final List<Map<String, dynamic>> tasks;
  final List<Map<String, dynamic>> materials;
  final Map<String, dynamic> financial;
  final DateTime startDate;
  final DateTime createdAt;
  final String status; // 'active' | 'completed'
  // فهارس المهام المنجزة (الفهرس = مكان المهمة في قائمة tasks الأصلية).
  // بنخزّن الفهرس لأن قائمة المهام ما بتتغيرش بعد حفظ البرنامج.
  final List<int> doneTasks;

  MyFarmProgram({
    required this.id,
    required this.userId,
    required this.templateId,
    required this.templateName,
    required this.templateEmoji,
    required this.sectionId,
    required this.sectionName,
    required this.governorate,
    required this.climateZone,
    required this.inputValues,
    required this.tasks,
    required this.materials,
    required this.financial,
    required this.startDate,
    required this.createdAt,
    this.status = 'active',
    this.doneTasks = const [],
  });

  factory MyFarmProgram.fromFirestore(DocumentSnapshot doc) {
    final data = SafeParse.map(doc.data());
    final tasks = SafeParse.mapList(data['tasks']);
    return MyFarmProgram(
      id: doc.id,
      userId: SafeParse.string(data['user_id']),
      templateId: SafeParse.string(data['template_id']),
      templateName: SafeParse.string(data['template_name']),
      templateEmoji: SafeParse.string(data['template_emoji'], '🌱'),
      sectionId: SafeParse.string(data['section_id']),
      sectionName: SafeParse.string(data['section_name']),
      governorate: SafeParse.string(data['governorate']),
      climateZone: SafeParse.string(data['climate_zone']),
      inputValues: SafeParse.map(data['input_values']),
      tasks: tasks,
      materials: SafeParse.mapList(data['materials']),
      financial: SafeParse.map(data['financial']),
      startDate: (data['start_date'] is Timestamp)
          ? (data['start_date'] as Timestamp).toDate()
          : DateTime.now(),
      createdAt: (data['created_at'] is Timestamp)
          ? (data['created_at'] as Timestamp).toDate()
          : DateTime.now(),
      status: SafeParse.string(data['status'], 'active'),
      doneTasks: _parseDoneTasks(data['done_tasks'], tasks.length),
    );
  }

  // فهارس صحيحة فقط (داخل نطاق المهام وبدون تكرار) حتى لو الحقل بنوع غلط
  static List<int> _parseDoneTasks(dynamic raw, int tasksCount) {
    if (raw is! List) return const [];
    final result = <int>{};
    for (final e in raw) {
      final i = SafeParse.integer(e, -1);
      if (i >= 0 && i < tasksCount) result.add(i);
    }
    return result.toList()..sort();
  }

  Map<String, dynamic> toFirestore() => {
        'user_id': userId,
        'template_id': templateId,
        'template_name': templateName,
        'template_emoji': templateEmoji,
        'section_id': sectionId,
        'section_name': sectionName,
        'governorate': governorate,
        'climate_zone': climateZone,
        'input_values': inputValues,
        'tasks': tasks,
        'materials': materials,
        'financial': financial,
        'start_date': Timestamp.fromDate(startDate),
        'created_at': FieldValue.serverTimestamp(),
        'status': status,
        'done_tasks': doneTasks,
      };

  // رقم اليوم للمهمة (يقبل int أو double أو نص)
  static int _day(Map<String, dynamic> t) =>
      SafeParse.integer(t['day_from_start']);

  // ✅ نسخة جديدة بنفس البيانات لكن بقائمة منجزات مختلفة (للتحديث المتفائل في الواجهة)
  MyFarmProgram copyWithDoneTasks(Iterable<int> done) {
    final unique = <int>{
      for (final i in done)
        if (i >= 0 && i < tasks.length) i
    };
    final list = unique.toList()..sort();
    return MyFarmProgram(
      id: id,
      userId: userId,
      templateId: templateId,
      templateName: templateName,
      templateEmoji: templateEmoji,
      sectionId: sectionId,
      sectionName: sectionName,
      governorate: governorate,
      climateZone: climateZone,
      inputValues: inputValues,
      tasks: tasks,
      materials: materials,
      financial: financial,
      startDate: startDate,
      createdAt: createdAt,
      status: (tasks.isNotEmpty && list.length == tasks.length)
          ? 'completed'
          : 'active',
      doneTasks: list,
    );
  }

  // ✅ حساب عدد الأيام من البداية بالتقويم (مش بكل 24 ساعة)
  // بنقارن التواريخ فقط وبـ UTC عشان تغيير التوقيت الصيفي ما يبوّظش العدّ.
  int get daysSinceStart {
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    final start = DateTime.utc(startDate.year, startDate.month, startDate.day);
    return today.difference(start).inDays;
  }

  // ✅ المهام: الإنجاز
  bool isTaskDone(int index) => doneTasks.contains(index);

  int get doneCount => doneTasks.length;

  /// البرنامج مكتمل لما كل المهام تتعلّم (محسوبة من البيانات مش من حقل status
  /// عشان تفضل صح حتى لو status اتأخر تحديثه).
  bool get isCompleted => tasks.isNotEmpty && doneCount >= tasks.length;

  // فهارس المهام غير المنجزة مرتبة بالأيام
  List<int> get _pendingIndexesByDay {
    final pending = [
      for (var i = 0; i < tasks.length; i++)
        if (!isTaskDone(i)) i
    ];
    pending.sort((a, b) => _day(tasks[a]).compareTo(_day(tasks[b])));
    return pending;
  }

  // ✅ المهمة القادمة: أقرب مهمة غير منجزة موعدها اليوم أو بعده
  Map<String, dynamic>? get nextTask {
    final today = daysSinceStart;
    for (final i in _pendingIndexesByDay) {
      if (_day(tasks[i]) >= today) return tasks[i];
    }
    return null;
  }

  // ✅ المهام المستحقة اليوم (غير المنجزة)
  List<Map<String, dynamic>> get todayTasks {
    final today = daysSinceStart;
    return [
      for (final i in _pendingIndexesByDay)
        if (_day(tasks[i]) == today) tasks[i]
    ];
  }

  // ✅ المهام المتأخرة: فات موعدها ولسه ما اتعلّمتش منجزة
  List<Map<String, dynamic>> get overdueTasks {
    final today = daysSinceStart;
    return [
      for (final i in _pendingIndexesByDay)
        if (_day(tasks[i]) < today) tasks[i]
    ];
  }

  // ✅ تقدم البرنامج (0-1) = المهام المنجزة فعلًا ÷ كل المهام
  double get progress {
    if (tasks.isEmpty) return 0;
    return (doneCount / tasks.length).clamp(0.0, 1.0);
  }

  // التقدم الزمني (الأيام اللي عدّت من آخر مهمة) - للمقارنة مع التقدم الفعلي
  double get timeProgress {
    if (tasks.isEmpty) return 0;
    final totalDays = tasks.map(_day).reduce((a, b) => a > b ? a : b);
    if (totalDays <= 0) return 1.0;
    return (daysSinceStart / totalDays).clamp(0.0, 1.0);
  }
}
