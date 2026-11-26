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
    final result = List<IrrigationZoneCoverageReport>.unmodifiable(
      project.zones.map((zone) => _analyzeZone(project, zone)),
    );
    if (_cache.length >= 32) _cache.remove(_cache.keys.first);
    _cache[key] = result;
    return result;
  }

  static void clearCache() => _cache.clear();

  IrrigationZoneCoverageReport _analyzeZone(IrrigationDesignProject project, IrrigationZone zone) {
    final emitters = project.placements.where((p) => p.zoneId == zone.id && _isIrrigationElement(p.kind)).toList(growable: false);
    final obstacles = project.placements.where((p) => {'obstacle', 'building', 'wall', 'tree_canopy'}.contains(p.kind)).toList(growable: false);
    final center = _zoneCenter(project, emitters);
    final samples = _sampleArea(zone.areaM2, center, _cellSizeM(emitters));
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

  /// مركز المنطقة: متوسط مواضع الرشاشات، أو متوسط حدود الموقع إن لم توجد
  /// رشاشات (المنطقة لا تحمل مضلعًا خاصًا بها في الموديل).
  GeoCoordinate _zoneCenter(
    IrrigationDesignProject project,
    List<IrrigationMapPlacement> emitters,
  ) {
    final source = emitters.isEmpty
        ? project.siteBoundary.points
        : emitters.map((e) => e.coordinate).toList(growable: false);
    final lat = source.fold<double>(0, (s, p) => s + p.latitude) / source.length;
    final lon = source.fold<double>(0, (s, p) => s + p.longitude) / source.length;
    return GeoCoordinate(latitude: lat, longitude: lon);
  }

  /// خطوة الشبكة: لا تتجاوز ثلث أصغر مدى رشّ حتى لا تفوت أهداف صغيرة.
  double _cellSizeM(List<IrrigationMapPlacement> emitters) {
    final radii = emitters
        .map((e) => _radiusM(e.kind))
        .where((r) => r > 0)
        .toList(growable: false);
    if (radii.isEmpty) return 2;
    return math.max(radii.reduce(math.min) / 3, 0.5);
  }

  /// عيّنات شبكية داخل مربع مساحته مساحة المنطقة ومركزه مركزها.
  /// كانت العيّنات سابقًا تُوزّع على حدود الموقع كله، فتمسح مساحة المنطقة
  /// الحقيقية وتُظهر تغطية أقل من الواقع بفارق كبير.
  List<GeoCoordinate> _sampleArea(
    double areaM2,
    GeoCoordinate center,
    double cellM,
  ) {
    final halfSideM = math.sqrt(math.max(areaM2, 1)) / 2;
    // سقف 96 نقطة لكل اتجاه (9216 نقطة) بدل 160×160 = 25600 نقطة، لأن
    // التحليل بيتنفذ على الـ UI thread و26 ألف حساب يسبب تقطيعًا واضحًا.
    final steps = (2 * halfSideM / cellM).ceil().clamp(24, 96);
    final stepM = 2 * halfSideM / steps;
    const metersPerDegreeLat = 111320.0;
    final metersPerDegreeLon = math.max(
      metersPerDegreeLat * math.cos(center.latitude * math.pi / 180),
      1,
    );
    final points = <GeoCoordinate>[];
    for (var y = 0; y < steps; y++) {
      for (var x = 0; x < steps; x++) {
        final dLat = -halfSideM + (y + .5) * stepM;
        final dLon = -halfSideM + (x + .5) * stepM;
        points.add(GeoCoordinate(
          latitude: center.latitude + dLat / metersPerDegreeLat,
          longitude: center.longitude + dLon / metersPerDegreeLon,
        ));
      }
    }
    return points;
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

  /// مفتاح الكاش لازم يشمل كل ما يدخل في الحساب: حدود الموقع، مساحة المنطقة
  /// ومعدل تصرفها ونوع الرشّ، ونوع كل عنصر وخريطته ومساره. لو مساحة منطقة
  /// اتغيرت من غير ما يتغير عدد العناصر، النتيجة القديمة كانت بتفضل معروضة.
  String _cacheKey(IrrigationDesignProject project) => [
        project.id,
        '${project.version.major}.${project.version.minor}.${project.version.patch}',
        project.siteBoundary.points
            .map((p) => '${p.latitude},${p.longitude}')
            .join(';'),
        project.zones
            .map((z) => '${z.id}:${z.areaM2}:${z.designFlowLpm}:${z.method}')
            .join('|'),
        project.placements
            .map((p) =>
                '${p.id}:${p.kind}:${p.zoneId}:${p.coordinate.latitude}:${p.coordinate.longitude}:${p.rotationDegrees}')
            .join('|'),
      ].join('#');
}
