import 'package:agri_app/utils/calc_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('areaMultiplier', () {
    test('explicit "area" wins', () {
      expect(CalcEngine.areaMultiplier({'area': 2.5, 'plot_area': 9}),
          closeTo(2.5, 1e-9));
    });

    test('numeric text is accepted (e.g. a dropdown value)', () {
      expect(CalcEngine.areaMultiplier({'area': '3'}), closeTo(3, 1e-9));
    });

    test('falls back to a field whose id contains "area" or "مساحة"', () {
      expect(CalcEngine.areaMultiplier({'plot_area': '3'}), closeTo(3, 1e-9));
      expect(CalcEngine.areaMultiplier({'مساحة_الحقل': 4}), closeTo(4, 1e-9));
    });

    test('defaults to 1 when there is no usable area', () {
      expect(CalcEngine.areaMultiplier({}), 1.0);
      expect(CalcEngine.areaMultiplier({'area': ''}), 1.0);
      expect(CalcEngine.areaMultiplier({'area': 'abc'}), 1.0);
      expect(CalcEngine.areaMultiplier({'area': 0}), 1.0);
      expect(CalcEngine.areaMultiplier({'area': -2}), 1.0);
      expect(CalcEngine.areaMultiplier({'seed_rate': 20}), 1.0);
    });
  });

  group('hasExplicitArea', () {
    test('true only when a numeric area was given', () {
      expect(CalcEngine.hasExplicitArea({'area': 1}), isTrue);
      expect(CalcEngine.hasExplicitArea({'plot_area': '2'}), isTrue);
      expect(CalcEngine.hasExplicitArea({}), isFalse);
      expect(CalcEngine.hasExplicitArea({'seed_rate': 5}), isFalse);
      expect(CalcEngine.hasExplicitArea({'area': ''}), isFalse);
      expect(CalcEngine.hasExplicitArea({'area': 0}), isFalse);
      expect(CalcEngine.hasExplicitArea({'area': -1}), isFalse);
    });
  });

  group('variables', () {
    test('contains numeric inputs and always area', () {
      final vars =
          CalcEngine.variables({'seed_rate': 20, 'name': 'abc', 'area': 2});
      expect(vars['seed_rate'], 20.0);
      expect(vars['area'], 2.0);
      expect(vars.containsKey('name'), isFalse);
    });

    test('area is 1 when it was not entered', () {
      expect(CalcEngine.variables({'seed_rate': 20})['area'], 1.0);
    });
  });

  group('quantity', () {
    test('without a formula it is per-unit x area (old behaviour)', () {
      expect(
        CalcEngine.quantity(perUnit: 5, inputs: {'area': 3}),
        closeTo(15, 1e-9),
      );
    });

    test('a valid formula replaces the per-unit rule', () {
      expect(
        CalcEngine.quantity(
            perUnit: 5, formula: 'area * 2 + 1', inputs: {'area': 3}),
        closeTo(7, 1e-9),
      );
    });

    test('formulas can use other numeric inputs, including numeric text', () {
      expect(
        CalcEngine.quantity(
            perUnit: 0,
            formula: 'area * rate',
            inputs: {'area': 2, 'rate': '5'}),
        closeTo(10, 1e-9),
      );
    });

    test('an invalid formula falls back to per-unit x area', () {
      expect(
        CalcEngine.quantity(
            perUnit: 5, formula: 'area *', inputs: {'area': 3}),
        closeTo(15, 1e-9),
      );
      expect(
        CalcEngine.quantity(
            perUnit: 5, formula: 'area / 0', inputs: {'area': 3}),
        closeTo(15, 1e-9),
      );
    });

    test('blank formula counts as no formula', () {
      expect(
        CalcEngine.quantity(perUnit: 5, formula: '  ', inputs: {'area': 3}),
        closeTo(15, 1e-9),
      );
    });

    test('a negative formula result is clamped to zero', () {
      expect(
        CalcEngine.quantity(
            perUnit: 5, formula: 'area - 10', inputs: {'area': 3}),
        0,
      );
    });
  });

  group('materials from saved program maps', () {
    final inputs = {'area': 3};

    test('quantity uses per-unit when the formula is empty or missing', () {
      expect(
        CalcEngine.materialQuantity(
            {'quantity_per_unit': 2, 'quantity_formula': ''}, inputs),
        closeTo(6, 1e-9),
      );
      expect(
        CalcEngine.materialQuantity({'quantity_per_unit': 2}, inputs),
        closeTo(6, 1e-9),
      );
    });

    test('cost = quantity x price', () {
      expect(
        CalcEngine.materialCost(
            {'quantity_per_unit': 2, 'price_per_unit': 10}, inputs),
        closeTo(60, 1e-9),
      );
    });

    test('total cost sums every material', () {
      final materials = <Map<String, dynamic>>[
        {'quantity_per_unit': 2, 'price_per_unit': 10}, // 6 x 10 = 60
        {'quantity_formula': 'area', 'price_per_unit': 5}, // 3 x 5 = 15
      ];
      expect(CalcEngine.materialsTotalCost(materials, inputs),
          closeTo(75, 1e-9));
    });

    test('values stored as text or null do not crash', () {
      expect(
        CalcEngine.materialCost(
            {'quantity_per_unit': '2', 'price_per_unit': null}, inputs),
        0,
      );
    });
  });

  group('yieldOf', () {
    test('per-unit x area without a formula', () {
      expect(CalcEngine.yieldOf({'expected_yield': 2}, {'area': 3}),
          closeTo(6, 1e-9));
      expect(
        CalcEngine.yieldOf(
            {'expected_yield': 2, 'yield_formula': ''}, {'area': 3}),
        closeTo(6, 1e-9),
      );
    });

    test('formula overrides the per-unit rule', () {
      expect(
        CalcEngine.yieldOf(
            {'expected_yield': 2, 'yield_formula': 'area * 1.5'},
            {'area': 3}),
        closeTo(4.5, 1e-9),
      );
    });
  });
}
