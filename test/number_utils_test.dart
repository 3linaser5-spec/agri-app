import 'package:agri_app/utils/number_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
