import 'formula_evaluator.dart';

/// تحقق من شكل قالب الحاسبة (JSON) قبل حفظه في Firestore.
///
/// الهدف: ملف JSON واحد غلط ما يبوّظش قوالب القسم كله. بنرجّع قائمة أخطاء
/// مقروءة بالعربي؛ لو القائمة فاضية القالب سليم.
class TemplateValidator {
  static const _fieldTypes = {'number', 'text', 'dropdown', 'slider'};

  static bool _isNum(dynamic v) => v is num;

  static bool _isNonEmptyString(dynamic v) =>
      v is String && v.trim().isNotEmpty;

  /// يرجّع أخطاء القالب. [label] بيظهر قبل كل خطأ عشان نعرف أنهي قالب.
  static List<String> validate(Map<String, dynamic> t, {String label = ''}) {
    final errors = <String>[];
    void err(String msg) => errors.add(label.isEmpty ? msg : '$label: $msg');

    if (!_isNonEmptyString(t['name'])) err('الاسم مطلوب (نص)');

    for (final key in const ['emoji', 'description', 'area_unit']) {
      if (t[key] != null && t[key] is! String) err('"$key" لازم يكون نص');
    }

    // المتغيرات المسموحة في المعادلات: ids الحقول + area
    final knownVars = <String>{'area'};
    final rawFields = t['fields'];
    if (rawFields is List) {
      for (final f in rawFields) {
        if (f is Map && f['id'] is String) knownVars.add((f['id'] as String).trim());
      }
    }

    // ---- fields ----
    final fields = t['fields'];
    if (fields != null) {
      if (fields is! List) {
        err('"fields" لازم تكون قائمة');
      } else {
        final seen = <String>{};
        for (var i = 0; i < fields.length; i++) {
          final f = fields[i];
          final at = 'حقل ${i + 1}';
          if (f is! Map) {
            err('$at ليس Object');
            continue;
          }
          final id = f['id'];
          if (!_isNonEmptyString(id)) {
            err('$at: "id" مطلوب');
          } else if (!seen.add((id as String).trim())) {
            err('$at: الـ id "$id" مكرر');
          }
          if (!_isNonEmptyString(f['label'])) err('$at: "label" مطلوب');

          final type = f['type'];
          if (type != null && !_fieldTypes.contains(type)) {
            err('$at: نوع غير معروف "$type" (المسموح: ${_fieldTypes.join("، ")})');
          }
          for (final k in const ['min', 'max', 'default']) {
            if (f[k] != null && !_isNum(f[k])) err('$at: "$k" لازم يكون رقم');
          }

          if (type == 'dropdown') {
            final options = f['options'];
            if (options is! List || options.isEmpty) {
              err('$at: القائمة المنسدلة محتاجة "options" (قائمة غير فاضية)');
            } else {
              for (var j = 0; j < options.length; j++) {
                final o = options[j];
                if (o is! Map ||
                    o['value'] == null ||
                    !_isNonEmptyString(o['label'])) {
                  err('$at: الخيار ${j + 1} لازم فيه "value" و"label"');
                }
              }
            }
          }
        }
      }
    }

    // ---- tasks ----
    final tasks = t['tasks'];
    if (tasks != null) {
      if (tasks is! List) {
        err('"tasks" لازم تكون قائمة');
      } else {
        for (var i = 0; i < tasks.length; i++) {
          final k = tasks[i];
          final at = 'مهمة ${i + 1}';
          if (k is! Map) {
            err('$at ليست Object');
            continue;
          }
          if (!_isNonEmptyString(k['title'])) err('$at: "title" مطلوب');
          final d = k['day_from_start'];
          if (!_isNum(d) || (d as num) < 0) {
            err('$at: "day_from_start" لازم يكون رقم 0 أو أكبر');
          }
        }
      }
    }

    // ---- materials ----
    final materials = t['materials'];
    if (materials != null) {
      if (materials is! List) {
        err('"materials" لازم تكون قائمة');
      } else {
        for (var i = 0; i < materials.length; i++) {
          final m = materials[i];
          final at = 'مادة ${i + 1}';
          if (m is! Map) {
            err('$at ليست Object');
            continue;
          }
          if (!_isNonEmptyString(m['name'])) err('$at: "name" مطلوب');
          final qf = m['quantity_formula'];
          if (qf != null) {
            if (qf is! String) {
              err('$at: "quantity_formula" لازم تكون نص');
            } else {
              final e = FormulaEvaluator.validate(qf, knownVars);
              if (e != null) err('$at: معادلة الكمية: $e');
            }
          }
          for (final k in const ['quantity_per_unit', 'price_per_unit']) {
            final v = m[k];
            if (v != null && (!_isNum(v) || (v as num) < 0)) {
              err('$at: "$k" لازم يكون رقم 0 أو أكبر');
            }
          }
        }
      }
    }

    // ---- financial ----
    final fin = t['financial'];
    if (fin != null) {
      if (fin is! Map) {
        err('"financial" لازم يكون Object');
      } else {
        for (final k in const ['expected_yield', 'expected_price']) {
          if (fin[k] != null && !_isNum(fin[k])) {
            err('financial.$k لازم يكون رقم');
          }
        }
        final yf = fin['yield_formula'];
        if (yf != null) {
          if (yf is! String) {
            err('financial.yield_formula لازم تكون نص');
          } else {
            final e = FormulaEvaluator.validate(yf, knownVars);
            if (e != null) err('معادلة الإنتاج: $e');
          }
        }
        final dist = fin['cost_distribution'];
        if (dist != null) {
          if (dist is! Map) {
            err('financial.cost_distribution لازم يكون Object');
          } else if (dist.values.any((v) => !_isNum(v))) {
            err('financial.cost_distribution كل قيمه لازم تكون أرقام');
          }
        }
      }
    }

    return errors;
  }
}
