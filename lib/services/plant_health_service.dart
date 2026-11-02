import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/my_farm_model.dart';

class PlantHealthService {
  PlantHealthService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String safeIrrigationAdvice =
      'لا توجد توصية ري موثقة لهذا التشخيص في التطبيق حتى الآن. حافظ على برنامج الري المحسوب للمحصول، وافحص رطوبة التربة والصرف، ولا ترفع أو تخفض كمية الري اعتمادًا على تصنيف الصورة وحده. راجع مهندسًا زراعيًا لتحديد الإجراء المناسب حسب مرحلة النمو ونظام الري.';

  static MyFarmProgram? findUniqueMatchingProgram({
    required List<MyFarmProgram> programs,
    required String className,
  }) {
    final cropCode = _normalize(className.split('__').first);
    final cropKey = _cropAliases.keys
        .firstWhere((key) => cropCode.startsWith(key), orElse: () => '');
    final aliases = _cropAliases[cropKey];
    if (aliases == null) return null;

    final matches = programs.where((program) {
      if (program.status != 'active') return false;
      final candidateTexts = <String>[
        program.templateName,
        program.sectionName,
        for (final entry in program.inputValues.entries)
          if (_isCropField(entry.key)) entry.value?.toString() ?? '',
      ];
      return candidateTexts.any((text) => _containsAlias(text, aliases));
    }).toList(growable: false);

    return matches.length == 1 ? matches.single : null;
  }

  static bool _isCropField(String key) {
    final normalized = _normalize(key);
    return normalized.contains('crop') ||
        normalized.contains('plant') ||
        normalized.contains('variety') ||
        normalized.contains('محصول') ||
        normalized.contains('نبات') ||
        normalized.contains('صنف');
  }

  static bool _containsAlias(String value, List<String> aliases) {
    final normalizedValue = _normalize(value);
    for (final alias in aliases) {
      final normalizedAlias = _normalize(alias);
      if (RegExp(r'^[a-z0-9 ]+$').hasMatch(normalizedAlias)) {
        final escaped = RegExp.escape(normalizedAlias).replaceAll(' ', r'\s+');
        final endAnchor = String.fromCharCode(36);
        final pattern = '(^|[^a-z0-9])' +
            escaped +
            '([^a-z0-9]|' +
            endAnchor +
            ')';
        if (RegExp(pattern).hasMatch(normalizedValue)) {
          return true;
        }
      } else if (normalizedValue.contains(normalizedAlias)) {
        return true;
      }
    }
    return false;
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF]+'), ' ')
      .trim();

  static const Map<String, List<String>> _cropAliases = {
    'apple': ['apple', 'تفاح'],
    'blueberry': ['blueberry', 'توت ازرق'],
    'cherry': ['cherry', 'كرز'],
    'corn': ['corn', 'maize', 'ذره', 'ذرة'],
    'grape': ['grape', 'عنب'],
    'orange': ['orange', 'برتقال'],
    'peach': ['peach', 'خوخ'],
    'pepper': ['pepper', 'فلفل'],
    'potato': ['potato', 'بطاطس', 'بطاطا'],
    'raspberry': ['raspberry', 'توت العليق'],
    'soybean': ['soybean', 'فول الصويا', 'صويا'],
    'squash': ['squash', 'قرع', 'كوسه'],
    'strawberry': ['strawberry', 'فراوله'],
    'tomato': ['tomato', 'طماطم', 'بندوره'],
  };

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
