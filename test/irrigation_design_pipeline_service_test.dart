import 'package:flutter_test/flutter_test.dart';
import 'package:agri_app/engines/pump_coverage_engine.dart';
import 'package:agri_app/services/irrigation_design_pipeline_service.dart';

void main() {
  test('runs water, hydraulic and pump calculations together', () {
    final result = const IrrigationDesignPipelineService().calculate(IrrigationPipelineInput(etoMmDay:5, kc:.8, areaM2:100, efficiency:.8, flowRateLpm:60, pipeDiameterM:.1, pipeLengthM:40, pumpEfficiency:.72, pumpCurve:[PumpCurvePoint(flowLpm:0, headM:50), PumpCurvePoint(flowLpm:100, headM:25)]));
    expect(result.water.dailyVolumeM3, greaterThan(0));
    expect(result.hydraulics.totalDynamicHeadM, greaterThan(0));
    expect(result.pump.hydraulicPowerKw, greaterThan(0));
  });
}
