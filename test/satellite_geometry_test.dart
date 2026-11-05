import 'package:flutter_test/flutter_test.dart';
import 'package:agri_app/services/satellite_access_service.dart';

void main() {
  const square = <Map<String, double>>[
    {'lat': 24.0, 'lng': 32.0},
    {'lat': 24.0, 'lng': 32.001},
    {'lat': 24.001, 'lng': 32.001},
    {'lat': 24.001, 'lng': 32.0},
  ];

  test('مساحة مربع صغيرة تكون موجبة وتحويل الفدان متسق', () {
    final squareMeters = SatelliteGeometry.areaSquareMeters(square);
    final feddans = SatelliteGeometry.areaFeddan(square);

    expect(squareMeters, greaterThan(0));
    expect(feddans, closeTo(squareMeters / 4200.833, 0.000001));
  });

  test('عكس اتجاه ترتيب الحدود لا يغير المساحة', () {
    final reversed = square.reversed.toList(growable: false);

    expect(
      SatelliteGeometry.areaSquareMeters(reversed),
      closeTo(SatelliteGeometry.areaSquareMeters(square), 0.001),
    );
  });

  test('أقل من ثلاث نقاط لا تمثل مساحة', () {
    expect(SatelliteGeometry.areaSquareMeters(square.take(2).toList()), 0);
    expect(SatelliteGeometry.areaFeddan(const []), 0);
  });
}
