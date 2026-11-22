import 'package:flutter_test/flutter_test.dart';
import 'package:agri_app/models/irrigation_design_models.dart';
import 'package:agri_app/services/irrigation_route_hydraulics_service.dart';

void main() {
  test('calculates route friction loss and total dynamic head', () {
    final route = IrrigationPipeRoute(
      id: 'route-1',
      points: const [
        GeoCoordinate(latitude: 30, longitude: 31),
        GeoCoordinate(latitude: 30, longitude: 31.002),
      ],
      diameterMm: 50,
      material: 'PVC',
      designFlowLpm: 300,
    );
    final result = const IrrigationRouteHydraulicsService().analyzeRoute(route);

    expect(result.lengthM, greaterThan(180));
    expect(result.hydraulic.pipeFrictionHeadM, greaterThan(0));
    expect(result.hydraulic.totalDynamicHeadM, greaterThan(10));
    expect(result.hydraulic.warnings, contains('velocity_above_warning'));
  });
}
