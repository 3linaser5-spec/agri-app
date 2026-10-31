import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';

class PlantDiseaseService {
  PlantDiseaseService._();

  static final PlantDiseaseService instance = PlantDiseaseService._();
  static const int _maxImageBytes = 5 * 1024 * 1024;
  static const String _region = 'europe-west1';

  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: _region);

  Future<PlantDiseaseResult> classify({required File image}) async {
    if (!await image.exists()) {
      throw const PlantDiseaseException('ملف الصورة غير موجود. اختر الصورة مرة أخرى.');
    }

    final length = await image.length();
    if (length <= 0 || length > _maxImageBytes) {
      throw const PlantDiseaseException('حجم الصورة يجب أن يكون أقل من 5 ميجابايت.');
    }

    final mimeType = _mimeType(image.path);
    final bytes = await image.readAsBytes();
    final callable = _functions.httpsCallable(
      'classifyPlantDisease',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 65)),
    );

    try {
      final result = await callable.call(<String, Object>{
        'mimeType': mimeType,
        'imageBase64': base64Encode(bytes),
      });
      if (result.data is! Map) {
        throw const PlantDiseaseException('وصل رد غير صالح من خدمة التشخيص.');
      }

      final data = Map<String, dynamic>.from(result.data as Map);
      final rawPredictions = data['predictions'];
      if (rawPredictions is! List || rawPredictions.isEmpty) {
        throw const PlantDiseaseException('لم ينتج المصنف احتمالات قابلة للعرض.');
      }

      final predictions = rawPredictions.map((dynamic item) {
        if (item is! Map) {
          throw const PlantDiseaseException('تنسيق نتيجة المصنف غير صالح.');
        }
        final prediction = Map<String, dynamic>.from(item);
        final confidenceValue = prediction['confidence'];
        final confidence = confidenceValue is num ? confidenceValue.toDouble() : -1.0;
        final className = prediction['className']?.toString().trim() ?? '';
        final nameAr = prediction['nameAr']?.toString().trim() ?? '';
        final cropAr = prediction['cropAr']?.toString().trim() ?? '';
        if (className.isEmpty || nameAr.isEmpty || cropAr.isEmpty ||
            confidence < 0 || confidence > 1) {
          throw const PlantDiseaseException('بيانات إحدى النتائج غير صالحة.');
        }
        return PlantDiseasePrediction(
          className: className,
          nameAr: nameAr,
          cropAr: cropAr,
          confidence: confidence,
        );
      }).toList(growable: false);

      final treatmentValue = data['treatment'];
      final treatment = treatmentValue is Map
          ? PlantTreatmentInfo.fromMap(Map<String, dynamic>.from(treatmentValue))
          : null;

      return PlantDiseaseResult(
        modelVersion: data['modelVersion']?.toString() ?? 'unknown',
        predictions: predictions,
        treatment: treatment,
        disclaimer: data['disclaimer']?.toString() ??
            'هذه احتمالات أولية وليست تشخيصًا مؤكدًا أو وصفة علاجية.',
      );
    } on FirebaseFunctionsException catch (error) {
      throw PlantDiseaseException(_friendlyMessage(error.code));
    } on PlantDiseaseException {
      rethrow;
    } catch (_) {
      throw const PlantDiseaseException(
        'تعذر الاتصال بخدمة تشخيص النباتات. تحقق من الإنترنت ثم حاول مجددًا.',
      );
    }
  }

  String _mimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    throw const PlantDiseaseException(
      'صيغة الصورة غير مدعومة. استخدم JPG أو PNG أو WebP.',
    );
  }

  String _friendlyMessage(String code) {
    switch (code) {
      case 'unauthenticated':
        return 'سجّل الدخول أولاً لاستخدام تشخيص الصور.';
      case 'failed-precondition':
      case 'permission-denied':
        return 'تعذر التحقق من سلامة التطبيق. حدّث التطبيق أو أعد المحاولة.';
      case 'resource-exhausted':
        return 'وصلت إلى حد التشخيص اليومي. حاول مرة أخرى غدًا.';
      case 'invalid-argument':
        return 'الصورة غير صالحة أو أكبر من الحد المسموح. استخدم JPG أو PNG أو WebP.';
      case 'deadline-exceeded':
      case 'unavailable':
        return 'خدمة التشخيص لا تستجيب الآن. حاول مرة أخرى بعد قليل.';
      default:
        return 'تعذر تحليل الصورة الآن. حاول مرة أخرى لاحقًا.';
    }
  }
}

class PlantDiseaseResult {
  const PlantDiseaseResult({
    required this.modelVersion,
    required this.predictions,
    required this.treatment,
    required this.disclaimer,
  });

  final String modelVersion;
  final List<PlantDiseasePrediction> predictions;
  final PlantTreatmentInfo? treatment;
  final String disclaimer;
}

class PlantDiseasePrediction {
  const PlantDiseasePrediction({
    required this.className,
    required this.nameAr,
    required this.cropAr,
    required this.confidence,
  });

  final String className;
  final String nameAr;
  final String cropAr;
  final double confidence;
}

class PlantTreatmentInfo {
  const PlantTreatmentInfo({
    required this.matched,
    required this.recordId,
    required this.cropAr,
    required this.diseaseAr,
    required this.symptomsAr,
    required this.controlTimingAr,
    required this.noticeAr,
    required this.source,
    required this.section,
    required this.sourceStatus,
    required this.sourceVerificationNoteAr,
    required this.approvedPesticides,
  });

  final bool matched;
  final String? recordId;
  final String? cropAr;
  final String? diseaseAr;
  final String? symptomsAr;
  final String? controlTimingAr;
  final String? noticeAr;
  final String? source;
  final String? section;
  final String? sourceStatus;
  final String? sourceVerificationNoteAr;
  final List<Map<String, dynamic>> approvedPesticides;

  factory PlantTreatmentInfo.fromMap(Map<String, dynamic> map) {
    final rawProducts = map['approvedPesticides'];
    final products = rawProducts is List
        ? rawProducts
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false)
        : const <Map<String, dynamic>>[];
    return PlantTreatmentInfo(
      matched: map['matched'] == true,
      recordId: _optionalText(map['recordId']),
      cropAr: _optionalText(map['cropAr']),
      diseaseAr: _optionalText(map['diseaseAr']),
      symptomsAr: _optionalText(map['symptomsAr']),
      controlTimingAr: _optionalText(map['controlTimingAr']),
      noticeAr: _optionalText(map['noticeAr']),
      source: _optionalText(map['source']),
      section: _optionalText(map['section']),
      sourceStatus: _optionalText(map['sourceStatus']),
      sourceVerificationNoteAr: _optionalText(map['sourceVerificationNoteAr']),
      approvedPesticides: products,
    );
  }

  static String? _optionalText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}

class PlantDiseaseException implements Exception {
  const PlantDiseaseException(this.message);

  final String message;

  @override
  String toString() => message;
}
