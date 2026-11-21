class PumpCurvePoint {
  final double flowLpm;
  final double headM;
  const PumpCurvePoint({required this.flowLpm, required this.headM});
}

class PumpSelectionResult {
  final double operatingFlowLpm;
  final double requiredHeadM;
  final double hydraulicPowerKw;
  final bool withinCurve;
  final bool adequateHead;
  final List<String> warnings;
  const PumpSelectionResult({required this.operatingFlowLpm, required this.requiredHeadM, required this.hydraulicPowerKw, required this.withinCurve, required this.adequateHead, required this.warnings});
}

class CoverageResult {
  final double coveredAreaM2;
  final double dryAreaM2;
  final double overlapAreaM2;
  final List<String> conflicts;
  const CoverageResult({required this.coveredAreaM2, required this.dryAreaM2, required this.overlapAreaM2, required this.conflicts});
  bool get acceptable => dryAreaM2 <= 0 && conflicts.isEmpty;
}

class PumpCoverageEngine {
  PumpCoverageEngine._();

  static PumpSelectionResult selectPump({required double flowLpm, required double tdhM, required double efficiency, required List<PumpCurvePoint> curve, double safetyFactor = 1.1}) {
    _positive(flowLpm, 'flowLpm'); _positive(tdhM, 'tdhM'); _range(efficiency, 'efficiency', 0.01, 1); _positive(safetyFactor, 'safetyFactor');
    final required = tdhM * safetyFactor;
    final points = [...curve]..sort((a,b) => a.flowLpm.compareTo(b.flowLpm));
    if (points.length < 2) throw ArgumentError.value(curve, 'curve', 'requires at least two points');
    final within = flowLpm >= points.first.flowLpm && flowLpm <= points.last.flowLpm;
    double head = points.first.headM;
    for (var i = 1; i < points.length; i++) { if (flowLpm <= points[i].flowLpm) { final a=points[i-1], b=points[i]; final t=(flowLpm-a.flowLpm)/(b.flowLpm-a.flowLpm); head=a.headM+(b.headM-a.headM)*t; break; } }
    final warnings=<String>[]; if (!within) warnings.add('flow_outside_pump_curve'); if (head < required) warnings.add('insufficient_head'); if (efficiency < .5) warnings.add('low_efficiency');
    final power = 998.2*9.80665*(flowLpm/60000)*tdhM/efficiency/1000;
    return PumpSelectionResult(operatingFlowLpm: flowLpm, requiredHeadM: required, hydraulicPowerKw: power, withinCurve: within, adequateHead: head >= required, warnings: List.unmodifiable(warnings));
  }

  static CoverageResult checkCoverage({required double areaM2, required int sampleCount, required List<double> coveredSampleFractions, List<bool> conflicts = const []}) {
    _positive(areaM2, 'areaM2'); if (sampleCount < 1 || coveredSampleFractions.length != sampleCount) throw ArgumentError.value(sampleCount, 'sampleCount', 'must match samples');
    final dry = coveredSampleFractions.where((x) => x <= 0).length / sampleCount * areaM2;
    final covered = areaM2 - dry;
    final overlap = coveredSampleFractions.where((x) => x > 1).fold<double>(0, (s,x)=>s+(x-1))/sampleCount*areaM2;
    final conflictCodes = conflicts
        .map((e) => e ? 'obstacle_or_plant_conflict' : '')
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    return CoverageResult(coveredAreaM2: covered, dryAreaM2: dry, overlapAreaM2: overlap, conflicts: List.unmodifiable(conflictCodes));
  }
  static void _positive(num x,String n){if(!x.isFinite||x<=0)throw ArgumentError.value(x,n,'must be positive');}
  static void _range(num x,String n,double a,double b){if(!x.isFinite||x<a||x>b)throw ArgumentError.value(x,n,'out of range');}
}
