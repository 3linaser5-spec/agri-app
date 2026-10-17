import 'package:agri_app/utils/template_validator.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> validTemplate() => <String, dynamic>{
      'name': 'قمح',
      'fields': <Map<String, dynamic>>[
        {'id': 'seed_rate', 'label': 'معدل التقاوي', 'type': 'number'},
      ],
      'tasks': <Map<String, dynamic>>[
        {'title': 'ري', 'day_from_start': 0},
      ],
      'materials': <Map<String, dynamic>>[
        {
          'name': 'تقاوي',
          'quantity_per_unit': 50,
          'price_per_unit': 20,
          'quantity_formula': 'area * seed_rate',
        },
      ],
      'financial': {
        'expected_yield': 2,
        'expected_price': 100,
        'yield_formula': 'area * 2',
      },
    };

bool anyContains(List<String> errors, String text) =>
    errors.any((e) => e.contains(text));

void main() {
  group('TemplateValidator', () {
    test('accepts a valid template, including formulas', () {
      expect(TemplateValidator.validate(validTemplate()), isEmpty);
    });

    test('name is required', () {
      final t = validTemplate()..remove('name');
      expect(TemplateValidator.validate(t), isNotEmpty);
    });

    test('label is prefixed to every message', () {
      final t = validTemplate()..remove('name');
      final errors = TemplateValidator.validate(t, label: 'قالب 1');
      expect(errors.every((e) => e.startsWith('قالب 1')), isTrue);
    });

    test('rejects an unknown variable in a material formula', () {
      final t = validTemplate();
      (t['materials'] as List)[0]['quantity_formula'] = 'area * foo';
      expect(anyContains(TemplateValidator.validate(t), 'foo'), isTrue);
    });

    test('rejects an unknown variable in the yield formula', () {
      final t = validTemplate();
      (t['financial'] as Map)['yield_formula'] = 'area * mystery';
      final errors = TemplateValidator.validate(t);
      expect(anyContains(errors, 'mystery'), isTrue);
      expect(anyContains(errors, 'معادلة الإنتاج'), isTrue);
    });

    test('rejects a formula that always divides by zero', () {
      final t = validTemplate();
      (t['financial'] as Map)['yield_formula'] = '5 / 0';
      expect(anyContains(TemplateValidator.validate(t), 'معادلة الإنتاج'),
          isTrue);
    });

    test('quantity_formula must be text', () {
      final t = validTemplate();
      (t['materials'] as List)[0]['quantity_formula'] = 5;
      expect(anyContains(TemplateValidator.validate(t), 'quantity_formula'),
          isTrue);
    });

    test('rejects duplicate field ids', () {
      final t = validTemplate();
      (t['fields'] as List).add(
          {'id': 'seed_rate', 'label': 'تاني', 'type': 'number'});
      expect(anyContains(TemplateValidator.validate(t), 'مكرر'), isTrue);
    });

    test('rejects an unknown field type', () {
      final t = validTemplate();
      (t['fields'] as List)[0]['type'] = 'checkbox';
      expect(anyContains(TemplateValidator.validate(t), 'checkbox'), isTrue);
    });

    test('a dropdown needs options', () {
      final t = validTemplate();
      (t['fields'] as List)
          .add({'id': 'crop', 'label': 'المحصول', 'type': 'dropdown'});
      expect(anyContains(TemplateValidator.validate(t), 'options'), isTrue);
    });

    test('a dropdown with proper options is valid', () {
      final t = validTemplate();
      (t['fields'] as List).add({
        'id': 'crop',
        'label': 'المحصول',
        'type': 'dropdown',
        'options': [
          {'value': 'a', 'label': 'أ'},
          {'value': 'b', 'label': 'ب'},
        ],
      });
      expect(TemplateValidator.validate(t), isEmpty);
    });

    test('rejects ids with whitespace and non-boolean required', () {
      final t = validTemplate();
      final field = (t['fields'] as List)[0] as Map<String, dynamic>;
      field['id'] = 'seed rate';
      field['required'] = 'true';
      final errors = TemplateValidator.validate(t);
      expect(anyContains(errors, 'id'), isTrue);
      expect(anyContains(errors, 'required'), isTrue);
    });

    test('rejects invalid numeric field ranges and defaults', () {
      final t = validTemplate();
      final field = (t['fields'] as List)[0] as Map<String, dynamic>;
      field['min'] = 10;
      field['max'] = 5;
      field['default'] = 20;
      final errors = TemplateValidator.validate(t);
      expect(anyContains(errors, 'max'), isTrue);
      expect(anyContains(errors, 'الافتراضية'), isTrue);
    });

    test('rejects empty and duplicate dropdown options', () {
      final t = validTemplate();
      (t['fields'] as List).add({
        'id': 'crop',
        'label': 'المحصول',
        'type': 'dropdown',
        'options': [
          {'value': 'a', 'label': 'أ'},
          {'value': 'a', 'label': 'أخرى'},
          {'value': '', 'label': 'فارغ'},
        ],
      });
      final errors = TemplateValidator.validate(t);
      expect(anyContains(errors, 'مكررة'), isTrue);
      expect(anyContains(errors, 'الخيار 3'), isTrue);
    });

    test('validates non-negative financial ranges and distribution sum', () {
      final t = validTemplate();
      final financial = t['financial'] as Map<String, dynamic>;
      financial['expected_price'] = -1;
      financial['cost_distribution'] = {'تقاوي': 40, 'عمالة': 40};
      final errors = TemplateValidator.validate(t);
      expect(anyContains(errors, 'expected_price'), isTrue);
      expect(anyContains(errors, 'مجموعها 100'), isTrue);

      financial['expected_price'] = 100;
      financial['cost_distribution'] = {'تقاوي': 101};
      expect(anyContains(TemplateValidator.validate(t), 'بين 0 و100'), isTrue);
    });

    test('rejects tasks with a negative or missing day', () {
      final t = validTemplate();
      (t['tasks'] as List)[0]['day_from_start'] = -1;
      expect(TemplateValidator.validate(t), isNotEmpty);

      final t2 = validTemplate();
      (t2['tasks'] as List)[0].remove('day_from_start');
      expect(TemplateValidator.validate(t2), isNotEmpty);
    });

    test('rejects non-list sections', () {
      final t = validTemplate();
      t['tasks'] = 'x';
      expect(TemplateValidator.validate(t), isNotEmpty);
    });
  });
}
