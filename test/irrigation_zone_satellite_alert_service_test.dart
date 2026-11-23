import 'package:flutter_test/flutter_test.dart';
import 'package:agri_app/models/irrigation_design_models.dart';
import 'package:agri_app/services/irrigation_zone_satellite_alert_service.dart';

void main() {
  test('creates zone-linked alerts with field inspection coordinates', () {
    final project = IrrigationDesignProject(
      id: 'sat-project',
      siteBoundary: SiteBoundary(
        id: 'boundary',
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
          areaM2: 100,
          designFlowLpm: 30,
          applicationRateMmH: 8,
        ),
      ],
      pump: Pump(
        id: 'pump',
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
    final alerts = const IrrigationZoneSatelliteAlertService().analyze(
      project,
      zoneMetrics: {
        'zone-1': {'dryness': .8, 'salinity': .75, 'vegetation_health': .2},
      },
    );

    expect(alerts, hasLength(3));
    expect(alerts.every((alert) => alert.zoneId == 'zone-1'), isTrue);
    expect(alerts.every((alert) => alert.coordinate.latitude == 30.003333333333334), isTrue);
    expect(alerts.every((alert) => alert.fieldInspectionRequest.contains('فحص ميداني')), isTrue);
    expect(alerts.map((alert) => alert.toJson()), everyElement(isNot(contains('NASA'))));
  });
}
