import 'dart:ui' show Color;

/// تحويل آمن لألوان hex القادمة من Firestore أو من ملفات JSON المستوردة.
class ColorUtils {
  static final RegExp _valid = RegExp(r'^#?([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$');

  /// هل النص لون hex صالح (#RRGGBB أو #AARRGGBB، الـ # اختيارية)؟
  static bool isValidHex(String? hex) =>
      hex != null && _valid.hasMatch(hex.trim());

  /// يرجّع اللون، أو [fallback] لو النص مش صالح.
  static Color fromHex(String? hex,
      {Color fallback = const Color(0xFF047857)}) {
    if (!isValidHex(hex)) return fallback;

    // إزالة كل علامات # لو المستخدم كتب أكتر من واحدة بالغلط
    var h = hex!.trim().replaceAll('#', '');
    
    // إضافة Alpha كامل (FF) لو اللون 6 خانات
    if (h.length == 6) h = 'FF$h';
    
    final value = int.tryParse(h, radix: 16);
    return value == null ? fallback : Color(value);
  }
}
