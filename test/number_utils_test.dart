import 'package:agri_app/utils/number_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalize and parse', () {
    test('normalizes Arabic-Indic and Persian digits', () {
      expect(NumberUtils.normalize('٠١٢٣٤٥٦٧٨٩'), '0123456789');
      expect(NumberUtils.normalize('۱۲۳'), '123');
      expect(NumberUtils.tryParseInt('١٢٣'), 123);
      expect(NumberUtils.tryParseDouble('١٢٫٥'), 12.5);
    });

    test('treats a three-digit comma group as a thousands separator', () {
      expect(NumberUtils.tryParseInt('1,500'), 1500);
      expect(NumberUtils.tryParseDouble('1,500'), 1500);
      expect(NumberUtils.tryParseDouble('1,5'), 1.5);
    });

    test('strips spaces and Arabic decimal separators', () {
      expect(NumberUtils.tryParseDouble(' 2 · 5 '.replaceAll('·', '٫')), 2.5);
      expect(NumberUtils.tryParseDouble('3،25'), 3.25);
    });

    test('returns null for empty and non-numeric input', () {
      expect(NumberUtils.normalize(''), '');
      expect(NumberUtils.tryParseDouble(null), isNull);
      expect(NumberUtils.tryParseDouble('   '), isNull);
      expect(NumberUtils.tryParseInt('abc'), isNull);
    });
  });

  group('normalizeEgyptianMobile', () {
    test('normalizes local Arabic-Indic digits', () {
      expect(NumberUtils.normalizeEgyptianMobile('٠١٠١٢٣٤٥٦٧٨'), '01012345678');
    });

    test('maps supported international forms to one local identity', () {
      for (final number in [
        '01012345678',
        '+201012345678',
        '00201012345678',
        '201012345678',
      ]) {
        expect(NumberUtils.normalizeEgyptianMobile(number), '01012345678');
      }
    });

    test('rejects incomplete and non-Egyptian mobile numbers', () {
      expect(NumberUtils.normalizeEgyptianMobile('010123'), isNull);
      expect(NumberUtils.normalizeEgyptianMobile('+14155552671'), isNull);
    });

    test(
      'retains the legacy spelling needed for existing international logins',
      () {
        expect(
          NumberUtils.legacyEgyptianMobile('+201012345678'),
          '+201012345678',
        );
        expect(NumberUtils.legacyEgyptianMobile('01012345678'), isNull);
      },
    );
  });
}
