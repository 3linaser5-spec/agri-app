/// إعدادات ثابتة للتطبيق في مكان واحد.
///
/// القيم الافتراضية هي نفس اللي كانت مكتوبة في الكود، ويمكن تغييرها وقت البناء
/// بدون تعديل الكود، مثلاً:
///   flutter build apk --dart-define=ENGINEER_PHONE=2010xxxxxxx
class AppConfig {
  /// رقم واتساب المهندس (بصيغة دولية بدون +).
  static const String engineerPhone =
      String.fromEnvironment('ENGINEER_PHONE', defaultValue: '201284172047');

  /// نفس الرقم بالصيغة المحلية للعرض (في ملفات PDF).
  static const String engineerPhoneLocal = String.fromEnvironment(
      'ENGINEER_PHONE_LOCAL',
      defaultValue: '01284172047');

  static const String whatsappUrl = 'https://wa.me/$engineerPhone';

  /// موديل Gemini. غيّره وقت البناء لو اسم الموديل اتغيّر عند Google:
  ///   --dart-define=GEMINI_MODEL=<model-id>
  static const String geminiModel =
      String.fromEnvironment('GEMINI_MODEL', defaultValue: 'gemini-3.8-flash');

  /// حسابات الأدمن (واجهة فقط). الحماية الحقيقية لازم تكون في قواعد Firestore،
  /// راجع firebase/README.md.
  static const List<String> adminEmails = [
    '01284172047@agri-app.local',
  ];
}
