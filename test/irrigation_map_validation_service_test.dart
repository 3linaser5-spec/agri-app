import 'package:flutter_test/flutter_test.dart';
import 'package:agri_app/models/irrigation_design_models.dart';
import 'package:agri_app/services/irrigation_map_validation_service.dart';

void main() {
  IrrigationDesignProject projectWith(List<IrrigationMapPlacement> placements) {
    final plant = PlantSpecies(
      id: 'plant-1',
      kc: .8,
      salinityResistance: .7,
      droughtResistance: .7,
    );
    const points = [
      GeoCoordinate(latitude: 30, longitude: 31),
      GeoCoordinate(latitude: 30, longitude: 31.01),
      GeoCoordinate(latitude: 30.01, longitude: 31.01),
      GeoCoordinate(latitude: 30.01, longitude: 31),
    ];
    return IrrigationDesignProject(
      id: 'project-1',
      siteBoundary: SiteBoundary(id: 'boundary-1', points: points),
      plants: [plant],
      zones: [
        IrrigationZone(
          id: 'zone-1',
          method: 'rotor',
          areaM2: 100,
          designFlowLpm: 20,
          applicationRateMmH: 8,
        ),
      ],
      pump: Pump(
        id: 'pump-1',
        type: 'centrifugal',
        flowRateLpm: 20,
        headM: 20,
        powerKw: 1,
        efficiency: .7,
      ),
      placements: placements,
      version: DesignVersion(
        major: 1,
        minor: 0,
        patch: 0,
        createdAt: DateTime(2026, 1, 1),
      ),
    );
  }

  test('flags missing zone and unknown zone links', () {
    final issues = const IrrigationMapValidationService().validate(
      projectWith([
        IrrigationMapPlacement(
          id: 'sprinkler-1',
          kind: 'rotor',
          coordinate: GeoCoordinate(latitude: 30.005, longitude: 31.005),
        ),
        IrrigationMapPlacement(
          id: 'valve-1',
          kind: 'valve',
          coordinate: GeoCoordinate(latitude: 30.005, longitude: 31.005),
          zoneId: 'missing-zone',
        ),
      ]),
    );
    expect(issues.map((issue) => issue.code), containsAll([
      'missing_zone',
      'unknown_zone',
    ]));
  });

  test('flags placements outside the site boundary', () {
    final issues = const IrrigationMapValidationService().validate(
      projectWith([
        IrrigationMapPlacement(
          id: 'plant-1',
          kind: 'plant',
          coordinate: GeoCoordinate(latitude: 31, longitude: 32),
        ),
      ]),
    );
    expect(issues.single.code, 'outside_boundary');
  });
}
