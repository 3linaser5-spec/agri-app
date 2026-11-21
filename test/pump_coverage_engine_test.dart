import 'package:flutter_test/flutter_test.dart';
import 'package:agri_app/engines/pump_coverage_engine.dart';

void main() {
  test('interpolates pump curve and reports operating point', () {
    final result = PumpCoverageEngine.selectPump(
      flowLpm: 60,
      tdhM: 25,
      efficiency: .72,
      curve: const [PumpCurvePoint(flowLpm: 0, headM: 40), PumpCurvePoint(flowLpm: 100, headM: 20)],
    );
    expect(result.withinCurve, isTrue);
    expect(result.adequateHead, isTrue);
    expect(result.hydraulicPowerKw, greaterThan(0));
  });

  test('calculates dry area and conflicts', () {
    final result = PumpCoverageEngine.checkCoverage(areaM2: 100, sampleCount: 4, coveredSampleFractions: [1, 1, 0, 1], conflicts: [true, false, false, false]);
    expect(result.coveredAreaM2, 75);
    expect(result.dryAreaM2, 25);
    expect(result.conflicts, contains('obstacle_or_plant_conflict'));
  });
}
