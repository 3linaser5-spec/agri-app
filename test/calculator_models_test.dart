import 'package:flutter_test/flutter_test.dart';

import 'package:agri_app/models/calculator_models.dart';

void main() {
  test('FormFieldConfig يقرأ الحقول الاختيارية ويحافظ عليها في toMap', () {
    final field = FormFieldConfig.fromMap({
      'id': 'area',
      'label': 'المساحة',
      'type': 'number',
      'unit': 'فدان',
      'hint': 'مساحة الأرض',
      'required': false,
      'options': [
        {'value': 'a', 'label': 'أ'},
      ],
      'min': 0,
      'max': '10',
      'default': 1.5,
    });

    expect(field.id, 'area');
    expect(field.type, 'number');
    expect(field.required, isFalse);
    expect(field.options, hasLength(1));
    expect(field.max, 10);
    expect(field.defaultValue, 1.5);
    expect(field.toMap()['options'], hasLength(1));
    expect(field.toMap()['default'], 1.5);

    final minimal = FormFieldConfig.fromMap(const {'id': 'soil'});
    expect(minimal.type, 'text');
    expect(minimal.required, isTrue);
    expect(minimal.toMap().containsKey('options'), isFalse);
    expect(minimal.toMap().containsKey('min'), isFalse);
  });

  test('CalculatorTask يقرأ ويكتب المهام', () {
    final task = CalculatorTask.fromMap(const {
      'title': 'رية المحاياة',
      'description': 'بعد الزراعة',
      'day_from_start': '7',
    });

    expect(task.title, 'رية المحاياة');
    expect(task.dayFromStart, 7);
    expect(task.category, 'عام');
    expect(task.toMap()['day_from_start'], 7);
  });

  test('CalculatorMaterial يقرأ المعادلة الاختيارية ويتجاهل الفراغ', () {
    final material = CalculatorMaterial.fromMap(const {
      'name': 'بذور',
      'category': 'تقاوي',
      'quantity_per_unit': '60',
      'price_per_unit': 20,
      'quantity_formula': '  area * 60  ',
    });

    expect(material.unit, 'كجم');
    expect(material.quantityPerUnit, 60);
    expect(material.quantityFormula, 'area * 60');
    expect(material.toMap()['quantity_formula'], 'area * 60');

    final plain = CalculatorMaterial.fromMap(const {
      'name': 'سماد',
      'quantity_formula': '   ',
    });
    expect(plain.category, 'عام');
    expect(plain.quantityFormula, isNull);
    expect(plain.toMap().containsKey('quantity_formula'), isFalse);
  });

  test('CalculatorFinancial يقرأ التوزيع ويستبعد القيم غير الرقمية', () {
    final financial = CalculatorFinancial.fromMap(const {
      'expected_yield': '3.5',
      'yield_unit': 'طن',
      'expected_price': 2000,
      'cost_distribution': {'تقاوي': 40, 'سماد': '40', 'أخرى': 'غير رقم'},
      'yield_formula': ' area * 3.5 ',
    });

    expect(financial.expectedYieldPerUnit, 3.5);
    expect(financial.expectedPricePerYieldUnit, 2000);
    expect(financial.costDistribution, {'تقاوي': 40, 'سماد': 40});
    expect(financial.yieldFormula, 'area * 3.5');
    expect(financial.toMap()['yield_formula'], 'area * 3.5');

    final empty = CalculatorFinancial.fromMap(const {});
    expect(empty.yieldUnit, 'طن');
    expect(empty.costDistribution, isEmpty);
    expect(empty.toMap().containsKey('yield_formula'), isFalse);
  });
}
