import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/irrigation_design_models.dart';

/// يُرمى عندما يتعذر حفظ أو تحميل تصميم ري.
class IrrigationProjectException implements Exception {
  final String message;
  const IrrigationProjectException(this.message);

  @override
  String toString() => message;
}

/// تصميم محفوظ في حساب المستخدم.
class SavedIrrigationProject {
  final String documentId;
  final String name;
  final DateTime? updatedAt;
  final IrrigationDesignProject project;

  const SavedIrrigationProject({
    required this.documentId,
    required this.name,
    required this.project,
    this.updatedAt,
  });
}

/// حفظ وتحميل تصاميم الري في `irrigationDesignProjects`، وهي المجموعة التي
/// تسمح بها قواعد Firestore لصاحب المستند (`owner_id`). قبل كده كان المصمم
/// يبدأ بمشروع تجريبي ويعيد بناء كل شيء عند فتح الشاشة من جديد.
class IrrigationProjectService {
  IrrigationProjectService._();

  static const String collectionName = 'irrigationDesignProjects';

  static CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance.collection(collectionName);

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// محتوى المستند بدون الطوابع الزمنية (دالة نقية قابلة للاختبار).
  static Map<String, dynamic> toDocument({
    required String ownerId,
    required IrrigationDesignProject project,
  }) =>
      {
        'owner_id': ownerId,
        'name_ar': project.nameAr,
        'name_en': project.nameEn,
        'project': project.toJson(),
      };

  /// قراءة تصميم من مستند محفوظ (دالة نقية قابلة للاختبار).
  static SavedIrrigationProject fromDocument(
    String documentId,
    Map<String, dynamic> data,
  ) {
    final raw = data['project'];
    if (raw is! Map) {
      throw const IrrigationProjectException('بيانات التصميم غير صالحة.');
    }
    final project =
        IrrigationDesignProject.fromJson(Map<String, dynamic>.from(raw));
    final storedName = data['name_ar']?.toString().trim() ?? '';
    final updatedAt = data['updated_at'];
    return SavedIrrigationProject(
      documentId: documentId,
      name: storedName.isEmpty ? project.nameAr : storedName,
      updatedAt: updatedAt is Timestamp ? updatedAt.toDate() : null,
      project: project,
    );
  }

  /// حفظ التصميم؛ عند تمرير [documentId] يتم تحديث نفس المستند بدل إنشاء نسخ.
  static Future<String> save(
    IrrigationDesignProject project, {
    String? documentId,
  }) async {
    final uid = _uid;
    if (uid == null) {
      throw const IrrigationProjectException('سجّل الدخول أولاً لحفظ التصميم.');
    }
    try {
      final data = toDocument(ownerId: uid, project: project)
        ..['updated_at'] = FieldValue.serverTimestamp();
      if (documentId != null) {
        await _collection.doc(documentId).set(data, SetOptions(merge: true));
        return documentId;
      }
      final reference = _collection.doc();
      await reference.set({
        ...data,
        'created_at': FieldValue.serverTimestamp(),
      });
      return reference.id;
    } on FirebaseException catch (e) {
      throw IrrigationProjectException(
        e.code == 'permission-denied'
            ? 'لا تملك صلاحية حفظ هذا التصميم.'
            : 'تعذر حفظ التصميم: ${e.message ?? e.code}',
      );
    }
  }

  /// تصاميم المستخدم الحالي، الأحدث أولاً (الترتيب هنا لأن ترتيب الاستعلام
  /// مع فلتر المالك يحتاج فهرسًا مركبًا في Firestore).
  static Future<List<SavedIrrigationProject>> list() async {
    final uid = _uid;
    if (uid == null) return const [];
    try {
      final snapshot =
          await _collection.where('owner_id', isEqualTo: uid).get();
      final items = <SavedIrrigationProject>[];
      for (final doc in snapshot.docs) {
        try {
          items.add(fromDocument(doc.id, doc.data()));
        } on IrrigationProjectException {
          // تصميم تالف يتخطى بدل ما يوقف القائمة كلها.
        }
      }
      final epoch = DateTime.fromMillisecondsSinceEpoch(0);
      items.sort((a, b) => (b.updatedAt ?? epoch).compareTo(a.updatedAt ?? epoch));
      return List.unmodifiable(items);
    } on FirebaseException catch (e) {
      throw IrrigationProjectException(
        e.code == 'permission-denied'
            ? 'لا تملك صلاحية قراءة التصاميم المحفوظة.'
            : 'تعذر تحميل تصاميمك: ${e.message ?? e.code}',
      );
    }
  }

  /// حذف تصميم محفوظ.
  static Future<void> delete(String documentId) async {
    try {
      await _collection.doc(documentId).delete();
    } on FirebaseException catch (e) {
      throw IrrigationProjectException('تعذر حذف التصميم: ${e.message ?? e.code}');
    }
  }
}
