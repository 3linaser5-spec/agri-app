import 'package:flutter_test/flutter_test.dart';

import 'package:agri_app/models/map_alert_model.dart';

void main() {
  group('MapAlert.fromData', () {
    test('reads nested coordinates and parses the creation date', () {
      final alert = MapAlert.fromData('alert-1', {
        'field_id': 'field-1',
        'zone_id': 'zone-1',
        'title': 'إجهاد مائي',
        'message': 'انخفاض NDWI',
        'coordinates': {'lat': 30.5, 'lon': '31.25'},
        'severity': 'high',
        'created_at': '2026-11-20T10:00:00.000Z',
      });

      expect(alert.id, 'alert-1');
      expect(alert.fieldId, 'field-1');
      expect(alert.zoneId, 'zone-1');
      expect(alert.title, 'إجهاد مائي');
      expect(alert.latitude, 30.5);
      expect(alert.longitude, 31.25);
      expect(alert.severity, 'high');
      expect(alert.status, 'open');
      expect(alert.resolved, isFalse);
      expect(alert.createdAt, DateTime.utc(2026, 11, 20, 10));
    });

    test('falls back to safe defaults for missing or wrong types', () {
      final alert = MapAlert.fromData('alert-2', {
        'coordinates': 'bad',
        'latitude': 'not-a-number',
        'resolved': true,
      });

      expect(alert.title, 'تنبيه فحص');
      expect(alert.fieldId, '');
      expect(alert.latitude, 0);
      expect(alert.longitude, 0);
      expect(alert.severity, 'medium');
      expect(alert.status, 'resolved');
      expect(alert.resolved, isTrue);
      expect(alert.createdAt, isNull);
      expect(alert.inspectionResult, isNull);
    });

    test('accepts the legacy inspection note field', () {
      final alert = MapAlert.fromData('alert-3', {
        'inspection_note': 'تم الفحص',
      });

      expect(alert.inspectionResult, 'تم الفحص');
    });
  });

  test('copyWith replaces only the inspection result', () {
    final alert = MapAlert.fromData('alert-4', {
      'field_id': 'field-4',
      'severity': 'low',
      'inspection_result': 'قديم',
    });

    final updated = alert.copyWith(inspectionResult: 'جديد');

    expect(updated.inspectionResult, 'جديد');
    expect(updated.id, alert.id);
    expect(updated.fieldId, 'field-4');
    expect(updated.severity, 'low');
    expect(alert.inspectionResult, 'قديم');
  });
}
