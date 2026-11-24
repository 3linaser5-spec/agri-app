import 'dart:math' as math;
import '../engines/pump_coverage_engine.dart';
import '../models/irrigation_design_models.dart';

class IrrigationZoneCoverageReport {
  final String zoneId;
  final CoverageResult coverage;
  final int irrigationElementCount;
  final List<String> warnings;

  const IrrigationZoneCoverageReport({
    required this.zoneId,
    required this.coverage,
    required this.irrigationElementCount,
    required this.warnings,
  });
}

/// فحص تغطية تقديري من توزيع العناصر. يعتمد على مساحة تأثير اسمية،
/// ويجب معايرته ببيانات الشركة وتجربة ميدانية قبل اعتماده للتنفيذ.
class IrrigationCoverageAnalysisService {
  const IrrigationCoverageAnalysisService();

  List<IrrigationZoneCoverageReport> analyze(
    IrrigationDesignProject project,
  ) {
    return List.unmodifiable(project.zones.map((zone) {
      final elements = project.placements.where((placement) =>
          placement.zoneId == zone.id && _isIrrigationElement(placement.kind));
      final elementsList = elements.toList(growable: false);
      final nominalCoveredArea = elementsList.fold<double>(
        0,
        (sum, element) => sum + _nominalArea(element.kind),
      );
      final fraction = zone.areaM2 <= 0
          ? 0.0
          : nominalCoveredArea / zone.areaM2;
      final conflicts = <bool>[];
      for (var i = 0; i < elementsList.length; i++) {
        for (var j = i + 1; j < elementsList.length; j++) {
          conflicts.add(_distanceM(
                elementsList[i].coordinate,
                elementsList[j].coordinate,
              ) <
              _conflictDistanceM(elementsList[i].kind, elementsList[j].kind));
        }
      }
      final coverage = PumpCoverageEngine.checkCoverage(
        areaM2: zone.areaM2,
        sampleCount: 1,
        coveredSampleFractions: [fraction],
        conflicts: conflicts,
      );
      final warnings = <String>[
        'preliminary_coverage_requires_field_calibration',
      ];
      if (elementsList.isEmpty) warnings.add('zone_has_no_irrigation_elements');
      if (coverage.dryAreaM2 > 0) warnings.add('dry_area_detected');
      if (coverage.overlapAreaM2 > 0) warnings.add('overlap_detected');
      if (coverage.conflicts.isNotEmpty) warnings.add('equipment_conflict');
      return IrrigationZoneCoverageReport(
        zoneId: zone.id,
        coverage: coverage,
        irrigationElementCount: elementsList.length,
        warnings: List.unmodifiable(warnings),
      );
    }));
  }

  bool _isIrrigationElement(String kind) =>
      {'rotor', 'spray', 'drip', 'bubbler', 'micro_spray'}.contains(kind);

  double _nominalArea(String kind) => switch (kind) {
        'rotor' => 120,
        'spray' => 40,
        'micro_spray' => 25,
        'bubbler' => 12,
        'drip' => 20,
        _ => 0,
      };

  double _conflictDistanceM(String first, String second) =>
      (_radiusM(first) + _radiusM(second)) * .35;

  double _radiusM(String kind) => switch (kind) {
        'rotor' => 6,
        'spray' => 3.5,
        'micro_spray' => 2.5,
        'bubbler' => 1.5,
        'drip' => 2,
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
}
