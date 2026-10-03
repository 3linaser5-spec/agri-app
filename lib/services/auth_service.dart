import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // تحويل رقم الموبايل إلى بريد إلكتروني وهمي (لأن Firebase Auth يحتاج بريدًا)
  String _phoneToEmail(String phone) => '${phone.trim()}@agri-app.local';

  // دالة إنشاء حساب جديد
  Future<String?> register({
    required String name,
    required String phone,
    required String password,
  }) async {
    try {
      // 1. إنشاء المستخدم في نظام Firebase Auth
      final credential = await _auth.createUserWithEmailAndPassword(
        email: _phoneToEmail(phone),
        password: password,
      );

      // ✅ 2. حفظ الاسم في حساب المستخدم نفسه عشان يفضل موجود بعد إعادة فتح التطبيق
      await credential.user!.updateDisplayName(name);
      
      // ✅ 3. إعادة تحميل بيانات المستخدم عشان الاسم يتحدث فوراً
      await credential.user!.reload();

      // ✅ 4. تخزين بيانات المستخدم الإضافية في Firestore
      await _db.collection('users').doc(credential.user!.uid).set({
        'uid': credential.user!.uid,
        'name': name,
        'phone': phone,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      return null; // نجاح
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code); // تحويل الخطأ إلى رسالة عربية
    } catch (e) {
      return 'حدث خطأ غير متوقع، حاول مرة أخرى.';
    }
  }

  // دالة تسجيل الدخول
  Future<String?> login({
    required String phone,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: _phoneToEmail(phone),
        password: password,
      );
      return null; // نجاح
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    }
  }

  // دالة تسجيل الخروج
  Future<void> logout() => _auth.signOut();

  // دالة لجلب المستخدم الحالي
  User? get currentUser => _auth.currentUser;

  // دالة لتحويل أكواد الأخطاء إلى رسائل بالعربية
  String _mapError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'رقم الموبايل مسجّل بالفعل.';
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
