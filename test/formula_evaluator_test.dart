import 'package:agri_app/utils/formula_evaluator.dart';
import 'package:flutter_test/flutter_test.dart';

double? eval(String formula, [Map<String, double> vars = const {}]) =>
    FormulaEvaluator.evaluate(formula, vars);

void main() {
  group('evaluate: arithmetic', () {
    test('uses template variables', () {
      expect(eval('area * 50', {'area': 2.0}), closeTo(100, 1e-9));
    });

    test('multiplication binds tighter than addition', () {
      expect(eval('2 + 3 * 4'), closeTo(14, 1e-9));
    });

    test('parentheses override precedence', () {
      expect(eval('(2 + 3) * 4'), closeTo(20, 1e-9));
    });

    test('subtraction and division are left associative', () {
      expect(eval('10 - 3 - 2'), closeTo(5, 1e-9));
      expect(eval('100 / 5 / 2'), closeTo(10, 1e-9));
    });

    test('unary minus and plus', () {
      expect(eval('-3 + 5'), closeTo(2, 1e-9));
      expect(eval('2 - -3'), closeTo(5, 1e-9));
      expect(eval('-(1 + 2)'), closeTo(-3, 1e-9));
      expect(eval('+4'), closeTo(4, 1e-9));
    });

    test('decimals, including a leading dot', () {
      expect(eval('0.5 * 4'), closeTo(2, 1e-9));
      expect(eval('.5 * 4'), closeTo(2, 1e-9));
    });

    test('whitespace is ignored', () {
      expect(eval('  2 +   3  '), closeTo(5, 1e-9));
    });

    test('identifiers may contain digits and underscores', () {
      expect(eval('seed_rate2 * 2', {'seed_rate2': 3.0}), closeTo(6, 1e-9));
    });
  });

  group('evaluate: functions', () {
    test('min and max', () {
      expect(eval('min(3, 2)'), closeTo(2, 1e-9));
      expect(eval('max(area, 1) * 12', {'area': 0.5}), closeTo(12, 1e-9));
    });

    test('round, ceil, floor, abs', () {
      expect(eval('ceil(area * 2.5)', {'area': 3.0}), closeTo(8, 1e-9));
      expect(eval('floor(2.9)'), closeTo(2, 1e-9));
      expect(eval('round(2.5)'), closeTo(3, 1e-9));
      expect(eval('abs(-4)'), closeTo(4, 1e-9));
    });
  });

  group('evaluate: Arabic input', () {
    test('Arabic-Indic digits', () {
      expect(eval('٣ * ٢'), closeTo(6, 1e-9));
    });

    test('Arabic decimal separator', () {
      expect(eval('٣٫٥ * 2'), closeTo(7, 1e-9));
    });

    test('multiplication and division signs', () {
      expect(eval('6 ÷ 3 × 2'), closeTo(4, 1e-9));
    });
  });

  group('evaluate: invalid input returns null instead of throwing', () {
    test('division by zero', () {
      expect(eval('5 / 0'), isNull);
      expect(eval('x / (y - 1)', {'x': 4.0, 'y': 1.0}), isNull);
    });

    test('unknown variable', () {
      expect(eval('area * foo', {'area': 2.0}), isNull);
    });

    test('unknown function and wrong argument count', () {
      expect(eval('sqrt(4)'), isNull);
      expect(eval('min(1)'), isNull);
      expect(eval('min(1, 2, 3)'), isNull);
      expect(eval('abs()'), isNull);
    });

    test('syntax errors', () {
      expect(eval(''), isNull);
      expect(eval('   '), isNull);
      expect(eval('2 +'), isNull);
      expect(eval('2 3'), isNull);
      expect(eval('(1 + 2'), isNull);
      expect(eval('()'), isNull);
      expect(eval('2 * * 3'), isNull);
      expect(eval('1..2'), isNull);
      expect(eval('min(3 2)'), isNull);
    });

    test('characters that could be code are rejected', () {
      expect(eval('area; print(1)', {'area': 1.0}), isNull);
      expect(eval('area ** 2', {'area': 2.0}), isNull);
      expect(eval('"a"'), isNull);
      expect(eval('a.b', {'a': 1.0}), isNull);
    });

    test('result that is not finite', () {
      expect(eval('big * big', {'big': 1e200}), isNull);
    });
  });

  group('evaluate: limits', () {
    test('formula longer than the limit is rejected', () {
      final tooLong = '${'1+' * 101}1'; // 203 chars
      expect(tooLong.length, greaterThan(FormulaEvaluator.maxLength));
      expect(eval(tooLong), isNull);
    });

    test('long formula under the limit is accepted', () {
      final ok = '1${'+1' * 99}'; // 199 chars, value 100
      expect(ok.length, lessThanOrEqualTo(FormulaEvaluator.maxLength));
      expect(eval(ok), closeTo(100, 1e-9));
    });

    test('moderate nesting is accepted, extreme nesting is rejected', () {
      expect(eval('${'(' * 20}1${')' * 20}'), closeTo(1, 1e-9));
      expect(eval('${'(' * 30}1${')' * 30}'), isNull);
    });
  });

  group('validate', () {
    test('accepts a valid formula', () {
      expect(FormulaEvaluator.validate('area * 2', {'area'}), isNull);
    });

    test('blank formula means "no formula" and is valid', () {
      expect(FormulaEvaluator.validate('', {'area'}), isNull);
      expect(FormulaEvaluator.validate('   ', {'area'}), isNull);
    });

    test('reports unknown variables and lists the available ones', () {
      final msg = FormulaEvaluator.validate('area * foo', {'area', 'rate'});
      expect(msg, isNotNull);
      expect(msg, contains('foo'));
      expect(msg, contains('rate'));
    });

    test('rejects a formula that always divides by zero', () {
      expect(FormulaEvaluator.validate('5 / 0', {'area'}), isNotNull);
    });

    test('accepts x / (y - 1): only some inputs make it divide by zero', () {
      expect(FormulaEvaluator.validate('x / (y - 1)', {'x', 'y'}), isNull);
    });

    test('rejects bad syntax, wrong arity and over-long formulas', () {
      expect(FormulaEvaluator.validate('2 +', {'area'}), isNotNull);
      expect(FormulaEvaluator.validate('min(1)', {'area'}), isNotNull);
      expect(FormulaEvaluator.validate('${'1+' * 101}1', {'area'}), isNotNull);
    });
  });
}
