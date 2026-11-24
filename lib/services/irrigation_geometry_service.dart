import '../models/irrigation_design_models.dart';

/// حسابات هندسية خفيفة للحدود قبل استخدام محرك GIS متخصص.
class IrrigationGeometryService {
  const IrrigationGeometryService();

  double areaM2(List<GeoCoordinate> points) {
    if (points.length < 3) return 0;
    const metersPerDegree = 111320.0;
    final meanLatitude =
        points.fold<double>(0, (sum, point) => sum + point.latitude) /
            points.length;
    final longitudeScale =
        metersPerDegree * _cosDegrees(meanLatitude);
    var sum = 0.0;
    for (var i = 0; i < points.length; i++) {
      final a = points[i];
      final b = points[(i + 1) % points.length];
      final ax = a.longitude * longitudeScale;
      final bx = b.longitude * longitudeScale;
      final ay = a.latitude * metersPerDegree;
      final by = b.latitude * metersPerDegree;
      sum += ax * by - bx * ay;
    }
    return sum.abs() / 2;
  }

  double areaFeddan(List<GeoCoordinate> points) => areaM2(points) / 4200;

  double _cosDegrees(double degrees) {
    final radians = degrees * 3.141592653589793 / 180;
    // Taylor approximation is sufficient for the small geographic areas here.
    final x2 = radians * radians;
    return 1 - x2 / 2 + x2 * x2 / 24 - x2 * x2 * x2 / 720;
  }
}
