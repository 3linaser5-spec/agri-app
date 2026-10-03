class Validators {
  // التحقق من رقم موبايل مصري
  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'من فضلك أدخل رقم الموبايل';
    }
    final regex = RegExp(r'^01[0125][0-9]{8}$');
    if (!regex.hasMatch(value.trim())) {
      return 'رقم الموبايل غير صحيح (مثال: 01012345678)';
    }
    return null;
  }

  // التحقق من الاسم
  static String? name(String? value) {
    if (value == null || value.trim().length < 3) {
      return 'الاسم قصير جدًا (3 أحرف على الأقل)';
    }
    return null;
  }

  // التحقق من كلمة المرور
  static String? password(String? value) {
    if (value == null || value.length < 6) {
      return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(value) || !RegExp(r'[0-9]').hasMatch(value)) {
      return 'يجب أن تحتوي كلمة المرور على حروف وأرقام';
    }
    return null;
  }
}
