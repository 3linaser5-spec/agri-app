/// أدوات تعامل مع الأرقام المكتوبة بلوحة مفاتيح عربية.
class NumberUtils {
  static const _arabicIndic = '٠١٢٣٤٥٦٧٨٩';
  static const _easternArabicIndic = '۰۱۲۳۴۵۶۷۸۹';

  /// يحوّل الأرقام العربية/الفارسية إلى 0-9، والفاصلة العشرية العربية
  /// '٫' و'،' و',' إلى '.'، ويشيل المسافات.
  static String normalize(String input) {
    final buffer = StringBuffer();
    for (final ch in input.trim().split('')) {
      final a = _arabicIndic.indexOf(ch);
      if (a != -1) {
        buffer.write(a);
        continue;
      }
      final e = _easternArabicIndic.indexOf(ch);
      if (e != -1) {
        buffer.write(e);
        continue;
      }
      if (ch == '٫' || ch == '،' || ch == ',') {
        buffer.write('.');
        continue;
      }
      if (ch.trim().isEmpty) continue; // مسافات
      buffer.write(ch);
    }
    return buffer.toString();
  }

  /// بديل آمن لـ double.tryParse يقبل الأرقام العربية.
  static double? tryParseDouble(String? input) {
    if (input == null) return null;
    return double.tryParse(normalize(input));
  }

  /// بديل آمن لـ int.tryParse يقبل الأرقام العربية.
  static int? tryParseInt(String? input) {
    if (input == null) return null;
    return int.tryParse(normalize(input));
  }
}
