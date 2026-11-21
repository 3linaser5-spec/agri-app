library;

class IrrigationCostLine {
  final String id, category, description, unit;
  final double quantity, unitCost;
  const IrrigationCostLine({required this.id, required this.category, required this.description, required this.unit, required this.quantity, required this.unitCost});
  double get total => quantity * unitCost;
  Map<String, dynamic> toJson() => {'id':id,'category':category,'description':description,'unit':unit,'quantity':quantity,'unit_cost':unitCost,'total':total};
}

class IrrigationScenario {
  final String id, name;
  final double waterVolumeM3Week, energyKwhWeek, estimatedCost;
  final List<String> warnings;
  const IrrigationScenario({required this.id, required this.name, required this.waterVolumeM3Week, required this.energyKwhWeek, required this.estimatedCost, this.warnings = const []});
  Map<String, dynamic> toJson() => {'id':id,'name':name,'water_volume_m3_week':waterVolumeM3Week,'energy_kwh_week':energyKwhWeek,'estimated_cost':estimatedCost,'warnings':warnings};
}

class AsBuiltRecord {
  final String projectId, recordedBy;
  final DateTime recordedAt;
  final Map<String, dynamic> installedChanges;
  final String notes;
  const AsBuiltRecord({required this.projectId, required this.recordedBy, required this.recordedAt, this.installedChanges = const {}, this.notes = ''});
  Map<String, dynamic> toJson() => {'project_id':projectId,'recorded_by':recordedBy,'recorded_at':recordedAt.toIso8601String(),'installed_changes':installedChanges,'notes':notes};
}

class MaintenanceTask {
  final String id, projectId, assetId, title, priority, status;
  final DateTime dueAt;
  final String? qrCode;
  const MaintenanceTask({required this.id, required this.projectId, required this.assetId, required this.title, required this.priority, required this.status, required this.dueAt, this.qrCode});
  Map<String, dynamic> toJson() => {'id':id,'project_id':projectId,'asset_id':assetId,'title':title,'priority':priority,'status':status,'due_at':dueAt.toIso8601String(),'qr_code':qrCode};
}
