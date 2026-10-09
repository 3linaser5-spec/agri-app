import 'package:cloud_firestore/cloud_firestore.dart';

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
    final data = doc.data() as Map<String, dynamic>;
    return MyFarmProgram(
      id: doc.id,
      userId: data['user_id'] ?? '',
      templateId: data['template_id'] ?? '',
      templateName: data['template_name'] ?? '',
      templateEmoji: data['template_emoji'] ?? '🌱',
      sectionId: data['section_id'] ?? '',
      sectionName: data['section_name'] ?? '',
      governorate: data['governorate'] ?? '',
      climateZone: data['climate_zone'] ?? '',
      inputValues: Map<String, dynamic>.from(data['input_values'] ?? {}),
      tasks: (data['tasks'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      materials: (data['materials'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      financial: Map<String, dynamic>.from(data['financial'] ?? {}),
      startDate: (data['start_date'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      status: data['status'] ?? 'active',
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

  // ✅ حساب عدد الأيام من البداية
  int get daysSinceStart =>
      DateTime.now().difference(startDate).inDays;

  // ✅ المهمة القادمة
  Map<String, dynamic>? get nextTask {
    final sorted = List<Map<String, dynamic>>.from(tasks);
    sorted.sort((a, b) =>
        (a['day_from_start'] ?? 0).compareTo(b['day_from_start'] ?? 0));
    for (var task in sorted) {
      final day = task['day_from_start'] as int? ?? 0;
      if (day >= daysSinceStart) return task;
    }
    return null;
  }

  // ✅ المهام المستحقة اليوم
  List<Map<String, dynamic>> get todayTasks {
    return tasks.where((t) {
      final day = t['day_from_start'] as int? ?? 0;
      return day == daysSinceStart;
    }).toList();
  }

  // ✅ المهام المتأخرة
  List<Map<String, dynamic>> get overdueTasks {
    return tasks.where((t) {
      final day = t['day_from_start'] as int? ?? 0;
      return day < daysSinceStart && day > 0;
    }).toList();
  }

  // ✅ تقدم البرنامج (0-1)
  double get progress {
    if (tasks.isEmpty) return 0;
    final totalDays = tasks
        .map((t) => t['day_from_start'] as int? ?? 0)
        .reduce((a, b) => a > b ? a : b);
    if (totalDays <= 0) return 1.0;
    return (daysSinceStart / totalDays).clamp(0.0, 1.0);
  }
}
