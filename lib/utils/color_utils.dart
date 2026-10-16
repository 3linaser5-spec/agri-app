import 'dart:ui' show Color;

/// تحويل آمن لألوان hex القادمة من Firestore أو من ملفات JSON المستوردة.
///
/// المشكلة القديمة: `int.parse('FF' + hex)` مع قيمة من 8 خانات أو 3 خانات أو نص
/// مش hex كانت بتطلع لون غلط أو شفاف أو بترمي خطأ.
class ColorUtils {
  static final RegExp _valid = RegExp(r'^#?([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$');

  /// هل النص لون hex صالح (#RRGGBB أو #AARRGGBB، الـ # اختيارية)؟
  static bool isValidHex(String? hex) =>
      hex != null && _valid.hasMatch(hex.trim());

  /// يرجّع اللون، أو [fallback] لو النص مش صالح.
  static Color fromHex(String? hex,
      {Color fallback = const Color(0xFF047857)}) {
    if (!isValidHex(hex)) return fallback;
    var h = hex!.trim().replaceFirst('#', '');
    if (h.length == 6) h = 'FF$h';
    final value = int.tryParse(h, radix: 16);
    return value == null ? fallback : Color(value);
  }
}
