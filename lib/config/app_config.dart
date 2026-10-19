/// إعدادات ثابتة للتطبيق في مكان واحد.
///
/// القيم الافتراضية هي نفس اللي كانت مكتوبة في الكود، ويمكن تغييرها وقت البناء
/// بدون تعديل الكود، مثلاً:
///   flutter build apk --dart-define=ENGINEER_PHONE=2010xxxxxxx
class AppConfig {
  AppConfig._(); // منع إنشاء كائن من الكلاس

  /// رقم واتساب المهندس (بصيغة دولية بدون + أو مسافات).
  static const String engineerPhone =
      String.fromEnvironment('ENGINEER_PHONE', defaultValue: '201284172047');

  /// نفس الرقم بالصيغة المحلية للعرض (في ملفات PDF).
  static const String engineerPhoneLocal = String.fromEnvironment(
      'ENGINEER_PHONE_LOCAL',
      defaultValue: '01284172047');

  /// رابط واتساب آمن (يشيل أي رموز غير أرقام).
  static String get whatsappUrl {
    // إزالة أي رموز غير الأرقام (زي + أو مسافات) لضمان سلامة الرابط
    final safePhone = engineerPhone.replaceAll(RegExp(r'[^0-9]'), '');
    return 'https://wa.me/$safePhone';
  }

  /// موديل Gemini. غيّره وقت البناء لو اسم الموديل اتغيّر عند Google:
  ///   --dart-define=GEMINI_MODEL=<model-id>
  static const String geminiModel = String.fromEnvironment(
    'GEMINI_MODEL', 
    defaultValue: 'gemini-1.5-flash', // تم تعديله لموديل حقيقي
  );

  /// حسابات الأدمن (واجهة فقط). الحماية الحقيقية لازم تكون في قواعد Firestore،
  /// راجع firebase/README.md.
  static const List<String> adminEmails = [
    '01284172047@agri-app.local',
  ];
}
