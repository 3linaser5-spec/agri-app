import 'dart:math' as math;
import '../models/irrigation_design_models.dart';

class IrrigationPipeRouteResult {
  final String routeId;
  final double lengthM;
  final double velocityMps;
  final bool velocityWithinTypicalRange;

  const IrrigationPipeRouteResult({
    required this.routeId,
    required this.lengthM,
    required this.velocityMps,
    required this.velocityWithinTypicalRange,
  });
}

class IrrigationPipeRouteService {
  const IrrigationPipeRouteService();

  IrrigationPipeRouteResult analyze(IrrigationPipeRoute route) {
    final length = _lengthM(route.points);
    final flowM3s = (route.designFlowLpm ?? 0) / 60000;
    final diameterM = route.diameterMm / 1000;
    final area = math.pi * diameterM * diameterM / 4;
    final velocity = area == 0 ? 0.0 : flowM3s / area;
    return IrrigationPipeRouteResult(
      routeId: route.id,
      lengthM: length,
      velocityMps: velocity,
      velocityWithinTypicalRange: velocity == 0 || (velocity >= .3 && velocity <= 2.5),
    );
  }

  double _lengthM(List<GeoCoordinate> points) {
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += _distanceM(points[i - 1], points[i]);
    }
    return total;
  }

  double _distanceM(GeoCoordinate a, GeoCoordinate b) {
    const earthRadiusM = 6371000.0;
    final lat1 = _radians(a.latitude);
    final lat2 = _radians(b.latitude);
    final dLat = lat2 - lat1;
    final dLon = _radians(b.longitude - a.longitude);
    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLon / 2), 2);
    return 2 * earthRadiusM * math.asin(math.sqrt(h));
  }

  double _radians(double degrees) => degrees * math.pi / 180;
}
