import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PlantHealthService {
  PlantHealthService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String safeIrrigationAdvice =
      'لا توجد توصية ري موثقة لهذا التشخيص في التطبيق حتى الآن. حافظ على برنامج الري المحسوب للمحصول، وافحص رطوبة التربة والصرف، ولا ترفع أو تخفض كمية الري اعتمادًا على تصنيف الصورة وحده. راجع مهندسًا زراعيًا لتحديد الإجراء المناسب حسب مرحلة النمو ونظام الري.';

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchProgramCases(
    String programId,
  ) {
    return _firestore
        .collection('my_farm')
        .doc(programId)
        .collection('plant_health_cases')
        .orderBy('created_at', descending: true)
        .limit(50)
        .snapshots();
  }

  static Future<String> saveDiagnosisToProgram({
    required String programId,
    required String farmCrop,
    required String predictedCrop,
    required String disease,
    required String className,
    required double confidence,
    required String modelVersion,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const PlantHealthException('سجّل الدخول أولاً لحفظ التشخيص في مزرعتك.');
    }
    if (programId.trim().isEmpty ||
        farmCrop.trim().isEmpty ||
        predictedCrop.trim().isEmpty ||
        disease.trim().isEmpty ||
        className.trim().isEmpty ||
        !confidence.isFinite ||
        confidence < 0 ||
        confidence > 1) {
      throw const PlantHealthException('بيانات التشخيص أو برنامج المزرعة غير مكتملة.');
    }

    final programRef = _firestore.collection('my_farm').doc(programId);
    final programSnapshot = await programRef.get(
      const GetOptions(source: Source.server),
    );
    final programData = programSnapshot.data();
    if (!programSnapshot.exists || programData?['user_id'] != user.uid) {
      throw const PlantHealthException(
        'تعذر التحقق من ملكية برنامج المزرعة. حدّث بيانات مزرعتي وحاول مرة أخرى.',
      );
    }

    final document = programRef.collection('plant_health_cases').doc();
    await document.set({
      'user_id': user.uid,
      'farm_crop': farmCrop.trim(),
      'predicted_crop': predictedCrop.trim(),
      'disease': disease.trim(),
      'class_name': className.trim(),
      'confidence': confidence,
      'model_version': modelVersion.trim(),
      'irrigation_action': 'monitor_and_review',
      'irrigation_advice_ar': safeIrrigationAdvice,
      'review_required': true,
      'status': 'needs_agronomist_review',
      'created_at': FieldValue.serverTimestamp(),
    });
    return document.id;
  }
}

class PlantHealthException implements Exception {
  const PlantHealthException(this.message);

  final String message;

  @override
  String toString() => message;
}
