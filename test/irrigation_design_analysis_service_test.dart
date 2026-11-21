import 'package:flutter_test/flutter_test.dart';
import 'package:agri_app/models/irrigation_design_models.dart';
import 'package:agri_app/services/irrigation_design_analysis_service.dart';

void main() {
  test('analyzes cost, scenarios, and maintenance plan', () {
    final p = _project();
    final result = const IrrigationDesignAnalysisService().analyze(p, unitCosts: {'PVC': 3, 'electric': 100, 'rotor': 25}, weeklyWaterM3: 20, pumpPowerKw: 2, operatingHoursWeek: 5);
    expect(result.valid, isTrue);
    expect(result.totalCost, 180);
    expect(result.scenarios, hasLength(2));
    expect(const IrrigationDesignAnalysisService().buildMaintenancePlan(p, startAt: DateTime(2026, 1, 1)), hasLength(2));
  });

  test('reports missing zone references', () {
    final p = _project();
    final z = IrrigationZone(id:'z2', method:'drip', equipmentIds:const ['missing'], areaM2:10, designFlowLpm:2, applicationRateMmH:4);
    final invalid = IrrigationDesignProject(id:p.id, siteBoundary:p.siteBoundary, zones:[z], pump:p.pump, version:p.version);
    final result = const IrrigationDesignAnalysisService().analyze(invalid);
    expect(result.valid, isFalse);
    expect(result.issues.single.code, 'missing_equipment');
  });
}

IrrigationDesignProject _project() {
  final boundary = SiteBoundary(id:'b', points:const [GeoCoordinate(latitude:30, longitude:31), GeoCoordinate(latitude:30, longitude:31.001), GeoCoordinate(latitude:30.001, longitude:31.001)]);
  final e = IrrigationEquipment(id:'e', type:'rotor', flowRateLpm:10, operatingPressureBar:2, quantity:2);
  final v = Valve(id:'v', type:'electric', diameterMm:25);
  final pipe = Pipe(id:'p', material:'PVC', diameter:50, lengthM:10);
  return IrrigationDesignProject(id:'p1', siteBoundary:boundary, equipment:[e], valves:[v], pipes:[pipe], zones:[IrrigationZone(id:'z', method:'rotor', equipmentIds:['e'], valveIds:['v'], pipeIds:['p'], areaM2:50, designFlowLpm:20, applicationRateMmH:6)], pump:Pump(id:'pump', type:'centrifugal', flowRateLpm:20, headM:20, powerKw:2, efficiency:.7), version:DesignVersion(major:1, minor:0, patch:0, createdAt:DateTime(2026,1,1)));
}
