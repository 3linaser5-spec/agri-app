import 'package:flutter_test/flutter_test.dart';
import 'package:agri_app/models/irrigation_design_models.dart';
import 'package:agri_app/services/irrigation_operations_service.dart';

void main() {
  IrrigationDesignProject project() => IrrigationDesignProject(
        id: 'ops-project',
        siteBoundary: SiteBoundary(
          id: 'boundary',
          points: const [
            GeoCoordinate(latitude: 30, longitude: 31),
            GeoCoordinate(latitude: 30, longitude: 31.01),
            GeoCoordinate(latitude: 30.01, longitude: 31.01),
          ],
        ),
        valves: [
          Valve(id: 'valve-1', type: 'zone', diameterMm: 50),
        ],
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

  test('creates QR-linked tasks for valves, zones and pump', () {
    final tasks = const IrrigationOperationsService().buildMaintenancePlan(
      project(),
      startAt: DateTime(2026, 1, 1),
    );
    expect(tasks.map((task) => task.assetId), containsAll([
      'valve-1',
      'zone-1',
      'pump-1',
    ]));
    expect(tasks.every((task) => task.qrCode!.startsWith('irrigation://')), isTrue);
  });

  test('creates an as-built record with installed project data', () {
    final record = const IrrigationOperationsService().createAsBuilt(
      project: project(),
      recordedBy: 'field-user',
      recordedAt: DateTime(2026, 1, 2),
      installedChanges: {'valve-1': 'moved 2m'},
    );
    expect(record.projectId, 'ops-project');
    expect(record.installedChanges['overrides'], containsPair('valve-1', 'moved 2m'));
    expect(const IrrigationOperationsService().maintenanceCsv(const []).trim(),
        'id,project_id,asset_id,title,priority,status,due_at,qr_code');
  });
}
