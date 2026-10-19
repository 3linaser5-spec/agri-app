import 'number_utils.dart';

/// تحويلات آمنة للبيانات القادمة من Firestore أو من ملفات JSON المستوردة.
///
/// المشكلة: لو حقل واحد جه بنوع غلط (مثلاً رقم بدل نص، أو 7.0 بدل 7)
/// الـ `as` العادي بيرمي TypeError ويوقّع الشاشة كلها. هنا بنحوّل بدل ما نرمي.
class SafeParse {
  /// أي قيمة -> نص (null يرجّع [fallback]).
  static String string(dynamic v, [String fallback = '']) {
    if (v == null) return fallback;
    // لو رقم صحيح (7.0) بنحوله لـ "7" بدل "7.0"
    if (v is num) {
      if (v == v.roundToDouble()) return v.toInt().toString();
      return v.toString();
    }
    return v.toString();
  }

  /// نص اختياري: null يفضل null.
  static String? stringOrNull(dynamic v) => v?.toString();

  /// رقم صحيح من int أو double أو نص (7 / 7.0 / "7" / "١٢٣").
  static int integer(dynamic v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) {
      // استخدام NumberUtils لدعم الأرقام العربية والفواصل
      return NumberUtils.tryParseInt(v.trim()) ?? fallback;
    }
    return fallback;
  }

  /// رقم عشري من int أو double أو نص (يدعم الأرقام العربية).
  static double? doubleOrNull(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) {
      final trimmed = v.trim();
      if (trimmed.isEmpty) return null;
      // استخدام NumberUtils لدعم الأرقام العربية والفواصل
      return NumberUtils.tryParseDouble(trimmed);
    }
    return null;
  }

  static double decimal(dynamic v, [double fallback = 0]) =>
      doubleOrNull(v) ?? fallback;

  /// Map بمفاتيح نصية (يتجاهل أي شيء ليس Map).
  static Map<String, dynamic> map(dynamic v) {
    if (v is Map) {
      return v.map((k, val) => MapEntry(k.toString(), val));
    }
    return <String, dynamic>{};
  }

  /// Map<String,String> وكل القيم تتحوّل لنص (null تتحول لنص فاضي).
  static Map<String, String> stringMap(dynamic v) {
    if (v is Map) {
      return v.map((k, val) => MapEntry(k.toString(), string(val)));
    }
    return <String, String>{};
  }

  /// قائمة Maps: يتجاهل العناصر اللي مش Map بدل ما يرمي.
  static List<Map<String, dynamic>> mapList(dynamic v) {
    if (v is! List) return <Map<String, dynamic>>[];
    return v.whereType<Map>().map((e) => map(e)).toList();
  }

  static List<Map<String, String>> stringMapList(dynamic v) {
    if (v is! List) return <Map<String, String>>[];
    return v.whereType<Map>().map((e) => stringMap(e)).toList();
  }
}
