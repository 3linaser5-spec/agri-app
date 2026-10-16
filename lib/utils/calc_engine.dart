import 'formula_evaluator.dart';
import 'safe_parse.dart';

/// حسابات الحاسبات الزراعية في مكان واحد.
///
/// قبل كده كل شاشة (النتيجة، تفاصيل البرنامج المحفوظ، الـ PDF) كانت بتحسب
/// المساحة بطريقتها فالكميات كانت بتتغير بعد الحفظ. دلوقتي الكل بيستخدم
/// نفس الدوال.
///
/// القاعدة: لو للمادة (أو للإنتاج) معادلة صالحة بتتحسب منها، وإلا الحساب
/// الخطي القديم: القيمة لكل وحدة × المساحة. فالقوالب القديمة بتفضل زي ما هي.
class CalcEngine {
  /// المساحة المستخدمة في الحساب: حقل "area" الصريح، وإلا أول حقل اسمه فيه
  /// area أو مساحة، وإلا 1.
  static double areaMultiplier(Map<String, dynamic> inputs) {
    final direct = _asNum(inputs['area']);
    if (direct != null) return direct;
    for (final entry in inputs.entries) {
      final key = entry.key.toLowerCase();
      if (key.contains('area') || entry.key.contains('مساحة')) {
        final v = _asNum(entry.value);
        if (v != null) return v;
      }
    }
    return 1.0;
  }

  /// هل المساحة اتحددت صراحة؟ (للتنبيه لو اتحسبت على افتراض 1)
  static bool hasExplicitArea(Map<String, dynamic> inputs) {
    if (_asNum(inputs['area']) != null) return true;
    for (final entry in inputs.entries) {
      final key = entry.key.toLowerCase();
      if ((key.contains('area') || entry.key.contains('مساحة')) &&
          _asNum(entry.value) != null) {
        return true;
      }
    }
    return false;
  }

  /// متغيرات المعادلات: كل مدخل رقمي + area.
  static Map<String, double> variables(Map<String, dynamic> inputs) {
    final vars = <String, double>{};
    inputs.forEach((k, v) {
      final n = _asNum(v);
      if (n != null) vars[k] = n;
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
      final v = FormulaEvaluator.evaluate(f, variables(inputs));
      if (v != null) return v < 0 ? 0 : v;
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

  // مدخل رقمي فقط: num أو نص رقمي (قيمة dropdown رقمية مثلاً). النص الفاضي لا.
  static double? _asNum(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String && v.trim().isNotEmpty) return double.tryParse(v.trim());
    return null;
  }
}
