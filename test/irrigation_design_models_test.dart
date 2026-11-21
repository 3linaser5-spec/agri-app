import 'package:flutter_test/flutter_test.dart';
import 'package:agri_app/models/irrigation_design_models.dart';

void main() {
  test('round-trips a complete irrigation project', () {
    final project = _project();
    final restored = IrrigationDesignProject.fromJson(project.toJson());

    expect(restored.id, project.id);
    expect(restored.siteBoundary.points, hasLength(4));
    expect(restored.plants.single.kc, 0.85);
    expect(restored.zones.single.designFlowLpm, 36);
    expect(restored.pump.efficiency, 0.72);
    expect(restored.version.toString(), '1.0.0-draft');
  });

  test('rejects invalid coordinates and unsupported boundary units', () {
    expect(
      () => GeoCoordinate.checked(latitude: 91, longitude: 31),
      throwsArgumentError,
    );
    expect(
      () => SiteBoundary(
        id: 'b',
        points: const [
          GeoCoordinate(latitude: 30, longitude: 31),
          GeoCoordinate(latitude: 30, longitude: 31.001),
          GeoCoordinate(latitude: 30.001, longitude: 31.001),
        ],
        areaUnit: 'acre',
      ),
      throwsArgumentError,
    );
  });
}

IrrigationDesignProject _project() {
  final boundary = SiteBoundary(
    id: 'boundary-1',
    nameAr: 'حد الحديقة',
    points: [
      GeoCoordinate(latitude: 30, longitude: 31),
      GeoCoordinate(latitude: 30, longitude: 31.001),
      GeoCoordinate(latitude: 30.001, longitude: 31.001),
      GeoCoordinate(latitude: 30.001, longitude: 31),
    ],
  );
  final plant = PlantSpecies(
    id: 'plant-1',
    nameAr: 'زيتون',
    kc: 0.85,
    salinityResistance: 0.7,
    droughtResistance: 0.8,
  );
  final equipment = IrrigationEquipment(
    id: 'rotor-1',
    nameAr: 'رشاش دوار',
    type: 'rotor',
    flowRateLpm: 12,
    operatingPressureBar: 2.5,
    quantity: 3,
  );
  final valve = Valve(
    id: 'valve-1',
    type: 'electric',
    zoneId: 'zone-1',
    diameterMm: 32,
  );
  final pipe = Pipe(
    id: 'main-1',
    material: 'PVC',
    diameter: 50,
    lengthM: 40,
  );
  final zone = IrrigationZone(
    id: 'zone-1',
    nameAr: 'المنطقة الأولى',
    method: 'rotor',
    plantId: plant.id,
    equipmentIds: [equipment.id],
    pipeIds: [pipe.id],
    valveIds: [valve.id],
    areaM2: 180,
    designFlowLpm: 36,
    applicationRateMmH: 8,
  );
  return IrrigationDesignProject(
    id: 'project-1',
    nameAr: 'حديقة اختبار',
    siteBoundary: boundary,
    plants: [plant],
    equipment: [equipment],
    pipes: [pipe],
    valves: [valve],
    zones: [zone],
    pump: Pump(
      id: 'pump-1',
      type: 'centrifugal',
      flowRateLpm: 36,
      headM: 32,
      powerKw: 2.2,
      efficiency: 0.72,
    ),
    version: DesignVersion(
      major: 1,
      minor: 0,
      patch: 0,
      label: 'draft',
      createdAt: DateTime.utc(2026, 11, 20),
    ),
  );
}
