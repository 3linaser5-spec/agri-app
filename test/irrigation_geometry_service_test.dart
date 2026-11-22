import 'package:flutter_test/flutter_test.dart';
import 'package:agri_app/models/irrigation_design_models.dart';
import 'package:agri_app/services/irrigation_geometry_service.dart';

void main() {
  test('calculates a square area and converts it to feddan', () {
    const service = IrrigationGeometryService();
    final points = [
      const GeoCoordinate(latitude: 30, longitude: 31),
      const GeoCoordinate(latitude: 30, longitude: 31.001),
      const GeoCoordinate(latitude: 30.001, longitude: 31.001),
      const GeoCoordinate(latitude: 30.001, longitude: 31),
    ];

    final area = service.areaM2(points);
    expect(area, greaterThan(9000));
    expect(area, lessThan(11000));
    expect(service.areaFeddan(points), closeTo(area / 4200, 0.000001));
  });

  test('returns zero for an incomplete boundary', () {
    const service = IrrigationGeometryService();
    expect(service.areaM2(const []), 0);
  });
}
