import 'package:flutter_test/flutter_test.dart';

import 'package:agri_app/models/irrigation_design_models.dart';
import 'package:agri_app/services/design_comparison_service.dart';

IrrigationDesignProject design({
  List<IrrigationPipeRoute> routes = const [],
  List<IrrigationZone> zones = const [],
  List<Pipe> pipes = const [],
  double? declaredArea,
}) =>
    IrrigationDesignProject(
      id: 'p',
      siteBoundary: SiteBoundary(
        id: 'b',
        declaredArea: declaredArea,
        points: const [
          GeoCoordinate(latitude: 30, longitude: 31),
          GeoCoordinate(latitude: 30, longitude: 31.01),
          GeoCoordinate(latitude: 30.01, longitude: 31.01),
        ],
      ),
      zones: zones,
      pipes: pipes,
      pipeRoutes: routes,
      pump: Pump(
        id: 'pump',
        type: 'centrifugal',
        flowRateLpm: 10,
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

void main() {
  test('pipe route lengths are added to the bill of quantities length', () {
    final snapshot = const DesignComparisonService().snapshot(design(
      declaredArea: 1000,
      routes: [
        IrrigationPipeRoute(
          id: 'route-1',
          points: const [
            GeoCoordinate(latitude: 30, longitude: 31),
            GeoCoordinate(latitude: 30, longitude: 31.001),
          ],
          diameterMm: 32,
          material: 'PE',
        ),
      ],
    ));
    // 0.001 درجة طول عند خط عرض 30 ≈ 96 مترًا.
    expect(snapshot.totalPipeMeters, greaterThan(90));
    expect(snapshot.totalPipeMeters, lessThan(100));
  });

  test('a design with no zones or cost items is still summarised', () {
    final snapshot = const DesignComparisonService().snapshot(design());
    expect(snapshot.zones, 0);
    expect(snapshot.totalFlowLpm, 0);
    expect(snapshot.averageApplicationRateMmH, 0);
    expect(snapshot.estimatedCost, greaterThan(0)); // سعر المضخة الافتراضي
    // المساحة تُقدَّر من الحدود، فتكون المياه اليومية رقمًا موجبًا.
    expect(snapshot.dailyWaterM3, greaterThan(0));
  });

  test('zero area does not divide by zero in the snapshot', () {
    final snapshot = const DesignComparisonService().snapshot(design());
    expect(snapshot.areaM2, greaterThan(0));
    expect(snapshot.costPerM2.isFinite, isTrue);
  });

  test('percentage difference is 100 when the base value is zero', () {
    const row = ComparisonRow(
      label: 'اختبار',
      unit: 'م',
      valueA: 0,
      valueB: 50,
    );
    expect(row.percentDifference, 100);
    const bothZero = ComparisonRow(
      label: 'اختبار',
      unit: 'م',
      valueA: 0,
      valueB: 0,
    );
    expect(bothZero.percentDifference, 0);
    expect(bothZero.better, 'tie');
  });

  test('lower-is-better rows pick the smaller value', () {
    const row = ComparisonRow(
      label: 'تكلفة',
      unit: 'ج.م',
      valueA: 500,
      valueB: 400,
      higherIsBetter: false,
    );
    expect(row.better, 'b');
    expect(row.difference, -100);
  });
}
