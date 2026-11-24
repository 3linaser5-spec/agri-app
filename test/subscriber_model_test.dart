import 'package:flutter_test/flutter_test.dart';

import 'package:agri_app/models/subscriber_model.dart';

void main() {
  group('ActiveSubscriber.fromData', () {
    test('parses the current field names', () {
      final subscriber = ActiveSubscriber.fromData('uid-1', {
        'name': ' أحمد ',
        'phone': '01012345678',
        'plan': 'مراقبة المحاصيل',
        'max_area_feddan': 10,
        'used_area_feddan': '4.5',
        'expires_at': '2026-12-31T00:00:00.000Z',
        'status': 'active',
      });

      expect(subscriber.uid, 'uid-1');
      expect(subscriber.name, 'أحمد');
      expect(subscriber.areaLimitFeddans, 10);
      expect(subscriber.usedAreaFeddans, 4.5);
      expect(subscriber.remainingAreaFeddans, 5.5);
      expect(subscriber.usageRatio, closeTo(0.45, 1e-9));
      expect(subscriber.expiresAt, DateTime.utc(2026, 12, 31));
    });

    test('accepts the legacy field aliases', () {
      final subscriber = ActiveSubscriber.fromData('uid-2', {
        'max_area_feddans': 6,
        'used_area': 2,
        'expiry_date': '2027-01-01',
      });

      expect(subscriber.areaLimitFeddans, 6);
      expect(subscriber.usedAreaFeddans, 2);
      expect(subscriber.expiresAt, DateTime.parse('2027-01-01'));
    });

    test('falls back for missing or malformed values', () {
      final subscriber = ActiveSubscriber.fromData('uid-3', const {});

      expect(subscriber.name, 'مشترك');
      expect(subscriber.phone, '');
      expect(subscriber.plan, 'مراقبة المحاصيل');
      expect(subscriber.areaLimitFeddans, 0);
      expect(subscriber.usageRatio, 0);
      expect(subscriber.remainingAreaFeddans, 0);
      expect(subscriber.expiresAt, isNull);
      expect(subscriber.status, 'active');
    });
  });

  test('remaining area never goes negative and usage is capped at one', () {
    final subscriber = ActiveSubscriber.fromData('uid-4', {
      'max_area_feddan': 3,
      'used_area_feddan': 5,
    });

    expect(subscriber.remainingAreaFeddans, 0);
    expect(subscriber.usageRatio, 1);
  });
}
