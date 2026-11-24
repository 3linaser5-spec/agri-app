import 'package:flutter_test/flutter_test.dart';

import 'package:agri_app/utils/safe_parse.dart';

void main() {
  group('SafeParse.string', () {
    test('converts whole numbers without a trailing .0', () {
      expect(SafeParse.string(7.0), '7');
      expect(SafeParse.string(7.25), '7.25');
      expect(SafeParse.string(7), '7');
    });

    test('keeps null as the fallback', () {
      expect(SafeParse.string(null), '');
      expect(SafeParse.string(null, 'غير معروف'), 'غير معروف');
      expect(SafeParse.string('نص'), 'نص');
    });

    test('stringOrNull keeps nulls and stringifies the rest', () {
      expect(SafeParse.stringOrNull(null), isNull);
      expect(SafeParse.stringOrNull(12), '12');
    });
  });

  group('SafeParse numbers', () {
    test('integer accepts int, double, English and Arabic text', () {
      expect(SafeParse.integer(5), 5);
      expect(SafeParse.integer(5.9), 5);
      expect(SafeParse.integer(' 42 '), 42);
      expect(SafeParse.integer('١٢٣'), 123);
      expect(SafeParse.integer('1,500'), 1500);
      expect(SafeParse.integer('abc', 9), 9);
      expect(SafeParse.integer(null), 0);
    });

    test('doubleOrNull accepts decimals and rejects junk', () {
      expect(SafeParse.doubleOrNull(3), 3.0);
      expect(SafeParse.doubleOrNull('2.5'), 2.5);
      expect(SafeParse.doubleOrNull('٢٫٥'), 2.5);
      expect(SafeParse.doubleOrNull('  '), isNull);
      expect(SafeParse.doubleOrNull('abc'), isNull);
      expect(SafeParse.doubleOrNull(null), isNull);
    });

    test('decimal falls back when the value is not numeric', () {
      expect(SafeParse.decimal('4.5'), 4.5);
      expect(SafeParse.decimal('nope'), 0);
      expect(SafeParse.decimal('nope', 1.5), 1.5);
    });
  });

  group('SafeParse maps', () {
    test('map ignores non-map values and stringifies keys', () {
      expect(SafeParse.map(null), isEmpty);
      expect(SafeParse.map('x'), isEmpty);
      expect(SafeParse.map({1: 'a', 'b': 2}), {'1': 'a', 'b': 2});
    });

    test('stringMap converts every value to text', () {
      expect(SafeParse.stringMap({'a': 1, 'b': null}), {
        'a': '1',
        'b': '',
      });
      expect(SafeParse.stringMap(5), isEmpty);
    });

    test('mapList drops non-map entries instead of throwing', () {
      final parsed = SafeParse.mapList([
        {'id': 'a'},
        'junk',
        3,
        {'id': 'b'},
      ]);
      expect(parsed, [
        {'id': 'a'},
        {'id': 'b'},
      ]);
      expect(SafeParse.mapList('x'), isEmpty);
    });

    test('stringMapList converts and filters entries', () {
      final parsed = SafeParse.stringMapList([
        {'count': 2},
        null,
      ]);
      expect(parsed, [
        {'count': '2'},
      ]);
      expect(SafeParse.stringMapList(null), isEmpty);
    });
  });
}
