import 'package:flutter_test/flutter_test.dart';
import 'package:agri_app/models/satellite_monitoring_model.dart';

void main() {
  group('HlsField geometry', () {
    test('computes a positive approximate area for a small farm polygon', () {
      final field = HlsField(
        id: 'field-1',
        name: 'حقل اختبار',
        crop: 'قمح',
        plantingDate: DateTime(2026, 1, 1),
        polygon: const [
          HlsCoordinate(latitude: 30.0, longitude: 31.0),
          HlsCoordinate(latitude: 30.0, longitude: 31.001),
          HlsCoordinate(latitude: 30.001, longitude: 31.001),
          HlsCoordinate(latitude: 30.001, longitude: 31.0),
        ],
      );

      expect(field.areaSquareMeters, greaterThan(9000));
      expect(field.areaSquareMeters, lessThan(14000));
      expect(field.areaFeddans, closeTo(field.areaSquareMeters / 4200, 1e-8));
    });
  });

  group('HlsSamplePoint parsing', () {
    test('parses numeric metrics, bands, and quality value', () {
      final sample = HlsSamplePoint.fromMap({
        'id': 'p3',
        'latitude': 30.1,
        'longitude': 31.2,
        'indices': {'NDVI': 0.62, 'NDMI': '0.21'},
        'bands': {'B04': 0.11},
        'qa': {
          'HLSS30': {'clear': true, 'water': true, 'aerosolCode': 1},
          'HLSL30': {'clear': false, 'cloud': true},
        },
        'fmask': 32,
      });

      expect(sample.id, 'p3');
      expect(sample.indices['NDVI'], 0.62);
      expect(sample.indices['NDMI'], 0.21);
      expect(sample.bands['B04'], 0.11);
      expect(sample.qa['HLSS30']?['water'], isTrue);
      expect(sample.qa['HLSL30']?['cloud'], isTrue);
      expect(sample.fmask, 32);
    });

    test('drops non-finite values and tolerates a malformed sample', () {
      final sample = HlsSamplePoint.fromMap({
        'id': 'p1',
        'latitude': 'NaN',
        'longitude': null,
        'indices': {'NDVI': double.nan, 'EVI': '0.4'},
      });

      expect(sample.latitude, 0);
      expect(sample.longitude, 0);
      expect(sample.indices.containsKey('NDVI'), isFalse);
      expect(sample.indices['EVI'], 0.4);
    });
  });
}
