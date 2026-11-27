/// أعلام بناء بتتحدد وقت البناء بـ `--dart-define`، عشان نفس الكود يطلّع نسختين:
///
/// نسخة GitHub (الافتراضية):
///   flutter build apk --release
///   → التحديث الذاتي شغّال: بتنزّل APK من GitHub وتثبّته.
///
/// نسخة Google Play:
///   flutter build appbundle --release --dart-define=STORE_BUILD=true
///   → التحديث الذاتي مقفول، والتحديثات بتيجي من المتجر فقط.
///     ده مطلوب بسياسة Play اللي بتمنع تنزيل وتشغيل كود من برّه المتجر.
class BuildFlags {
  BuildFlags._(); // منع إنشاء كائن من الكلاس

  /// true في نسخة المتجر فقط (بتتحدد وقت البناء).
  static const bool storeBuild =
      bool.fromEnvironment('STORE_BUILD', defaultValue: false);
}
