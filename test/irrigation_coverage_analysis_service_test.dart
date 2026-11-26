import 'package:flutter_test/flutter_test.dart';
import 'package:agri_app/models/irrigation_design_models.dart';
import 'package:agri_app/services/irrigation_coverage_analysis_service.dart';

void main() {
  IrrigationDesignProject projectWith(
    List<IrrigationMapPlacement> placements,
  ) {
    final zone = IrrigationZone(
      id: 'zone-1',
      method: 'rotor',
      areaM2: 200,
      designFlowLpm: 30,
      applicationRateMmH: 8,
    );
    return IrrigationDesignProject(
      id: 'project-1',
      siteBoundary: SiteBoundary(
        id: 'boundary-1',
        points: const [
          GeoCoordinate(latitude: 30, longitude: 31),
          GeoCoordinate(latitude: 30, longitude: 31.01),
          GeoCoordinate(latitude: 30.01, longitude: 31.01),
        ],
      ),
      zones: [zone],
      placements: placements,
      pump: Pump(
        id: 'pump-1',
        type: 'centrifugal',
        flowRateLpm: 30,
        headM: 20,
        powerKw: 1,
        efficiency: .7,
      ),
      version: DesignVersion(
        major: 1,
        minor: 0,
        patch: 0,
        createdAt: DateTime(2026, 1, 1),
      ),
    );
  }

  test('reports dry area when a zone has no irrigation elements', () {
    final report = const IrrigationCoverageAnalysisService()
        .analyze(projectWith(const []))
        .single;
    expect(report.coverage.dryAreaM2, 200);
    expect(report.warnings, contains('zone_has_no_irrigation_elements'));
  });

  test('does not reuse a cached report after the zone area changes', () {
    IrrigationDesignProject withArea(double area) => IrrigationDesignProject(
          id: 'project-cache',
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
              method: 'rotor',
              areaM2: area,
              designFlowLpm: 30,
              applicationRateMmH: 8,
            ),
          ],
          pump: Pump(
            id: 'pump-1',
            type: 'centrifugal',
            flowRateLpm: 30,
            headM: 20,
            powerKw: 1,
            efficiency: .7,
          ),
          version: DesignVersion(
            major: 1,
            minor: 0,
            patch: 0,
            createdAt: DateTime(2026, 1, 1),
          ),
        );

    final first = const IrrigationCoverageAnalysisService().analyze(withArea(200)).single;
    final second = const IrrigationCoverageAnalysisService().analyze(withArea(800)).single;

    expect(first.coverage.dryAreaM2, 200);
    expect(second.coverage.dryAreaM2, 800);
  });

  test('reports coverage for placed irrigation elements', () {
    final report = const IrrigationCoverageAnalysisService().analyze(
      projectWith([
        IrrigationMapPlacement(
          id: 'rotor-1',
          kind: 'rotor',
          coordinate: const GeoCoordinate(latitude: 30.005, longitude: 31.005),
          zoneId: 'zone-1',
        ),
        IrrigationMapPlacement(
          id: 'rotor-2',
          kind: 'rotor',
          coordinate: const GeoCoordinate(latitude: 30.005, longitude: 31.005),
          zoneId: 'zone-1',
        ),
      ]),
    ).single;
    expect(report.coverage.coveredAreaM2, greaterThan(0));
    expect(report.coverage.dryAreaM2, greaterThan(0));
    expect(report.coverage.conflicts, isNotEmpty);
    expect(report.warnings, contains('equipment_conflict'));
    expect(report.sampledPoints, greaterThan(1));
  });
}
