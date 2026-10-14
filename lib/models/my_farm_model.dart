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
  });

  factory MyFarmProgram.fromFirestore(DocumentSnapshot doc) {
    final data = SafeParse.map(doc.data());
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
      tasks: SafeParse.mapList(data['tasks']),
      materials: SafeParse.mapList(data['materials']),
      financial: SafeParse.map(data['financial']),
      startDate: (data['start_date'] is Timestamp)
          ? (data['start_date'] as Timestamp).toDate()
          : DateTime.now(),
      createdAt: (data['created_at'] is Timestamp)
          ? (data['created_at'] as Timestamp).toDate()
          : DateTime.now(),
      status: SafeParse.string(data['status'], 'active'),
    );
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
      };

  // رقم اليوم للمهمة (يقبل int أو double أو نص)
  static int _day(Map<String, dynamic> t) =>
      SafeParse.integer(t['day_from_start']);

  // ✅ حساب عدد الأيام من البداية بالتقويم (مش بكل 24 ساعة)
  // بنقارن التواريخ فقط وبـ UTC عشان تغيير التوقيت الصيفي ما يبوّظش العدّ.
  int get daysSinceStart {
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    final start = DateTime.utc(startDate.year, startDate.month, startDate.day);
    return today.difference(start).inDays;
  }

  // ✅ المهمة القادمة
  Map<String, dynamic>? get nextTask {
    final sorted = List<Map<String, dynamic>>.from(tasks);
    sorted.sort((a, b) => _day(a).compareTo(_day(b)));
    final today = daysSinceStart;
    for (var task in sorted) {
      if (_day(task) >= today) return task;
    }
    return null;
  }

  // ✅ المهام المستحقة اليوم
  List<Map<String, dynamic>> get todayTasks {
    final today = daysSinceStart;
    return tasks.where((t) => _day(t) == today).toList();
  }

  // ✅ المهام المتأخرة (يوم 0 كمان لو عدّى)
  List<Map<String, dynamic>> get overdueTasks {
    final today = daysSinceStart;
    return tasks.where((t) {
      final day = _day(t);
      return day < today && day >= 0;
    }).toList();
  }

  // ✅ تقدم البرنامج (0-1)
  double get progress {
    if (tasks.isEmpty) return 0;
    final totalDays = tasks.map(_day).reduce((a, b) => a > b ? a : b);
    if (totalDays <= 0) return 1.0;
    return (daysSinceStart / totalDays).clamp(0.0, 1.0);
  }
}
