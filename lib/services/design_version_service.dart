import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/irrigation_design_models.dart';

/// خطأ في أرشيف نسخ التصميم.
class DesignVersionException implements Exception {
  final String message;
  const DesignVersionException(this.message);
  @override
  String toString() => message;
}

/// نسخة محفوظة من تصميم ري.
class SavedDesignVersion {
  final String documentId;
  final int number;
  final String label;
  final DateTime? createdAt;
  final IrrigationDesignProject project;

  const SavedDesignVersion({
    required this.documentId,
    required this.number,
    required this.label,
    required this.project,
    this.createdAt,
  });
}

/// أرشيف نسخ التصاميم المحفوظة، داخل
/// `irrigationDesignProjects/{projectId}/versions` — وهي المسارات التي تسمح
/// بها قواعد Firestore لمالك التصميم.
class DesignVersionService {
  DesignVersionService._();

  static CollectionReference<Map<String, dynamic>> _versions(String projectId) =>
      FirebaseFirestore.instance
          .collection('irrigationDesignProjects')
          .doc(projectId)
          .collection('versions');

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// رقم النسخة التالية: الأكبر + 1.
  static int nextNumber(Iterable<int> existing) {
    var max = 0;
    for (final value in existing) {
      if (value > max) max = value;
    }
    return max + 1;
  }

  /// حفظ نسخة جديدة (لقطة كاملة من التصميم).
  static Future<SavedDesignVersion> saveVersion({
    required String projectId,
    required IrrigationDesignProject project,
    String label = '',
  }) async {
    final uid = _uid;
    if (uid == null) {
      throw const DesignVersionException('سجّل الدخول أولاً لحفظ النسخة.');
    }
    try {
      final existing = await listVersions(projectId);
      final number = nextNumber(existing.map((item) => item.number));
      final reference = _versions(projectId).doc();
      final data = {
        'owner_id': uid,
        'number': number,
        'label': label.trim(),
        'project': project.toJson(),
        'created_at': FieldValue.serverTimestamp(),
      };
      await reference.set(data);
      return SavedDesignVersion(
        documentId: reference.id,
        number: number,
        label: label.trim(),
        createdAt: DateTime.now(),
        project: project,
      );
    } on FirebaseException catch (error) {
      throw DesignVersionException(
        error.code == 'permission-denied'
            ? 'لا تملك صلاحية حفظ نسخة من هذا التصميم.'
            : 'تعذر حفظ النسخة: ${error.message ?? error.code}',
      );
    }
  }

  /// كل النسخ، الأحدث أولًا.
  static Future<List<SavedDesignVersion>> listVersions(String projectId) async {
    try {
      final snapshot = await _versions(projectId).get();
      final versions = <SavedDesignVersion>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final raw = data['project'];
        if (raw is! Map) continue;
        try {
          versions.add(SavedDesignVersion(
            documentId: doc.id,
            number: (data['number'] as num?)?.toInt() ?? 0,
            label: data['label']?.toString() ?? '',
            createdAt: data['created_at'] is Timestamp
                ? (data['created_at'] as Timestamp).toDate()
                : DateTime.tryParse(data['created_at']?.toString() ?? ''),
            project: IrrigationDesignProject.fromJson(
              Map<String, dynamic>.from(raw),
            ),
          ));
        } catch (_) {
          // نسخة تالفة تتخطى بدل أن توقف الأرشيف.
        }
      }
      versions.sort((a, b) => b.number.compareTo(a.number));
      return List.unmodifiable(versions);
    } on FirebaseException catch (error) {
      throw DesignVersionException(
        error.code == 'permission-denied'
            ? 'لا تملك صلاحية قراءة نسخ هذا التصميم.'
            : 'تعذر تحميل النسخ: ${error.message ?? error.code}',
      );
    }
  }

  static Future<void> deleteVersion({
    required String projectId,
    required String versionId,
  }) async {
    try {
      await _versions(projectId).doc(versionId).delete();
    } on FirebaseException catch (error) {
      throw DesignVersionException(
        'تعذر حذف النسخة: ${error.message ?? error.code}',
      );
    }
  }
}
