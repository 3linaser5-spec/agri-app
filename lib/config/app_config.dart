/// إعدادات ثابتة للتطبيق في مكان واحد.
///
/// أرقام التواصل لا تُكتب داخل الكود حتى لا تظهر في المستودع العام.
/// تُمرَّر وقت البناء عبر --dart-define، مثلاً:
///   flutter build apk --dart-define=ENGINEER_PHONE=2010xxxxxxx
///                     --dart-define=ENGINEER_PHONE_LOCAL=010xxxxxxx
///
/// الـ workflow بيقراها من GitHub Secrets (ENGINEER_PHONE و ENGINEER_PHONE_LOCAL).
/// راجع SECURITY.md. لو السر مش موجود، أزرار التواصل بتختفي من الواجهة.
class AppConfig {
  AppConfig._(); // منع إنشاء كائن من الكلاس

  /// رقم واتساب المهندس (صيغة دولية بدون + أو مسافات). فارغ لو مش مضبوط.
  static const String engineerPhone = String.fromEnvironment('ENGINEER_PHONE');

  /// نفس الرقم بالصيغة المحلية للعرض (في ملفات PDF).
  static const String engineerPhoneLocal =
      String.fromEnvironment('ENGINEER_PHONE_LOCAL');

  /// هل رقم التواصل مضبوط في نسخة البناء الحالية؟
  static bool get hasEngineerPhone => engineerPhone.trim().isNotEmpty;

  /// الرقم المعروض للمستخدم: المحلي لو موجود وإلا الدولي، وإلا نص فارغ.
  static String get engineerPhoneDisplay {
    if (engineerPhoneLocal.trim().isNotEmpty) return engineerPhoneLocal.trim();
    return engineerPhone.trim();
  }

  /// سطر التواصل في تذييل PDF، ويختفي بالكامل لو الرقم غير مضبوط.
  static String get pdfContactLine =>
      engineerPhoneDisplay.isEmpty ? '' : ' | للتواصل: $engineerPhoneDisplay';

  /// رابط واتساب آمن، أو null لو الرقم غير مضبوط في نسخة البناء.
  static String? get whatsappUrl {
    final safePhone = engineerPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (safePhone.isEmpty) return null;
    return 'https://wa.me/$safePhone';
  }
}
