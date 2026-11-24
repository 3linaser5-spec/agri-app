import '../models/irrigation_design_models.dart';
import '../models/irrigation_operations_models.dart';

class IrrigationDesignIssue {
  final String code, severity, message, subjectId;
  const IrrigationDesignIssue({required this.code, required this.severity, required this.message, this.subjectId = ''});
  Map<String, dynamic> toJson() => {'code':code,'severity':severity,'message':message,'subject_id':subjectId};
}

class IrrigationDesignAnalysis {
  final List<IrrigationDesignIssue> issues;
  final List<IrrigationCostLine> costLines;
  final List<IrrigationScenario> scenarios;
  const IrrigationDesignAnalysis({required this.issues, required this.costLines, required this.scenarios});
  double get totalCost => costLines.fold(0, (sum, line) => sum + line.total);
  bool get valid => !issues.any((x) => x.severity == 'error');
  Map<String, dynamic> toJson() => {'valid':valid,'total_cost':totalCost,'issues':issues.map((x)=>x.toJson()).toList(),'cost_lines':costLines.map((x)=>x.toJson()).toList(),'scenarios':scenarios.map((x)=>x.toJson()).toList()};
}

class IrrigationDesignAnalysisService {
  const IrrigationDesignAnalysisService();

  IrrigationDesignAnalysis analyze(IrrigationDesignProject project, {Map<String, double> unitCosts = const {}, double weeklyWaterM3 = 0, double pumpPowerKw = 0, double operatingHoursWeek = 0}) {
    final issues = <IrrigationDesignIssue>[];
    final equipmentIds = project.equipment.map((x) => x.id).toSet();
    final pipeIds = project.pipes.map((x) => x.id).toSet();
    final valveIds = project.valves.map((x) => x.id).toSet();
    for (final zone in project.zones) {
      if (zone.equipmentIds.any((id) => !equipmentIds.contains(id))) issues.add(IrrigationDesignIssue(code:'missing_equipment', severity:'error', message:'المنطقة تشير إلى معدة غير موجودة', subjectId:zone.id));
      if (zone.pipeIds.any((id) => !pipeIds.contains(id))) issues.add(IrrigationDesignIssue(code:'missing_pipe', severity:'error', message:'المنطقة تشير إلى ماسورة غير موجودة', subjectId:zone.id));
      if (zone.valveIds.any((id) => !valveIds.contains(id))) issues.add(IrrigationDesignIssue(code:'missing_valve', severity:'error', message:'المنطقة تشير إلى محبس غير موجود', subjectId:zone.id));
      if (zone.applicationRateMmH <= 0) issues.add(IrrigationDesignIssue(code:'invalid_application_rate', severity:'error', message:'معدل التطبيق غير صالح', subjectId:zone.id));
    }
    final lines = <IrrigationCostLine>[];
    for (final p in project.pipes) {
      lines.add(IrrigationCostLine(id:p.id, category:'pipe', description:'${p.diameter}${p.diameterUnit} ${p.material}', unit:'m', quantity:p.lengthM, unitCost:unitCosts[p.material] ?? 0));
    }
    for (final v in project.valves) {
      lines.add(IrrigationCostLine(id:v.id, category:'valve', description:v.type, unit:'ea', quantity:1, unitCost:unitCosts[v.type] ?? 0));
    }
    for (final e in project.equipment) {
      lines.add(IrrigationCostLine(id:e.id, category:'equipment', description:e.nameAr.isEmpty ? e.type : e.nameAr, unit:'ea', quantity:e.quantity.toDouble(), unitCost:unitCosts[e.type] ?? 0));
    }
    final energy = pumpPowerKw * operatingHoursWeek;
    final scenarios = [
      IrrigationScenario(id:'baseline', name:'التصميم الأساسي', waterVolumeM3Week:weeklyWaterM3, energyKwhWeek:energy, estimatedCost:lines.fold<double>(0,(s,x)=>s+x.total)),
      IrrigationScenario(id:'water_saving', name:'توفير المياه', waterVolumeM3Week:weeklyWaterM3*.85, energyKwhWeek:energy*.9, estimatedCost:lines.fold<double>(0,(s,x)=>s+x.total)*1.08, warnings: const ['يحتاج تحققًا ميدانيًا من التغطية']),
    ];
    return IrrigationDesignAnalysis(issues:List.unmodifiable(issues), costLines:List.unmodifiable(lines), scenarios:List.unmodifiable(scenarios));
  }

  List<MaintenanceTask> buildMaintenancePlan(IrrigationDesignProject project, {required DateTime startAt}) => [
    for (final v in project.valves) MaintenanceTask(id:'maintenance-${v.id}', projectId:project.id, assetId:v.id, title:'فحص المحبس وتنظيف الفلتر', priority:'medium', status:'open', dueAt:startAt.add(const Duration(days:30)), qrCode:'irrigation://${project.id}/valve/${v.id}'),
    MaintenanceTask(id:'maintenance-pump-${project.pump.id}', projectId:project.id, assetId:project.pump.id, title:'فحص المضخة والضغط', priority:'high', status:'open', dueAt:startAt.add(const Duration(days:14)), qrCode:'irrigation://${project.id}/pump/${project.pump.id}'),
  ];
}
