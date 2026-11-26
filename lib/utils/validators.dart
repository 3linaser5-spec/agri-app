import 'number_utils.dart';

class Validators {
  // التحقق من رقم موبايل مصري
  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'من فضلك أدخل رقم الموبايل';
    }
    
    // توحيد الأرقام العربية وصيغ الاتصال الدولي إلى 01xxxxxxxxx.
    if (NumberUtils.normalizeEgyptianMobile(value) == null) {
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

  // سياسة كلمة المرور عند إنشاء حساب جديد.
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'من فضلك أدخل كلمة المرور';
    }
    if (value.trim() != value) {
      return 'كلمة المرور لا تبدأ أو تنتهي بمسافة';
    }
    if (value.length < 10) {
      return 'كلمة المرور يجب أن تكون 10 أحرف على الأقل';
    }
    if (value.length > 128) {
      return 'كلمة المرور طويلة جدًا (128 حرف كحد أقصى)';
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(value)) {
      return 'يجب أن تحتوي كلمة المرور على حروف على الأقل';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'يجب أن تحتوي كلمة المرور على أرقام على الأقل';
    }
    if (value.split('').toSet().length < 4) {
      return 'كلمة المرور ضعيفة، استخدم مزيجًا متنوعًا من الحروف والأرقام';
    }
    if (_commonPasswords.contains(value.toLowerCase())) {
      return 'كلمة المرور شائعة جدًا، اختر كلمة أقوى';
    }
    return null;
  }

  // عند تسجيل الدخول لا نفرض السياسة الجديدة على حسابات قديمة.
  static String? loginPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'من فضلك أدخل كلمة المرور';
    }
    if (value.length < 6) {
      return 'كلمة المرور قصيرة جدًا';
    }
    return null;
  }

  static const Set<String> _commonPasswords = {
    'password', 'password1', 'password123', '123456', '1234567', '12345678',
    '123456789', '1234567890', 'qwerty', 'qwerty123', '111111', '000000',
    'iloveyou', 'admin', 'admin123', 'welcome', 'welcome1', 'abc123',
    'letmein', 'monkey', 'dragon', 'football', 'egypt123', 'agri1234',
  };
}
