import 'dart:convert';
import '../models/irrigation_design_models.dart';
import '../models/irrigation_operations_models.dart';

class IrrigationOperationsService {
  const IrrigationOperationsService();

  String qrPayload({
    required String projectId,
    required String assetType,
    required String assetId,
  }) => 'irrigation://$projectId/$assetType/$assetId';

  List<MaintenanceTask> buildMaintenancePlan(
    IrrigationDesignProject project, {
    required DateTime startAt,
  }) {
    final tasks = <MaintenanceTask>[
      for (final valve in project.valves)
        MaintenanceTask(
          id: 'maintenance-${valve.id}',
          projectId: project.id,
          assetId: valve.id,
          title: 'فحص المحبس وتنظيف الفلتر',
          priority: 'medium',
          status: 'open',
          dueAt: startAt.add(const Duration(days: 30)),
          qrCode: qrPayload(
            projectId: project.id,
            assetType: 'valve',
            assetId: valve.id,
          ),
        ),
      for (final zone in project.zones)
        MaintenanceTask(
          id: 'maintenance-zone-${zone.id}',
          projectId: project.id,
          assetId: zone.id,
          title: 'اختبار تغطية وضغط المنطقة',
          priority: 'medium',
          status: 'open',
          dueAt: startAt.add(const Duration(days: 14)),
          qrCode: qrPayload(
            projectId: project.id,
            assetType: 'zone',
            assetId: zone.id,
          ),
        ),
      for (final route in project.pipeRoutes)
        MaintenanceTask(
          id: 'maintenance-route-${route.id}',
          projectId: project.id,
          assetId: route.id,
          title: 'فحص التسريب ومسار الماسورة',
          priority: 'low',
          status: 'open',
          dueAt: startAt.add(const Duration(days: 90)),
          qrCode: qrPayload(
            projectId: project.id,
            assetType: 'pipe_route',
            assetId: route.id,
          ),
        ),
      MaintenanceTask(
        id: 'maintenance-pump-${project.pump.id}',
        projectId: project.id,
        assetId: project.pump.id,
        title: 'فحص المضخة والضغط',
        priority: 'high',
        status: 'open',
        dueAt: startAt.add(const Duration(days: 14)),
        qrCode: qrPayload(
          projectId: project.id,
          assetType: 'pump',
          assetId: project.pump.id,
        ),
      ),
    ];
    return List.unmodifiable(tasks);
  }

  AsBuiltRecord createAsBuilt({
    required IrrigationDesignProject project,
    required String recordedBy,
    required DateTime recordedAt,
    Map<String, dynamic> installedChanges = const {},
    String notes = '',
  }) {
    if (recordedBy.trim().isEmpty) {
      throw ArgumentError.value(recordedBy, 'recordedBy', 'مطلوب');
    }
    return AsBuiltRecord(
      projectId: project.id,
      recordedBy: recordedBy.trim(),
      recordedAt: recordedAt,
      installedChanges: {
        'boundary': project.siteBoundary.toJson(),
        'placements': project.placements.map((item) => item.toJson()).toList(),
        'pipe_routes': project.pipeRoutes.map((route) => route.toJson()).toList(),
        'overrides': installedChanges,
      },
      notes: notes,
    );
  }

  String maintenanceJson(List<MaintenanceTask> tasks) =>
      jsonEncode(tasks.map((task) => task.toJson()).toList(growable: false));

  String maintenanceCsv(List<MaintenanceTask> tasks) {
    final rows = <String>[
      'id,project_id,asset_id,title,priority,status,due_at,qr_code',
      for (final task in tasks)
        [
          task.id,
          task.projectId,
          task.assetId,
          task.title,
          task.priority,
          task.status,
          task.dueAt.toIso8601String(),
          task.qrCode ?? '',
        ].map((value) => '"${value.replaceAll('"', '""')}"').join(','),
    ];
    return '${rows.join('\n')}\n';
  }
}
