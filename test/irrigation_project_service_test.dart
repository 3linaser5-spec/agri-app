import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agri_app/models/irrigation_design_models.dart';
import 'package:agri_app/services/irrigation_project_service.dart';

void main() {
  IrrigationDesignProject project({String nameAr = 'مزرعة الزيتون'}) =>
      IrrigationDesignProject(
        id: 'project-1',
        nameAr: nameAr,
        siteBoundary: SiteBoundary(
          id: 'boundary-1',
          points: const [
            GeoCoordinate(latitude: 30, longitude: 31),
            GeoCoordinate(latitude: 30, longitude: 31.01),
            GeoCoordinate(latitude: 30.01, longitude: 31.01),
          ],
        ),
        zones: [
          IrrigationZone(
            id: 'zone-1',
            method: 'drip',
            areaM2: 500,
            designFlowLpm: 20,
            applicationRateMmH: 4,
          ),
        ],
        placements: [
          IrrigationMapPlacement(
            id: 'drip-1',
            kind: 'drip',
            coordinate: const GeoCoordinate(latitude: 30.005, longitude: 31.005),
            zoneId: 'zone-1',
          ),
        ],
        pump: Pump(
          id: 'pump-1',
          type: 'centrifugal',
          flowRateLpm: 20,
          headM: 25,
          powerKw: 1.5,
          efficiency: .7,
        ),
        version: DesignVersion(
          major: 2,
          minor: 1,
          patch: 0,
          createdAt: DateTime.utc(2026, 11, 20),
        ),
      );

  test('writes the owner and the full project into the document', () {
    final document = IrrigationProjectService.toDocument(
      ownerId: 'user-1',
      project: project(),
    );

    expect(document['owner_id'], 'user-1');
    expect(document['name_ar'], 'مزرعة الزيتون');
    expect(document['project'], isA<Map<String, dynamic>>());
    expect((document['project'] as Map)['zones'], hasLength(1));
  });

  test('reads a saved document back into a project', () {
    final document = IrrigationProjectService.toDocument(
      ownerId: 'user-1',
      project: project(),
    )..['updated_at'] = Timestamp.fromDate(DateTime.utc(2026, 11, 25, 9));

    final saved = IrrigationProjectService.fromDocument('doc-1', document);

    expect(saved.documentId, 'doc-1');
    expect(saved.name, 'مزرعة الزيتون');
    expect(saved.updatedAt!.toUtc(), DateTime.utc(2026, 11, 25, 9));
    expect(saved.project.zones.single.areaM2, 500);
    expect(saved.project.placements.single.kind, 'drip');
    expect(saved.project.version.major, 2);
  });

  test('falls back to the project name when no stored name exists', () {
    final document = IrrigationProjectService.toDocument(
      ownerId: 'user-1',
      project: project(),
    )..['name_ar'] = '   ';

    expect(
      IrrigationProjectService.fromDocument('doc-2', document).name,
      'مزرعة الزيتون',
    );
  });

  test('rejects a document without project data', () {
    expect(
      () => IrrigationProjectService.fromDocument('doc-3', {
        'owner_id': 'user-1',
        'name_ar': 'مشروع',
      }),
      throwsA(isA<IrrigationProjectException>()),
    );
  });
}
