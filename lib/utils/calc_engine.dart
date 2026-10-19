import 'formula_evaluator.dart';
import 'safe_parse.dart';

/// حسابات الحاسبات الزراعية في مكان واحد.
///
/// القاعدة: لو للمادة (أو للإنتاج) معادلة صالحة بتتحسب منها، وإلا الحساب
/// الخطي القديم: القيمة لكل وحدة × المساحة. فالقوالب القديمة بتفضل زي ما هي.
class CalcEngine {
  /// المساحة المستخدمة في الحساب: حقل "area" الصريح، وإلا أول حقل اسمه فيه
  /// area أو مساحة، وإلا 1.
  static double areaMultiplier(Map<String, dynamic> inputs) {
    final direct = _asNum(inputs['area']);
    if (direct != null) return direct > 0 ? direct : 1.0;

    for (final entry in inputs.entries) {
      final key = entry.key.toLowerCase();
      if (key.contains('area') || entry.key.contains('مساحة')) {
        final v = _asNum(entry.value);
        if (v != null && v > 0) return v;
      }
    }
    return 1.0;
  }

  /// هل المساحة اتحددت صراحة؟ (للتنبيه لو اتحسبت على افتراض 1)
  static bool hasExplicitArea(Map<String, dynamic> inputs) {
    if ((_asNum(inputs['area']) ?? 0) > 0) return true;
    for (final entry in inputs.entries) {
      final key = entry.key.toLowerCase();
      if ((key.contains('area') || entry.key.contains('مساحة')) &&
          (_asNum(entry.value) ?? 0) > 0) {
        return true;
      }
    }
    return false;
  }

  /// متغيرات المعادلات: كل مدخل رقمي + area.
  /// تحسين: يتم تحويل كل أسماء المتغيرات إلى lowercase لتجنب مشاكل الحروف الكبيرة (Area vs area).
  static Map<String, double> variables(Map<String, dynamic> inputs) {
    final vars = <String, double>{};
    inputs.forEach((k, v) {
      final n = _asNum(v);
      if (n != null) {
        vars[k.toLowerCase()] = n;
      }
    });
    vars['area'] = areaMultiplier(inputs);
    return vars;
  }

  /// الكمية الكلية لمادة.
  static double quantity({
    required double perUnit,
    String? formula,
    required Map<String, dynamic> inputs,
  }) {
    final f = formula?.trim();
    if (f != null && f.isNotEmpty) {
      try {
        // نرسل المعادلة كما هي (عشان منبوظش دوال زي Sin أو أسماء عربية)
        // لكن المتغيرات اللي جوه map بقت lowercase
        final v = FormulaEvaluator.evaluate(f, variables(inputs));
        
        // لو المعادلة فيها خطأ أو رجعت null، نرجع الحساب الخطي كخطة بديلة (Fallback)
        if (v != null && !v.isNaN && !v.isInfinite) {
          return v < 0 ? 0 : v;
        }
      } catch (_) {
        // في حال حدوث أي استثناء غير متوقع في المقيّم
      }
    }
    return perUnit * areaMultiplier(inputs);
  }

  /// الإنتاج الكلي المتوقع.
  static double totalYield({
    required double perUnit,
    String? yieldFormula,
    required Map<String, dynamic> inputs,
  }) =>
      quantity(perUnit: perUnit, formula: yieldFormula, inputs: inputs);

  // ───── نسخ تشتغل على الـ Map المحفوظ في برنامج "مزرعتي" وملف PDF ─────

  static double materialQuantity(
          Map<String, dynamic> material, Map<String, dynamic> inputs) =>
      quantity(
        perUnit: SafeParse.decimal(material['quantity_per_unit']),
        formula: SafeParse.stringOrNull(material['quantity_formula']),
        inputs: inputs,
      );

  static double materialCost(
          Map<String, dynamic> material, Map<String, dynamic> inputs) =>
      materialQuantity(material, inputs) *
      SafeParse.decimal(material['price_per_unit']);

  static double materialsTotalCost(
      List<Map<String, dynamic>> materials, Map<String, dynamic> inputs) {
    var total = 0.0;
    for (final m in materials) {
      total += materialCost(m, inputs);
    }
    return total;
  }

  static double yieldOf(
          Map<String, dynamic> financial, Map<String, dynamic> inputs) =>
      totalYield(
        perUnit: SafeParse.decimal(financial['expected_yield']),
        yieldFormula: SafeParse.stringOrNull(financial['yield_formula']),
        inputs: inputs,
      );

  // ───── دوال إضافية مفيدة للواجهة (UI Helpers) ─────

  /// التحقق من أن المعادلة سليمة وتعمل بدون أخطاء
  static bool isValidFormula(String formula, Map<String, dynamic> inputs) {
    if (formula.trim().isEmpty) return false;
    try {
      // نرسل المعادلة كما هي بدون toLowerCase
      final v = FormulaEvaluator.evaluate(formula, variables(inputs));
      return v != null && !v.isNaN && !v.isInfinite;
    } catch (_) {
      return false;
    }
  }

  /// مدخل رقمي فقط: num أو نص رقمي مع معالجة الفواصل العربية والمسافات.
  static double? _asNum(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String && v.trim().isNotEmpty) {
      // استبدال الفاصلة العادية أو العربية بنقطة عشرية وإزالة أي رموز غير مساعدة
      final cleaned = v.trim().replaceAll(',', '.');
      return double.tryParse(cleaned);
    }
    return null;
  }
}
