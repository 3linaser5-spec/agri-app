/// إعدادات ثابتة للتطبيق في مكان واحد.
///
/// رقم التواصل الافتراضي مكتوب هنا لأنه رقم العمل اللي بيتواصل عليه المستخدمون،
/// ويمكن تغييره وقت البناء بدون تعديل الكود، مثلاً:
///   flutter build apk --dart-define=ENGINEER_PHONE=2010xxxxxxx
///                     --dart-define=ENGINEER_PHONE_LOCAL=010xxxxxxx
class AppConfig {
  AppConfig._(); // منع إنشاء كائن من الكلاس

  /// رقم واتساب للتواصل (صيغة دولية بدون + أو مسافات).
  static const String engineerPhone =
      String.fromEnvironment('ENGINEER_PHONE', defaultValue: '201284172047');

  /// نفس الرقم بالصيغة المحلية للعرض (في ملفات PDF).
  static const String engineerPhoneLocal = String.fromEnvironment(
      'ENGINEER_PHONE_LOCAL',
      defaultValue: '01284172047');

  /// هل رقم التواصل مضبوط؟
  static bool get hasEngineerPhone => engineerPhone.trim().isNotEmpty;

  /// الرقم المعروض للمستخدم: المحلي لو موجود وإلا الدولي، وإلا نص فارغ.
  static String get engineerPhoneDisplay {
    if (engineerPhoneLocal.trim().isNotEmpty) return engineerPhoneLocal.trim();
    return engineerPhone.trim();
  }

  /// سطر التواصل في تذييل PDF، ويختفي لو الرقم غير مضبوط.
  static String get pdfContactLine =>
      engineerPhoneDisplay.isEmpty ? '' : ' | للتواصل: $engineerPhoneDisplay';

  /// رابط واتساب آمن، أو null لو الرقم غير مضبوط.
  static String? get whatsappUrl {
    final safePhone = engineerPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (safePhone.isEmpty) return null;
    return 'https://wa.me/$safePhone';
  }
}
