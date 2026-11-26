import 'package:flutter_test/flutter_test.dart';

import 'package:agri_app/models/irrigation_design_models.dart';
import 'package:agri_app/services/design_comparison_service.dart';

void main() {
  IrrigationDesignProject project({
    required String id,
    double? declaredArea = 1000,
    double pipeLength = 100,
    double flow = 40,
  }) =>
      IrrigationDesignProject(
        id: id,
        nameAr: 'تصميم $id',
        siteBoundary: SiteBoundary(
          id: 'boundary-$id',
          declaredArea: declaredArea,
          points: const [
            GeoCoordinate(latitude: 30, longitude: 31),
            GeoCoordinate(latitude: 30, longitude: 31.01),
            GeoCoordinate(latitude: 30.01, longitude: 31.01),
            GeoCoordinate(latitude: 30.01, longitude: 31),
          ],
        ),
        pipes: [
          Pipe(
            id: 'pipe-$id',
            material: 'PE',
            diameter: 32,
            lengthM: pipeLength,
          ),
        ],
        valves: [
          Valve(id: 'valve-$id', type: 'ball', diameterMm: 50),
        ],
        equipment: [
          IrrigationEquipment(
            id: 'eq-$id',
            type: 'dripper',
            flowRateLpm: 4,
            operatingPressureBar: 1,
            quantity: 2,
          ),
        ],
        plants: [
          PlantSpecies(
            id: 'plant-$id',
            kc: 1,
            salinityResistance: .5,
            droughtResistance: .5,
          ),
        ],
        zones: [
          IrrigationZone(
            id: 'zone-1-$id',
            method: 'drip',
            areaM2: (declaredArea ?? 1000) / 2,
            designFlowLpm: flow / 2,
            applicationRateMmH: 4,
          ),
          IrrigationZone(
            id: 'zone-2-$id',
            method: 'drip',
            areaM2: (declaredArea ?? 1000) / 2,
            designFlowLpm: flow / 2,
            applicationRateMmH: 6,
          ),
        ],
        pump: Pump(
          id: 'pump-$id',
          type: 'centrifugal',
          flowRateLpm: flow,
          headM: 25,
          powerKw: 2,
          efficiency: .7,
        ),
        version: DesignVersion(
          major: 1,
          minor: 0,
          patch: 0,
          createdAt: DateTime(2026, 1, 1),
        ),
      );

  test('builds a snapshot from design quantities', () {
    final snapshot = const DesignComparisonService().snapshot(project(id: 'a'));
    expect(snapshot.areaM2, 1000);
    expect(snapshot.zones, 2);
    expect(snapshot.totalFlowLpm, 40);
    expect(snapshot.averageApplicationRateMmH, 5);
    expect(snapshot.totalPipeMeters, 100);
    expect(snapshot.valves, 1);
    expect(snapshot.equipment, 2);
    expect(snapshot.dailyWaterM3, closeTo(5, 1e-9));
    // 100م×60 + محبس 350 + معدات 2×45 + نبات 25 + مضخة 15000
    expect(snapshot.estimatedCost, closeTo(6000 + 350 + 90 + 25 + 15000, .01));
  });

  test('cost per square metre stays finite for a design without an area', () {
    final snapshot = const DesignComparisonService()
        .snapshot(project(id: 'a', declaredArea: null));
    // بدون مساحة معلنة تُقدَّر المساحة من إحداثيات الحدود.
    expect(snapshot.areaM2, greaterThan(0));
    expect(snapshot.costPerM2.isFinite, isTrue);
  });

  test('comparison marks the cheaper and smaller design as better', () {
    final result = const DesignComparisonService().compare(
      project(id: 'a', pipeLength: 200, flow: 60, declaredArea: 1200),
      project(id: 'b', pipeLength: 100, flow: 40, declaredArea: 1000),
    );
    expect(result.a.name, 'تصميم a');
    expect(result.b.name, 'تصميم b');
    final cost = result.rows.firstWhere((row) => row.label == 'التكلفة التقديرية');
    expect(cost.better, 'b');
    expect(cost.percentDifference, lessThan(0));
    final area = result.rows.firstWhere((row) => row.label == 'المساحة');
    expect(area.better, 'a'); // مساحة أكبر أفضل
    final flowRow = result.rows.firstWhere((row) => row.label == 'التصرف الكلي');
    expect(flowRow.better, 'b'); // تصرف أقل أفضل
  });

  test('identical designs tie on every row', () {
    final result = const DesignComparisonService().compare(
      project(id: 'a'),
      project(id: 'b'),
    );
    for (final row in result.rows) {
      expect(row.better, 'tie', reason: row.label);
      expect(row.percentDifference, 0);
    }
  });

  test('custom rates change the estimated cost', () {
    const cheap = DesignCostRates(pipeMeterPrice: 10, pumpPrice: 0);
    final snapshot =
        const DesignComparisonService().snapshot(project(id: 'a'), rates: cheap);
    expect(snapshot.estimatedCost, closeTo(1000 + 350 + 90 + 25, .01));
  });
}
