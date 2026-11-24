import 'dart:math' as math;
import '../engines/pump_coverage_engine.dart';
import '../models/irrigation_design_models.dart';

class IrrigationZoneCoverageReport {
  final String zoneId;
  final CoverageResult coverage;
  final int irrigationElementCount;
  final int sampledPoints;
  final List<String> warnings;

  const IrrigationZoneCoverageReport({
    required this.zoneId,
    required this.coverage,
    required this.irrigationElementCount,
    required this.sampledPoints,
    required this.warnings,
  });
}

/// تحليل شبكي فعلي حسب مدى الرشاش واتجاهه وقطاعه والعوائق المرسومة.
/// يظل اختبار الضغط الميداني ضروريًا قبل التنفيذ النهائي.
class IrrigationCoverageAnalysisService {
  const IrrigationCoverageAnalysisService();
  static final Map<String, List<IrrigationZoneCoverageReport>> _cache = {};

  List<IrrigationZoneCoverageReport> analyze(
    IrrigationDesignProject project,
  ) {
    final key = _cacheKey(project);
    final cached = _cache[key];
    if (cached != null) return cached;
    final result = List.unmodifiable(project.zones.map((zone) => _analyzeZone(project, zone)));
    if (_cache.length >= 32) _cache.remove(_cache.keys.first);
    _cache[key] = result;
    return result;
  }

  static void clearCache() => _cache.clear();

  IrrigationZoneCoverageReport _analyzeZone(IrrigationDesignProject project, IrrigationZone zone) {
    final emitters = project.placements.where((p) => p.zoneId == zone.id && _isIrrigationElement(p.kind)).toList(growable: false);
    final obstacles = project.placements.where((p) => {'obstacle', 'building', 'wall', 'tree_canopy'}.contains(p.kind)).toList(growable: false);
    final samples = _sampleBoundary(project.siteBoundary.points, 48);
    final fractions = samples.map((sample) {
      var hits = 0;
      for (final emitter in emitters) {
        if (_covers(emitter, sample) && !_blocked(sample, emitter, obstacles)) hits++;
      }
      return hits.toDouble();
    }).toList(growable: false);
    final conflicts = <bool>[];
    for (var i = 0; i < emitters.length; i++) {
      for (var j = i + 1; j < emitters.length; j++) {
        conflicts.add(_distanceM(emitters[i].coordinate, emitters[j].coordinate) <
            (_radiusM(emitters[i].kind) + _radiusM(emitters[j].kind)) * .35);
      }
    }
    final coverage = PumpCoverageEngine.checkCoverage(
      areaM2: zone.areaM2,
      sampleCount: samples.length,
      coveredSampleFractions: fractions,
      conflicts: conflicts,
    );
    final warnings = <String>[];
    if (emitters.isEmpty) warnings.add('zone_has_no_irrigation_elements');
    if (coverage.dryAreaM2 > 0) warnings.add('dry_area_detected');
    if (coverage.overlapAreaM2 > 0) warnings.add('overlap_detected');
    if (coverage.conflicts.isNotEmpty) warnings.add('equipment_conflict');
    if (obstacles.isNotEmpty) warnings.add('obstacles_included_in_analysis');
    warnings.add('field_pressure_calibration_recommended');
    return IrrigationZoneCoverageReport(
      zoneId: zone.id,
      coverage: coverage,
      irrigationElementCount: emitters.length,
      sampledPoints: samples.length,
      warnings: List.unmodifiable(warnings),
    );
  }

  List<GeoCoordinate> _sampleBoundary(List<GeoCoordinate> boundary, int grid) {
    final minLat = boundary.map((p) => p.latitude).reduce((a, b) => math.min(a, b).toDouble());
    final maxLat = boundary.map((p) => p.latitude).reduce((a, b) => math.max(a, b).toDouble());
    final minLon = boundary.map((p) => p.longitude).reduce((a, b) => math.min(a, b).toDouble());
    final maxLon = boundary.map((p) => p.longitude).reduce((a, b) => math.max(a, b).toDouble());
    final points = <GeoCoordinate>[];
    for (var y = 0; y < grid; y++) {
      for (var x = 0; x < grid; x++) {
        final point = GeoCoordinate(latitude: minLat + (maxLat - minLat) * (y + .5) / grid, longitude: minLon + (maxLon - minLon) * (x + .5) / grid);
        if (_inside(point, boundary)) points.add(point);
      }
    }
    return points.isEmpty ? [boundary.first] : points;
  }

  bool _covers(IrrigationMapPlacement emitter, GeoCoordinate point) {
    final distance = _distanceM(emitter.coordinate, point);
    final radius = _radiusM(emitter.kind);
    if (distance > radius) return false;
    if (emitter.kind == 'drip' || emitter.kind == 'bubbler') return distance <= radius * .55;
    final bearing = math.atan2(point.longitude - emitter.coordinate.longitude, point.latitude - emitter.coordinate.latitude) * 180 / math.pi;
    final delta = ((bearing - emitter.rotationDegrees + 540) % 360) - 180;
    final sector = emitter.kind == 'rotor' ? 180.0 : 55.0;
    return delta.abs() <= sector / 2;
  }

  bool _blocked(GeoCoordinate point, IrrigationMapPlacement emitter, List<IrrigationMapPlacement> obstacles) => obstacles.any((obstacle) => _distanceM(point, obstacle.coordinate) < math.min(2.0, _radiusM(emitter.kind) * .25));

  bool _inside(GeoCoordinate point, List<GeoCoordinate> polygon) {
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final yi = polygon[i].latitude, yj = polygon[j].latitude;
      final xi = polygon[i].longitude, xj = polygon[j].longitude;
      final intersects = ((yi > point.latitude) != (yj > point.latitude)) && (point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi + 1e-12) + xi);
      if (intersects) inside = !inside;
    }
    return inside;
  }

  bool _isIrrigationElement(String kind) =>
      {'rotor', 'spray', 'drip', 'bubbler', 'micro_spray'}.contains(kind);

  double _radiusM(String kind) => switch (kind) {
        'rotor' => 12,
        'spray' => 7,
        'micro_spray' => 4,
        'bubbler' => 2,
        'drip' => 3,
        _ => 0,
      };

  double _distanceM(GeoCoordinate a, GeoCoordinate b) {
    const earthRadius = 6371000.0;
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLat = lat2 - lat1;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLon / 2), 2);
    return 2 * earthRadius * math.asin(math.sqrt(h));
  }

  String _cacheKey(IrrigationDesignProject project) => '${project.id}:${project.version}:${project.placements.map((p) => '${p.id}:${p.coordinate.latitude}:${p.coordinate.longitude}:${p.rotationDegrees}').join('|')}';
}
