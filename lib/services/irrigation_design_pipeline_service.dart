import '../engines/hydraulic_engine.dart';
import '../engines/irrigation_water_engine.dart';
import '../engines/pump_coverage_engine.dart';

class IrrigationPipelineInput {
  final double etoMmDay, kc, areaM2, efficiency, flowRateLpm, pipeDiameterM, pipeLengthM, pumpEfficiency;
  final List<PumpCurvePoint> pumpCurve;
  const IrrigationPipelineInput({required this.etoMmDay, required this.kc, required this.areaM2, required this.efficiency, required this.flowRateLpm, required this.pipeDiameterM, required this.pipeLengthM, required this.pumpEfficiency, required this.pumpCurve});
}

class IrrigationPipelineResult {
  final IrrigationWaterResult water;
  final HydraulicResult hydraulics;
  final PumpSelectionResult pump;
  final List<String> warnings;
  const IrrigationPipelineResult({required this.water, required this.hydraulics, required this.pump, required this.warnings});
  bool get valid => warnings.isEmpty;
}

class IrrigationDesignPipelineService {
  const IrrigationDesignPipelineService();
  IrrigationPipelineResult calculate(IrrigationPipelineInput input) {
    final water = IrrigationWaterEngine.calculate(etoMmDay:input.etoMmDay, kc:input.kc, areaM2:input.areaM2, efficiency:input.efficiency, flowRateLpm:input.flowRateLpm);
    final hydraulics = HydraulicEngine.calculate(flowM3s:input.flowRateLpm / 60000, diameterM:input.pipeDiameterM, lengthM:input.pipeLengthM, residualPressureHeadM:10);
    final pump = PumpCoverageEngine.selectPump(flowLpm:input.flowRateLpm, tdhM:hydraulics.totalDynamicHeadM, efficiency:input.pumpEfficiency, curve:input.pumpCurve);
    return IrrigationPipelineResult(water:water, hydraulics:hydraulics, pump:pump, warnings:List.unmodifiable([...hydraulics.warnings, ...pump.warnings]));
  }
}
