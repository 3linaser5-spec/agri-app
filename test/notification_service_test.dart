import 'package:flutter_test/flutter_test.dart';

import 'package:agri_app/services/notification_service.dart';

void main() {
  test('two notifications in the same second get different ids', () {
    final now = DateTime(2026, 11, 26, 10, 30, 15);

    final first = NotificationService.nextNotificationId(now);
    final second = NotificationService.nextNotificationId(now);

    expect(second, greaterThan(first));
  });

  test('notification ids keep growing over time', () {
    final first = NotificationService.nextNotificationId(DateTime(2026, 11, 26, 10));
    final later =
        NotificationService.nextNotificationId(DateTime(2026, 11, 26, 11));

    expect(later, greaterThan(first));
  });
}
