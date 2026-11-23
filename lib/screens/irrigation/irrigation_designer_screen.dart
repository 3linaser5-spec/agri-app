import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../models/irrigation_design_models.dart';
import '../../models/irrigation_operations_models.dart';
import '../../services/irrigation_export_service.dart';
import '../../services/irrigation_design_analysis_service.dart';
import '../../services/landscape_satellite_access_service.dart';
import '../../services/irrigation_map_validation_service.dart';
import '../../services/irrigation_route_hydraulics_service.dart';
import '../../services/irrigation_zone_hydraulic_report_service.dart';
import '../../services/irrigation_coverage_analysis_service.dart';
import '../../services/irrigation_report_service.dart';
import '../../services/irrigation_operations_service.dart';
import 'irrigation_map_editor_screen.dart';
import 'irrigation_network_map_screen.dart';
import 'irrigation_pipe_route_editor_screen.dart';
import 'irrigation_satellite_alerts_panel.dart';

class IrrigationDesignerScreen extends StatefulWidget {
  const IrrigationDesignerScreen({super.key});
  @override State<IrrigationDesignerScreen> createState() => _IrrigationDesignerScreenState();
}

class _IrrigationDesignerScreenState extends State<IrrigationDesignerScreen> {
  int step = 0;
  late IrrigationDesignProject project;
  IrrigationExportBundle? bundle;
  IrrigationDesignAnalysis? analysis;
  List<IrrigationMapIssue> mapIssues = const [];
  List<IrrigationRouteHydraulicResult> routeHydraulics = const [];
  List<IrrigationZoneHydraulicReport> zoneReports = const [];
  List<IrrigationZoneCoverageReport> coverageReports = const [];
  IrrigationReportDocument? reportDocument;
  List<MaintenanceTask> maintenanceTasks = const [];
  final steps = const ['الموقع', 'النباتات', 'المعدات والمناطق', 'المضخة', 'الفحص والتصدير'];

