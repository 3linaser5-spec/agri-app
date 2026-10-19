import 'number_utils.dart';

class Validators {
  // التحقق من رقم موبايل مصري
  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'من فضلك أدخل رقم الموبايل';
    }
    
    // 1. تحويل الأرقام العربية لإنجليزي وإزالة المسافات
    var normalized = NumberUtils.normalize(value).trim();
    
    // 2. توحيد كود الدولة (لو المستخدم كتب +20 أو 0020 أو 20)
    if (normalized.startsWith('+20')) {
      normalized = '0${normalized.substring(3)}';
    } else if (normalized.startsWith('0020')) {
      normalized = '0${normalized.substring(4)}';
    } else if (normalized.startsWith('20') && normalized.length == 12) {
      normalized = '0${normalized.substring(2)}';
    }

    // 3. التحقق (بيبدأ بـ 010 أو 011 أو 012 أو 015)
    final regex = RegExp(r'^01[0125][0-9]{8}$');
    if (!regex.hasMatch(normalized)) {
      return 'رقم الموبايل غير صحيح (مثال: 01012345678)';
    }
    return null;
  }

  // التحقق من الاسم
  static String? name(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return 'من فضلك أدخل الاسم';
    }
    if (normalized.length < 3) {
      return 'الاسم قصير جدًا (3 أحرف على الأقل)';
    }
    if (normalized.length > 100) {
      return 'الاسم طويل جدًا (100 حرف كحد أقصى)';
    }
    // منع الأرقام في الاسم (اختياري حسب متطلبات التطبيق)
    if (RegExp(r'[0-9٠-٩]').hasMatch(normalized)) {
      return 'الاسم لا يجب أن يحتوي على أرقام';
    }
    return null;
  }

  // التحقق من كلمة المرور
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'من فضلك أدخل كلمة المرور';
    }
    if (value.length < 8) { // تحسين: 8 أحرف أفضل أمنياً
      return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(value)) {
      return 'يجب أن تحتوي كلمة المرور على حروف على الأقل';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'يجب أن تحتوي كلمة المرور على أرقام على الأقل';
    }
    // تحسين: يفضل لو فيها رمز خاص كمان (اختياري)
    // if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
    //   return 'يفضل استخدام رمز خاص (!@#$) لتقوية كلمة المرور';
    // }
    return null;
  }
}
