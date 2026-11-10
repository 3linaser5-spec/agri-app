import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/number_utils.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // تحويل رقم الموبايل إلى بريد إلكتروني اصطناعي (لأن هذا التدفق يستخدم
  // Email/Password). هذا لا يثبت ملكية الرقم؛ استخدم Phone Auth/OTP عند الحاجة.
  // الرقم بيتحوّل لأرقام إنجليزية الأول عشان نفس الرقم يطلع نفس الحساب
  // سواء اتكتب ٠١٠١٢٣٤٥٦٧٨ أو 01012345678
  String _phoneToEmail(String phone) => '$phone@agri-app.local';

  // دالة إنشاء حساب جديد
  Future<String?> register({
    required String name,
    required String phone,
    required String password,
  }) async {
    User? createdUser;
    try {
      final normalizedName = name.trim();
      final normalizedPhone = NumberUtils.normalizeEgyptianMobile(phone);
      if (normalizedPhone == null) {
        return 'رقم الموبايل غير صحيح (مثال: 01012345678)';
      }

      // 1. إنشاء المستخدم في نظام Firebase Auth
      final credential = await _auth.createUserWithEmailAndPassword(
        email: _phoneToEmail(normalizedPhone),
        password: password,
      );
      createdUser = credential.user;
      if (createdUser == null) {
        return 'تعذر إنشاء الحساب بهذه البيانات، حاول مرة أخرى.';
      }

      // ✅ 2. حفظ الاسم في حساب المستخدم نفسه عشان يفضل موجود بعد إعادة فتح التطبيق
      await createdUser.updateDisplayName(normalizedName);
      
      // ✅ 3. إعادة تحميل بيانات المستخدم عشان الاسم يتحدث فوراً
      await createdUser.reload();

      // ✅ 4. تخزين بيانات المستخدم الإضافية في Firestore
      await _db.collection('users').doc(createdUser.uid).set({
        'uid': createdUser.uid,
        'name': normalizedName,
        'phone': normalizedPhone,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      return null; // نجاح
    } on FirebaseAuthException catch (e) {
      if (createdUser != null) await _discardIncompleteUser(createdUser);
      // لا نكشف أن الرقم موجود مسبقاً؛ الرسالة الموحدة تقلل تعداد الأرقام.
      return _mapError(e.code, forRegistration: true);
    } catch (e) {
      if (createdUser != null) await _discardIncompleteUser(createdUser);
      return 'حدث خطأ غير متوقع، حاول مرة أخرى.';
    }
  }

  // دالة تسجيل الدخول
  Future<String?> login({
    required String phone,
    required String password,
  }) async {
    final canonicalPhone = NumberUtils.normalizeEgyptianMobile(phone);
    if (canonicalPhone == null) {
      return 'رقم الموبايل غير صحيح (مثال: 01012345678)';
    }

    User? signedInUser;
    try {
      UserCredential credential;
      try {
        credential = await _auth.signInWithEmailAndPassword(
          email: _phoneToEmail(canonicalPhone),
          password: password,
        );
      } on FirebaseAuthException catch (primaryError) {
        final legacyPhone = NumberUtils.legacyEgyptianMobile(phone);
        if (legacyPhone == null || legacyPhone == canonicalPhone ||
            !const {'invalid-credential', 'user-not-found', 'invalid-email'}
                .contains(primaryError.code)) {
          rethrow;
        }
        credential = await _auth.signInWithEmailAndPassword(
          email: _phoneToEmail(legacyPhone),
          password: password,
        );
      }
      signedInUser = credential.user;
      if (signedInUser != null) {
        await _ensureUserProfile(signedInUser, canonicalPhone);
      }
      return null; // نجاح
    } on FirebaseAuthException catch (e) {
      if (signedInUser != null) await _signOutIfCurrent(signedInUser);
      return _mapError(e.code);
    } catch (e) {
      if (signedInUser != null) await _signOutIfCurrent(signedInUser);
      return 'حدث خطأ غير متوقع، حاول مرة أخرى.';
    }
  }

  Future<void> _ensureUserProfile(User user, String phone) async {
    final profile = _db.collection('users').doc(user.uid);
    final snapshot = await profile.get();
    if (snapshot.exists) return;

    final displayName = user.displayName?.trim();
    await profile.set({
      'uid': user.uid,
      'name': displayName == null || displayName.isEmpty ? 'مستخدم' : displayName,
      'phone': phone,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _discardIncompleteUser(User user) async {
    DocumentSnapshot<Map<String, dynamic>> profile;
    try {
      profile = await _db.collection('users').doc(user.uid).get();
    } catch (_) {
      // Never delete an account if a transient read failure makes the profile
      // state ambiguous; leave it recoverable through the next login attempt.
      await _signOutIfCurrent(user);
      return;
    }
    if (profile.exists) return;
    try {
      await user.delete();
    } catch (_) {
      await _signOutIfCurrent(user);
    }
  }

  Future<void> _signOutIfCurrent(User user) async {
    if (_auth.currentUser?.uid != user.uid) return;
    try {
      await _auth.signOut();
    } catch (_) {
      // Preserve the original failure; the caller still receives a safe message.
    }
  }

  // دالة تسجيل الخروج
  Future<void> logout() => _auth.signOut();

  // دالة لجلب المستخدم الحالي
  User? get currentUser => _auth.currentUser;

  // دالة لتحويل أكواد الأخطاء إلى رسائل بالعربية
  static const _registrationFailure =
      'تعذر إنشاء الحساب بهذه البيانات، حاول مرة أخرى.';

  String _mapError(String code, {bool forRegistration = false}) {
    if (forRegistration &&
        (code == 'email-already-in-use' || code == 'invalid-email')) {
      return _registrationFailure;
    }

    switch (code) {
      case 'email-already-in-use':
        return _registrationFailure;
      case 'invalid-email':
        return 'صيغة رقم الموبايل غير صحيحة.';
      case 'weak-password':
        return 'كلمة المرور ضعيفة (6 أحرف على الأقل).';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'رقم الموبايل أو كلمة المرور غير صحيحة.';
      case 'too-many-requests':
        return 'محاولات كثيرة، حاول لاحقًا.';
      case 'network-request-failed':
        return 'تحقق من اتصالك بالإنترنت.';
      default:
        return 'حدث خطأ: $code';
    }
  }
}
