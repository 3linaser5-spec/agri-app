import 'package:flutter_test/flutter_test.dart';
import 'package:agri_app/models/irrigation_design_models.dart';
import 'package:agri_app/services/irrigation_zone_hydraulic_report_service.dart';

void main() {
  test('recommends a stronger pump when flow is insufficient', () {
    final zone = IrrigationZone(
      id: 'zone-1',
      method: 'rotor',
      areaM2: 100,
      designFlowLpm: 80,
      applicationRateMmH: 8,
    );
    final project = IrrigationDesignProject(
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
      pump: Pump(
        id: 'pump-1',
        type: 'centrifugal',
        flowRateLpm: 40,
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
    final report = const IrrigationZoneHydraulicReportService().build(project);

    expect(report.single.pumpAdequate, isFalse);
    expect(report.single.recommendations, isNotEmpty);
  });
}
