import 'package:flutter_test/flutter_test.dart';
import 'package:agri_app/models/irrigation_design_models.dart';
import 'package:agri_app/services/irrigation_export_service.dart';

void main() {
  test('exports a valid project as DXF, BOQ, and schedule', () {
    final bundle = const IrrigationExportService().export(_project());

    expect(bundle.dxf, contains('SECTION'));
    expect(bundle.dxf, contains('PUMP_STATION'));
    expect(bundle.dxf.trimRight().endsWith('EOF'), isTrue);
    expect(bundle.boq, isNotEmpty);
    expect(bundle.boqCsv, contains('category'));
    expect(bundle.boqJson, contains('pump'));
    expect(bundle.schedule.single.runtimeMinutes, closeTo(25, 1e-9));
  });

  test('rejects a zone that references a missing equipment item', () {
    final project = _project().zones.single;
    final invalid = IrrigationDesignProject(
      id: 'invalid',
      siteBoundary: _project().siteBoundary,
      zones: [
        IrrigationZone(
          id: project.id,
          method: project.method,
          equipmentIds: const ['missing-equipment'],
          areaM2: project.areaM2,
          designFlowLpm: project.designFlowLpm,
          applicationRateMmH: project.applicationRateMmH,
        ),
      ],
      pump: _project().pump,
      version: _project().version,
    );

    expect(
      () => const IrrigationExportService().export(invalid),
      throwsA(isA<IrrigationExportValidationException>()),
    );
  });
}

IrrigationDesignProject _project() {
  final boundary = SiteBoundary(
    id: 'boundary-1',
    points: const [
      GeoCoordinate(latitude: 30, longitude: 31),
      GeoCoordinate(latitude: 30, longitude: 31.001),
      GeoCoordinate(latitude: 30.001, longitude: 31.001),
    ],
  );
  final equipment = IrrigationEquipment(
    id: 'spray-1',
    type: 'spray',
    flowRateLpm: 12,
    operatingPressureBar: 2,
  );
  return IrrigationDesignProject(
    id: 'project-1',
    siteBoundary: boundary,
    equipment: [equipment],
    zones: [
      IrrigationZone(
        id: 'zone-1',
        method: 'spray',
        equipmentIds: [equipment.id],
        areaM2: 100,
        designFlowLpm: 20,
        applicationRateMmH: 8,
      ),
    ],
    pump: Pump(
      id: 'pump-1',
      type: 'centrifugal',
      flowRateLpm: 20,
      headM: 25,
      powerKw: 1.5,
      efficiency: 0.7,
    ),
    version: DesignVersion(
      major: 1,
      minor: 0,
      patch: 0,
      createdAt: DateTime.utc(2026, 11, 20),
    ),
  );
}
