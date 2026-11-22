import 'package:flutter_test/flutter_test.dart';
import 'package:agri_app/models/irrigation_design_models.dart';
import 'package:agri_app/services/irrigation_pipe_route_service.dart';

void main() {
  test('calculates route length and hydraulic velocity', () {
    final route = IrrigationPipeRoute(
      id: 'main-1',
      points: const [
        GeoCoordinate(latitude: 30, longitude: 31),
        GeoCoordinate(latitude: 30, longitude: 31.001),
      ],
      diameterMm: 100,
      material: 'PE',
      designFlowLpm: 60,
    );
    final result = const IrrigationPipeRouteService().analyze(route);

    expect(result.lengthM, greaterThan(90));
    expect(result.lengthM, lessThan(100));
    expect(result.velocityMps, closeTo(0.127, 0.01));
    expect(result.velocityWithinTypicalRange, isFalse);
  });
}
