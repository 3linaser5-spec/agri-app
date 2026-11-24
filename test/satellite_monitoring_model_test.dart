import 'package:flutter_test/flutter_test.dart';

import 'package:agri_app/models/satellite_monitoring_model.dart';

void main() {
  group('HlsField', () {
    test('parses the polygon and computes the area in meters and feddans', () {
      final field = HlsField.fromData('field-1', {
        'name': '  حقل الزيتون ',
        'crop': 'زيتون',
        'planting_date': '2026-01-15T00:00:00.000Z',
        'linked_program_id': 'program-1',
        'polygon': [
          {'lat': 30, 'lon': 31},
          {'lat': 30, 'lon': 31.001},
          {'lat': 30.001, 'lon': 31.001},
          {'lat': 30.001, 'lon': 31},
        ],
      });

      expect(field.id, 'field-1');
      expect(field.name, 'حقل الزيتون');
      expect(field.crop, 'زيتون');
      expect(field.linkedProgramId, 'program-1');
      expect(field.polygon, hasLength(4));
      expect(field.areaSquareMeters, inInclusiveRange(10000, 11500));
      expect(
        field.areaHectares,
        closeTo(field.areaSquareMeters / 10000, 1e-9),
      );
      expect(field.areaFeddans, closeTo(field.areaSquareMeters / 4200, 1e-9));
    });

    test('handles missing names and polygons without throwing', () {
      final field = HlsField.fromData('field-2', {
        'name': '   ',
        'polygon': 'bad',
      });

      expect(field.name, 'حقل بدون اسم');
      expect(field.crop, '');
      expect(field.polygon, isEmpty);
      expect(field.areaSquareMeters, 0);
    });

    test('copyWith removes the linked program only when asked', () {
      final field = HlsField.fromData('field-3', {
        'name': 'حقل',
        'linked_program_id': 'program-3',
      });

      expect(field.copyWith(crop: 'قمح').linkedProgramId, 'program-3');
      expect(
        field.copyWith(clearLinkedProgram: true).linkedProgramId,
        isNull,
      );
    });
  });

  test('HlsCoordinate tolerates malformed input', () {
    final coordinate = HlsCoordinate.fromMap({'latitude': '30.5', 'lon': 'x'});

    expect(coordinate.latitude, 30.5);
    expect(coordinate.longitude, 0);
    expect(HlsCoordinate.fromMap('bad').latitude, 0);
    expect(coordinate.toMap(), {'lat': 30.5, 'lon': 0});
  });

  group('HlsSamplePoint', () {
    test('keeps numeric indices and bands only', () {
      final point = HlsSamplePoint.fromMap({
        'id': 'p1',
        'latitude': '30.25',
        'longitude': 31.25,
        'indices': {'ndvi': 0.6, 'broken': 'x', 'infinite': double.infinity},
        'bands': {'nir': '0.4'},
        'qa': {
          'fmask': {'cloud': false, 'snow': false},
          'not-a-map': 'x',
        },
        'fmask': 4.0,
      });

      expect(point.id, 'p1');
      expect(point.latitude, 30.25);
      expect(point.longitude, 31.25);
      expect(point.indices, {'ndvi': 0.6});
      expect(point.bands, {'nir': 0.4});
      expect(point.qa.keys, ['fmask']);
      expect(point.fmask, 4);
      expect(point.toMap()['fmask'], 4);
    });

    test('non-map input produces safe defaults', () {
      final point = HlsSamplePoint.fromMap(null);

      expect(point.id, '');
      expect(point.indices, isEmpty);
      expect(point.qa, isEmpty);
      expect(point.fmask, isNull);
    });
  });

  group('HlsObservation', () {
    test('parses metrics, samples, counts and sources', () {
      final observation = HlsObservation.fromData('obs-1', {
        'date': '2026-11-20T00:00:00.000Z',
        'metrics': {'ndvi': '0.62', 'bad': 'x'},
        'bands': {'red': 0.1},
        'samples': [
          {'id': 's1', 'latitude': 30, 'longitude': 31},
          'bad',
        ],
        'valid_sample_count': '3',
        'total_sample_count': 4,
        'sources': ['sentinel-2', 7],
        'quality': {'cloudy': false},
        'alerts': ['low_ndvi'],
      });

      expect(observation.id, 'obs-1');
      expect(observation.date, DateTime.utc(2026, 11, 20));
      expect(observation.metrics, {'ndvi': 0.62});
      expect(observation.bands, {'red': 0.1});
      expect(observation.samples, hasLength(1));
      expect(observation.validSampleCount, 3);
      expect(observation.totalSampleCount, 4);
      expect(observation.sources, ['sentinel-2', '7']);
      expect(observation.quality, {'cloudy': false});
      expect(observation.alerts, ['low_ndvi']);
    });

    test('falls back when the document body is empty', () {
      final observation = HlsObservation.fromData('obs-2', const {});

      expect(observation.samples, isEmpty);
      expect(observation.metrics, isEmpty);
      expect(observation.validSampleCount, 0);
      expect(observation.alerts, isEmpty);
    });
  });

  group('HlsAnalysisRun and HlsFieldNote', () {
    test('analysis runs default to an unknown status', () {
      final run = HlsAnalysisRun.fromData('run-1', const {});

      expect(run.status, 'unknown');
      expect(run.samplePointCount, 0);
      expect(run.sources, isEmpty);
      expect(run.requestedAt, isNull);
    });

    test('analysis runs parse dates and sentinel status', () {
      final run = HlsAnalysisRun.fromData('run-2', {
        'status': 'completed',
        'requested_at': '2026-11-19T08:00:00.000Z',
        'sample_point_count': '5',
        'observation_count': 2,
        'sentinel2_10m_status': 'ready',
        'sentinel2_10m_error_message': null,
      });

      expect(run.status, 'completed');
      expect(run.requestedAt, DateTime.utc(2026, 11, 19, 8));
      expect(run.samplePointCount, 5);
      expect(run.observationCount, 2);
      expect(run.sentinel2Status, 'ready');
    });

    test('field notes keep text, category and date', () {
      final note = HlsFieldNote.fromData('note-1', {
        'text': 'رشة وقائية',
        'category': 'pest',
        'created_at': '2026-11-18T12:00:00.000Z',
      });

      expect(note.text, 'رشة وقائية');
      expect(note.category, 'pest');
      expect(note.createdAt, DateTime.utc(2026, 11, 18, 12));
      expect(HlsFieldNote.fromData('note-2', const {}).text, '');
    });
  });
}
