import 'package:flutter_test/flutter_test.dart';
import 'package:agri_app/models/irrigation_design_models.dart';
import 'package:agri_app/services/irrigation_export_service.dart';

void main() {
  test('exports a valid project as DXF, BOQ, and schedule', () {
    final bundle = const IrrigationExportService().export(_project());

    expect(bundle.dxf, contains('SECTION'));
    expect(bundle.dxf, contains('PUMP_STATION'));
    expect(bundle.dxf, contains('SPRAYS_POPUP'));
    expect(bundle.dxf, contains('MAINLINE_PIPES'));
    expect(bundle.dxf.trimRight().endsWith('EOF'), isTrue);
    expect(bundle.boq, isNotEmpty);
    expect(bundle.boqCsv, contains('category'));
    expect(bundle.boqJson, contains('pump'));
    expect(bundle.schedule.single.runtimeMinutes, closeTo(25, 1e-9));
  });

  test('exposes the bundle as a JSON snapshot', () {
    final json = IrrigationExportService.exportProject(_project()).toJson();

    expect(json['dxf'], contains('SECTION'));
    expect(json['boq'], isNotEmpty);
    expect(
      (json['schedule'] as List).single['runtime_minutes'],
      closeTo(25, 1e-9),
    );
  });

  test('never writes Infinity or NaN into the schedule CSV', () {
    final bundle = const IrrigationExportService().export(_project());

    expect(bundle.scheduleCsv.contains('Infinity'), isFalse);
    expect(bundle.scheduleCsv.contains('NaN'), isFalse);
    expect(bundle.schedule.single.runtimeMinutes.isFinite, isTrue);
  });

  test('caps an implausibly long runtime at one day', () {
    final base = _project();
    final project = IrrigationDesignProject(
      id: base.id,
      siteBoundary: base.siteBoundary,
      equipment: base.equipment,
      zones: [
        IrrigationZone(
          id: 'zone-1',
          method: 'spray',
          equipmentIds: ['spray-1'],
          areaM2: 100000,
          designFlowLpm: 1,
          applicationRateMmH: 8,
        ),
      ],
      pump: base.pump,
      version: base.version,
    );

    expect(
      const IrrigationExportService()
          .export(project)
          .schedule
          .single
          .runtimeMinutes,
      IrrigationExportService.maxRuntimeMinutes,
    );
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
    placements: [
      IrrigationMapPlacement(
        id: 'spray-placement-1',
        kind: 'spray',
        coordinate: const GeoCoordinate(latitude: 30, longitude: 31.0005),
        zoneId: 'zone-1',
      ),
    ],
    pipeRoutes: [
      IrrigationPipeRoute(
        id: 'main-route-1',
        points: const [
          GeoCoordinate(latitude: 30, longitude: 31),
          GeoCoordinate(latitude: 30, longitude: 31.0008),
        ],
        diameterMm: 50,
        material: 'PVC',
      ),
    ],
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