  @override void initState() { super.initState(); project = _demoProject(); }
  void exportProject() { try { setState(() { bundle = const IrrigationExportService().export(project); analysis = const IrrigationDesignAnalysisService().analyze(project); mapIssues = const IrrigationMapValidationService().validate(project); routeHydraulics = const IrrigationRouteHydraulicsService().analyze(project.pipeRoutes); zoneReports = const IrrigationZoneHydraulicReportService().build(project); coverageReports = const IrrigationCoverageAnalysisService().analyze(project); maintenanceTasks = const IrrigationOperationsService().buildMaintenancePlan(project, startAt: DateTime(2026, 1, 1)); }); } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('لا يمكن التصدير: $e'))); } }

  Future<void> generateAndShareReport() async {
    try {
      final report = await const IrrigationReportService().build(
        project: project,
        coverageReports: coverageReports,
        routeHydraulics: routeHydraulics,
        zoneReports: zoneReports,
      );
      if (!mounted) return;
      setState(() => reportDocument = report);
      await Printing.sharePdf(bytes: report.pdfBytes, filename: report.fileName);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('لا يمكن إنشاء التقرير: $error')),
        );
      }
    }
  }

  Future<void> _editBoundary() async {
    final result = await Navigator.push<IrrigationMapEditResult>(
      context,
      MaterialPageRoute(builder: (_) => const IrrigationMapEditorScreen()),
    );
    if (!mounted || result == null) return;
    final entitlement = await LandscapeSatelliteAccessService.getCurrentEntitlement();
    if (!entitlement.allows(result.areaFeddan)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('المساحة تتجاوز الحد المسموح: ${entitlement.maxFeddan} فدان')),
        );
      }
      return;
    }
    setState(() {
      project = IrrigationDesignProject(
        id: project.id,
        nameAr: project.nameAr,
        nameEn: project.nameEn,
        description: project.description,
        siteBoundary: SiteBoundary(
          id: project.siteBoundary.id,
          nameAr: project.siteBoundary.nameAr,
          nameEn: project.siteBoundary.nameEn,
          points: result.points,
          areaUnit: 'feddan',
          declaredArea: result.areaFeddan,
        ),
        plants: project.plants,
        equipment: project.equipment,
        pipes: project.pipes,
        valves: project.valves,
        zones: project.zones,
        pump: project.pump,
        elevationPoints: project.elevationPoints,
        placements: project.placements,
        pipeRoutes: project.pipeRoutes,
        version: project.version,
      );
      bundle = null;
      analysis = null;
    });
  }

  Future<void> _editPlacements() async {
    final result = await Navigator.push<List<IrrigationMapPlacement>>(
      context,
      MaterialPageRoute(
        builder: (_) => IrrigationNetworkMapScreen(
          initialPlacements: project.placements,
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      project = IrrigationDesignProject(
        id: project.id,
        nameAr: project.nameAr,
        nameEn: project.nameEn,
        description: project.description,
        siteBoundary: project.siteBoundary,
        plants: project.plants,
        equipment: project.equipment,
        pipes: project.pipes,
        valves: project.valves,
        zones: project.zones,
        pump: project.pump,
        elevationPoints: project.elevationPoints,
        placements: result,
        pipeRoutes: project.pipeRoutes,
        version: project.version,
      );
      bundle = null;
      analysis = null;
    });
  }

  Future<void> _addPipeRoute() async {
    final result = await Navigator.push<IrrigationPipeRoute>(
      context,
      MaterialPageRoute(builder: (_) => const IrrigationPipeRouteEditorScreen()),
    );
    if (!mounted || result == null) return;
    setState(() {
      project = IrrigationDesignProject(
        id: project.id,
        nameAr: project.nameAr,
        nameEn: project.nameEn,
        description: project.description,
        siteBoundary: project.siteBoundary,
        plants: project.plants,
        equipment: project.equipment,
        pipes: project.pipes,
        valves: project.valves,
        zones: project.zones,
        pump: project.pump,
        elevationPoints: project.elevationPoints,
        placements: project.placements,
        pipeRoutes: [...project.pipeRoutes, result],
        version: project.version,
      );
      bundle = null;
      analysis = null;
      mapIssues = const [];
    });
  }

  @override Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('مصمم شبكة الري واللاندسكيب')),
      body: StreamBuilder<LandscapeSatelliteEntitlement>(stream: LandscapeSatelliteAccessService.watchEntitlement(), builder: (context, access) {
        if (access.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final entitlement = access.data;
        if (entitlement == null || !entitlement.active) return _accessRequired();
        if (entitlement.maxFeddan <= 0) return _accessRequired('الأدمن لم يحدد مساحة فدان مسموحة لهذا الحساب.');
        return Column(children: [
          Stepper(currentStep: step, onStepTapped: (i) => setState(() => step=i), controlsBuilder: (_,__) => const SizedBox.shrink(), steps: [for (var i=0;i<steps.length;i++) Step(title: Text(steps[i]), content: _stepContent(i), isActive: step >= i, state: step > i ? StepState.complete : StepState.indexed)]),
          if (step == steps.length - 1) Expanded(child: _review()),
        ]);
      }),
    ),
  );

  Widget _stepContent(int i) => Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(switch(i) { 0 => 'حدود الموقع: ${project.siteBoundary.points.length} نقاط — المساحة ${project.siteBoundary.declaredArea?.toStringAsFixed(3) ?? '-'} فدان', 1 => 'عدد النباتات: ${project.plants.length} — Kc: ${project.plants.isEmpty ? '-' : project.plants.first.kc}', 2 => 'المناطق: ${project.zones.length} — عناصر الخريطة: ${project.placements.length} — مسارات المواسير: ${project.pipeRoutes.length}', 3 => 'المضخة: ${project.pump.nameAr} — ${project.pump.headM} m TDH', _ => 'شغّل الفحص ثم صدّر DXF وBOQ وجدول التشغيل.'}), if (i == 0) Align(alignment: Alignment.centerRight, child: OutlinedButton.icon(onPressed: _editBoundary, icon: const Icon(Icons.map), label: const Text('فتح محرر الخريطة'))), if (i == 2) Wrap(spacing: 8, children: [OutlinedButton.icon(onPressed: _editPlacements, icon: const Icon(Icons.water_drop), label: const Text('عناصر الشبكة')), OutlinedButton.icon(onPressed: _addPipeRoute, icon: const Icon(Icons.alt_route), label: const Text('رسم مسار ماسورة'))])] )));
  Widget _accessRequired([String message = 'خدمة أقمار اللاندسكيب غير مفعّلة لهذا الحساب.']) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.lock_outline, size: 64, color: Colors.blueGrey), const SizedBox(height: 12), Text(message, textAlign: TextAlign.center), const SizedBox(height: 8), const Text('اطلب من الأدمن تفعيل الخدمة وتحديد المساحة قبل استخدام المصمم.', textAlign: TextAlign.center)])));
  Widget _review() => ListView(padding: const EdgeInsets.all(16), children: [
    const IrrigationSatelliteAlertsPanel(),
    Card(child: ListTile(leading: const Icon(Icons.check_circle, color: Colors.green), title: const Text('المشروع صالح للتصدير'), subtitle: Text('${project.zones.length} Zones • ${project.equipment.length} معدات • الإصدار ${project.version}'))),
    ElevatedButton.icon(onPressed: exportProject, icon: const Icon(Icons.file_download), label: const Text('إنشاء DXF وBOQ وجدول التشغيل')),
    ElevatedButton.icon(onPressed: generateAndShareReport, icon: const Icon(Icons.picture_as_pdf), label: Text(reportDocument == null ? 'إنشاء ومشاركة تقرير PDF' : 'مشاركة تقرير PDF مرة أخرى')),
    if (bundle != null) ...[Text('DXF: ${bundle!.dxf.length} حرف'), Text('بنود BOQ: ${bundle!.boq.length}'), ...bundle!.schedule.map((x) => ListTile(title: Text(x.zoneName), subtitle: Text('${x.runtimeMinutes.toStringAsFixed(1)} دقيقة تشغيل')))],
    if (analysis != null) ...[
      const ListTile(title: Text('فحص التغطية'), subtitle: Text('تقديري ويحتاج معايرة ميدانية قبل التنفيذ')),
      ...coverageReports.map((report) => ListTile(leading: Icon(report.warnings.length <= 1 ? Icons.check_circle : Icons.warning, color: report.warnings.length <= 1 ? Colors.green : Colors.orange), title: Text('${report.zoneId} — ${report.irrigationElementCount} عناصر'), subtitle: Text('مغطى: ${report.coverage.coveredAreaM2.toStringAsFixed(1)} م² — جاف: ${report.coverage.dryAreaM2.toStringAsFixed(1)} م² — تداخل: ${report.coverage.overlapAreaM2.toStringAsFixed(1)} م²'))),
      ListTile(title: const Text('توافق الـZones مع المضخة'), trailing: Text('${zoneReports.where((report) => report.pumpAdequate).length}/${zoneReports.length} صالح')),
      ...zoneReports.map((report) => ListTile(leading: Icon(report.pumpAdequate ? Icons.check_circle : Icons.warning, color: report.pumpAdequate ? Colors.green : Colors.orange), title: Text('${report.zoneId} — ${report.designFlowLpm.toStringAsFixed(1)} L/min'), subtitle: Text(report.recommendations.isEmpty ? 'المضخة مناسبة — TDH مطلوب: ${report.requiredHeadM.toStringAsFixed(1)} م' : report.recommendations.join(' ')))),
      ListTile(title: const Text('الفحص الهيدروليكي للمواسير'), trailing: Text('${routeHydraulics.length} مسارات')),
      ...routeHydraulics.map((item) => ListTile(leading: Icon(item.hydraulic.warnings.isEmpty ? Icons.check_circle : Icons.warning, color: item.hydraulic.warnings.isEmpty ? Colors.green : Colors.orange), title: Text('${item.routeId} — ${item.lengthM.toStringAsFixed(1)} م'), subtitle: Text('الفقد: ${item.hydraulic.pipeFrictionHeadM.toStringAsFixed(2)} م — TDH: ${item.hydraulic.totalDynamicHeadM.toStringAsFixed(2)} م — سرعة: ${item.hydraulic.velocityMps.toStringAsFixed(2)} م/ث'))),
      ListTile(title: const Text('فحص عناصر الخريطة'), trailing: Text(mapIssues.isEmpty ? 'صالح' : '${mapIssues.length} ملاحظات')),
      ...mapIssues.map((issue) => ListTile(leading: const Icon(Icons.location_off, color: Colors.orange), title: Text(issue.message), subtitle: Text(issue.subjectId))),
      ListTile(title: const Text('خطة التشغيل والصيانة'), trailing: Text('${maintenanceTasks.length} مهام')),
      ...maintenanceTasks.map((task) => ListTile(leading: const Icon(Icons.qr_code_2), title: Text(task.title), subtitle: Text('${task.assetId} — ${task.qrCode}'))),
      ListTile(title: const Text('تكلفة تقديرية'), trailing: Text('${analysis!.totalCost.toStringAsFixed(2)}')),
      ListTile(title: const Text('حالة الفحص'), trailing: Text(analysis!.valid ? 'صالح' : 'يحتاج مراجعة')),
      ...analysis!.issues.map((x) => ListTile(leading: const Icon(Icons.warning, color: Colors.orange), title: Text(x.message), subtitle: Text(x.subjectId))),
      ListTile(title: const Text('مهام الصيانة المبدئية'), trailing: Text('${const IrrigationDesignAnalysisService().buildMaintenancePlan(project, startAt: DateTime(2026, 1, 1)).length}')),
    ],
  ]);

  IrrigationDesignProject _demoProject() {
    final points = const [GeoCoordinate(latitude: 30, longitude: 31), GeoCoordinate(latitude: 30, longitude: 31.001), GeoCoordinate(latitude: 30.001, longitude: 31.001)];
    final plant = PlantSpecies(id: 'plant-1', nameAr: 'زيتون', kc: .85, salinityResistance: .7, droughtResistance: .8);
    final equipment = IrrigationEquipment(id: 'rotor-1', nameAr: 'رشاش دوار', type: 'rotor', flowRateLpm: 12, operatingPressureBar: 2.5, quantity: 3);
    return IrrigationDesignProject(id: 'demo-project', nameAr: 'مشروع تجريبي', siteBoundary: SiteBoundary(id: 'boundary', points: points), plants: [plant], equipment: [equipment], zones: [IrrigationZone(id: 'zone-1', nameAr: 'المنطقة الأولى', method: 'rotor', plantId: plant.id, equipmentIds: [equipment.id], areaM2: 180, designFlowLpm: 36, applicationRateMmH: 8)], pump: Pump(id: 'pump-1', nameAr: 'مضخة رئيسية', type: 'centrifugal', flowRateLpm: 36, headM: 32, powerKw: 2.2, efficiency: .72), version: DesignVersion(major: 1, minor: 0, patch: 0, label: 'draft', createdAt: DateTime.now()));
  }
}
