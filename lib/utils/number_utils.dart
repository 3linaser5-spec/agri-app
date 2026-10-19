/// أدوات تعامل مع الأرقام المكتوبة بلوحة مفاتيح عربية أو إنجليزية.
/// 
/// الغرض من الكلاس ده هو توحيد شكل الأرقام (عربي/إنجليزي) قبل 
/// إرسالها لدوال التحويل القياسية (double.tryParse / int.tryParse).
class NumberUtils {
  static const _arabicIndic = '٠١٢٣٤٥٦٧٨٩';
  static const _easternArabicIndic = '۰۱۲۳۴۵۶۷۸۹';

  /// يحوّل الأرقام العربية/الفارسية إلى 0-9، والفاصلة العشرية العربية
  /// إلى '.', ويشيل المسافات والفواصل الألفية بدقة.
  static String normalize(String input) {
    if (input.isEmpty) return '';
    
    final buffer = StringBuffer();
    final chars = input.trim().split('');

    for (var i = 0; i < chars.length; i++) {
      final ch = chars[i];

      // 1. الأرقام العربية (٠١٢٣)
      final a = _arabicIndic.indexOf(ch);
      if (a != -1) {
        buffer.write(a);
        continue;
      }

      // 2. الأرقام الفارسية (۰۱۲۳)
      final e = _easternArabicIndic.indexOf(ch);
      if (e != -1) {
        buffer.write(e);
        continue;
      }

      // 3. الفاصلة العشرية العربية (٫)
      if (ch == '٫') {
        buffer.write('.');
        continue;
      }

      // 4. الفاصلة العربية العادية (،) - غالباً بيستخدمها المستخدم كفاصلة عشرية
      if (ch == '،') {
        buffer.write('.');
        continue;
      }

      // 5. الفاصلة الإنجليزية (,) - التحقق مما إذا كانت فاصلة ألفية أم عشرية
      if (ch == ',') {
        final isThousandSeparator = _isThousandSeparator(chars, i);
        if (!isThousandSeparator) {
          buffer.write('.'); // فاصلة عشرية
        }
        // لو فاصلة ألفية، بنتجاهلها تماماً (منكتبش حاجة)
        continue;
      }

      // 6. المسافات
      if (ch.trim().isEmpty) continue;

      // 7. أي رموز أخرى (نقط، سالب، زائد، إلخ)
      buffer.write(ch);
    }

    return buffer.toString();
  }

  /// التحقق مما إذا كانت الفاصلة (,) هي فاصلة ألفية (زي 1,000)
  static bool _isThousandSeparator(List<String> chars, int index) {
    var digitsAfter = 0;
    for (var j = index + 1; j < chars.length; j++) {
      if (_isDigit(chars[j])) {
        digitsAfter++;
      } else {
        break; // لو لقينا رمز تاني (زي نقطة أو مسافة)، يبقى مش فاصلة ألفية
      }
    }
    // الشرط الآمن: لو الرقم اللي بعدها 3 أرقام بالظبط فقط
    // ده بيمنع مشكلة إن "1,500" تتحول لـ "1500" بدل "1.5"
    return digitsAfter == 3;
  }

  static bool _isDigit(String c) {
    return (c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57) || // 0-9
           _arabicIndic.contains(c) ||
           _easternArabicIndic.contains(c);
  }

  /// بديل آمن لـ double.tryParse يقبل الأرقام العربية والفواصل المختلفة.
  static double? tryParseDouble(String? input) {
    if (input == null || input.trim().isEmpty) return null;
    final normalized = normalize(input);
    return double.tryParse(normalized);
  }

  /// بديل آمن لـ int.tryParse يقبل الأرقام العربية.
  static int? tryParseInt(String? input) {
    if (input == null || input.trim().isEmpty) return null;
    final normalized = normalize(input);
    return int.tryParse(normalized);
  }
}
