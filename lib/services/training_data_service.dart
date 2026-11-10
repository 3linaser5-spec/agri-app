import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

class TrainingDataException implements Exception {
  final String message;
  const TrainingDataException(this.message);

  @override
  String toString() => message;
}

/// يحفظ صور الحقل المصنفة من الأدمن ضمن مجموعة بيانات التدريب.
/// هذه الخدمة تجمع العينات فقط ولا تعيد تدريب أوزان النموذج.
class TrainingDataService {
  TrainingDataService._();

  static const int maxImageBytes = 10 * 1024 * 1024;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static Future<bool> currentUserIsAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final adminDocument = await _firestore
        .collection('admins')
        .doc(user.uid)
        .get(const GetOptions(source: Source.server));
    return adminDocument.exists;
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchRecentSamples() {
    return _firestore
        .collection('plant_training_samples')
        .orderBy('uploadedAt', descending: true)
        .limit(30)
        .snapshots();
  }

  static Future<String> uploadLabeledImage({
    required File image,
    required String crop,
    required String disease,
    required void Function(int transferred, int total)? onProgress,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const TrainingDataException('سجّل الدخول بحساب الأدمن أولاً.');
    }

    final cleanCrop = crop.trim();
    final cleanDisease = disease.trim();
    if (cleanCrop.isEmpty || cleanDisease.isEmpty) {
      throw const TrainingDataException('اكتب اسم المحصول والمرض.');
    }
    if (cleanCrop.length > 80 || cleanDisease.length > 80) {
      throw const TrainingDataException('اسم المحصول أو المرض أطول من الحد المسموح.');
    }
    if (!await image.exists()) {
      throw const TrainingDataException('ملف الصورة لم يعد متاحاً على الجهاز. اختره مرة أخرى.');
    }

    final sizeBytes = await image.length();
    if (sizeBytes <= 0 || sizeBytes > maxImageBytes) {
      throw const TrainingDataException('حجم الصورة يجب أن يكون أقل من 10 ميجابايت.');
    }

    final extension = path.extension(image.path).toLowerCase();
    final String contentType;
    if (extension == '.jpg' || extension == '.jpeg') {
      contentType = 'image/jpeg';
    } else if (extension == '.png') {
      contentType = 'image/png';
    } else if (extension == '.webp') {
      contentType = 'image/webp';
    } else {
      throw const TrainingDataException('الصيغ المسموحة: JPG أو PNG أو WebP.');
    }

    final sampleDocument = _firestore.collection('plant_training_samples').doc();
    final storagePath =
        'plant_training/${user.uid}/${sampleDocument.id}$extension';
    final storageReference = _storage.ref().child(storagePath);
    final uploadTask = storageReference.putFile(
      image,
      SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'sampleId': sampleDocument.id,
          'uploadedByUid': user.uid,
        },
      ),
    );

    final progressSubscription = uploadTask.snapshotEvents.listen(
      (snapshot) => onProgress?.call(snapshot.bytesTransferred, snapshot.totalBytes),
      onError: (Object _) {},
    );

    try {
      await uploadTask;
      await sampleDocument.set({
        'crop': cleanCrop,
        'disease': cleanDisease,
        'className': '${cleanCrop}__${cleanDisease}',
        'storagePath': storagePath,
        'mimeType': contentType,
        'sizeBytes': sizeBytes,
        'uploadedByUid': user.uid,
        'uploadedAt': FieldValue.serverTimestamp(),
        'status': 'pending_training',
        'labelConfirmedByAgronomist': true,
        'source': 'admin_training_portal',
      });
      return sampleDocument.id;
    } on FirebaseException {
      try {
        await storageReference.delete();
      } catch (_) {
        // نحتفظ بخطأ الرفع الأصلي؛ حذف الملف اليتيم محاولة احترازية فقط.
      }
      rethrow;
    } catch (_) {
      try {
        await storageReference.delete();
      } catch (_) {
        // نحتفظ بالخطأ الأصلي؛ حذف الملف اليتيم محاولة احترازية فقط.
      }
      rethrow;
    } finally {
      await progressSubscription.cancel();
    }
  }
}
