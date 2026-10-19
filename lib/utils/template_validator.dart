import 'formula_evaluator.dart';

/// تحقق من شكل قالب الحاسبة (JSON) قبل حفظه في Firestore.
///
/// الهدف: ملف JSON واحد غلط ما يبوّظش قوالب القسم كله. بنرجّع قائمة أخطاء
/// مقروءة بالعربي؛ لو القائمة فاضية القالب سليم.
class TemplateValidator {
  static const _fieldTypes = {'number', 'text', 'dropdown', 'slider'};
  static final _idPattern = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

  static bool _isNum(dynamic v) =>
      v is num && v.toDouble().isFinite;

  static bool _isNonNegativeNum(dynamic v) =>
      _isNum(v) && (v as num).toDouble() >= 0;

  static bool _isNonEmptyString(dynamic v) =>
      v is String && v.trim().isNotEmpty;

  static String? _optionValue(dynamic v) {
    if (_isNonEmptyString(v)) return (v as String).trim();
    if (_isNum(v)) {
      final numVal = v as num;
      // التأكد من أن الرقم محدود قبل التحويل لنص (حماية إضافية)
      if (numVal.toDouble().isFinite) {
        return numVal.toString();
      }
    }
    return null;
  }

  /// يرجّع أخطاء القالب. [label] بيظهر قبل كل خطأ عشان نعرف أنهي قالب.
  static List<String> validate(Map<String, dynamic> t, {String label = ''}) {
    final errors = <String>[];
    void err(String msg) => errors.add(label.isEmpty ? msg : '$label: $msg');

    if (!_isNonEmptyString(t['name'])) err('الاسم مطلوب (نص)');

    for (final key in const ['emoji', 'description', 'area_unit']) {
      if (t[key] != null && t[key] is! String) err('"$key" لازم يكون نص');
    }

    // المتغيرات المسموحة في المعادلات: ids الحقول الصالحة فقط + area
    final knownVars = <String>{'area'};
    final rawFields = t['fields'];
    if (rawFields is List) {
      for (final f in rawFields) {
        if (f is Map && _isNonEmptyString(f['id'])) {
          final id = f['id'] as String;
          // نضيف الـ id فقط لو كان صالحاً (يطابق شروط التسمية)
          if (id == id.trim() && _idPattern.hasMatch(id)) {
            knownVars.add(id);
          }
        }
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
          } else if (id != (id as String).trim() || !_idPattern.hasMatch(id)) {
            err('$at: الـ id لازم يكون معرفًا إنجليزيًا بدون فراغات (يبدأ بحرف أو _)');
          } else if (!seen.add(id)) {
            err('$at: الـ id "$id" مكرر');
          }
          if (!_isNonEmptyString(f['label'])) err('$at: "label" مطلوب');

          if (f['required'] != null && f['required'] is! bool) {
            err('$at: "required" لازم يكون true أو false');
          }

          final type = f['type'];
          if (type != null && !_fieldTypes.contains(type)) {
            err('$at: نوع غير معروف "$type" (المسموح: ${_fieldTypes.join("، ")})');
          }
          
          for (final k in const ['min', 'max', 'default']) {
            if (f[k] != null && !_isNum(f[k])) err('$at: "$k" لازم يكون رقم');
          }

          // التحقق الخاص بالسلايدر: لازم يكون ليه حدود
          if (type == 'slider') {
            if (!_isNum(f['min']) || !_isNum(f['max'])) {
              err('$at: السلايدر لازم يكون ليه "min" و"max"');
            }
          }

          final min = f['min'];
          final max = f['max'];
          final defaultValue = f['default'];
          if (_isNum(min) && _isNum(max) && (max as num) < (min as num)) {
            err('$at: "max" لا يمكن أن يكون أقل من "min"');
          }
          if (_isNum(defaultValue) && _isNum(min) &&
              (defaultValue as num) < (min as num)) {
            err('$at: القيمة الافتراضية أقل من الحد الأدنى');
          }
          if (_isNum(defaultValue) && _isNum(max) &&
              (defaultValue as num) > (max as num)) {
            err('$at: القيمة الافتراضية أكبر من الحد الأقصى');
          }

          if (type == 'dropdown') {
            final options = f['options'];
            if (options is! List || options.isEmpty) {
              err('$at: القائمة المنسدلة محتاجة "options" (قائمة غير فاضية)');
            } else {
              for (var j = 0; j < options.length; j++) {
                final o = options[j];
                if (o is! Map ||
                    _optionValue(o['value']) == null ||
                    !_isNonEmptyString(o['label'])) {
                  err('$at: الخيار ${j + 1} لازم فيه "value" و"label"');
                }
              }
              final values = <String>{};
              final labels = <String>{};
              for (final o in options.whereType<Map>()) {
                final value = o['value'];
                final label = o['label'];
                final normalizedValue = _optionValue(value);
                if (normalizedValue != null && !values.add(normalizedValue)) {
                  err('$at: قيمة خيار مكررة "$normalizedValue"');
                }
                if (_isNonEmptyString(label) &&
                    !labels.add((label as String).trim())) {
                  err('$at: اسم خيار مكرر "${label.trim()}"');
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
            if (v != null && !_isNonNegativeNum(v)) {
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
          if (fin[k] != null && !_isNonNegativeNum(fin[k])) {
            err('financial.$k لازم يكون رقم 0 أو أكبر');
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
          } else {
            if (dist.keys.any((k) => !_isNonEmptyString(k))) {
              err('financial.cost_distribution أسماء البنود لازم تكون نصوصًا غير فارغة');
            }
            if (dist.values.any((v) => !_isNonNegativeNum(v) || (v as num) > 100)) {
              err('financial.cost_distribution كل قيمة لازم تكون بين 0 و100');
            }
            final sum = dist.values
                .where(_isNum)
                .fold<double>(0, (total, v) => total + (v as num).toDouble());
            if (dist.isNotEmpty && (sum - 100).abs() > 0.5) {
              err('financial.cost_distribution لازم يكون مجموعها 100%');
            }
          }
        }
      }
    }

    return errors;
  }
}
