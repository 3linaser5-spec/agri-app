import 'package:material_ui/material_ui.dart';
import 'package:printing/printing.dart';
import '../../models/irrigation_design_models.dart';
import '../../models/map_alert_model.dart';
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
import '../../services/irrigation_project_service.dart';
import '../../services/map_alert_service.dart';
import 'irrigation_map_editor_screen.dart';
import 'irrigation_network_map_screen.dart';
import 'irrigation_pipe_route_editor_screen.dart';
import 'irrigation_satellite_alerts_panel.dart';
import 'irrigation_3d_preview_screen.dart';
import 'landscape_planner_screen.dart';
import 'irrigation_review_view.dart';

/// مصمم شبكة الري واللاندسكيب.
///
/// التصميم (الحدود، النباتات، المعدات، المضخة، الفحص، التصدير) متاح لكل حساب.
/// اشتراك أقمار اللاندسكيب إضافة منفصلة: يفتح تنبيهات الأقمار وحدود المساحة
/// المرتبطة بالاشتراك فقط، ولا يمنع استخدام المصمم.
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
  String? _savedDocumentId;
  bool _savingProject = false;
  final steps = const ['الموقع', 'النباتات', 'المعدات والمناطق', 'المضخة', 'الفحص والتصدير'];

  @override void initState() { super.initState(); project = _demoProject(); }

  void exportProject() { try { setState(() { bundle = const IrrigationExportService().export(project); analysis = const IrrigationDesignAnalysisService().analyze(project); mapIssues = const IrrigationMapValidationService().validate(project); routeHydraulics = const IrrigationRouteHydraulicsService().analyze(project.pipeRoutes); zoneReports = const IrrigationZoneHydraulicReportService().build(project); coverageReports = const IrrigationCoverageAnalysisService().analyze(project); maintenanceTasks = const IrrigationOperationsService().buildMaintenancePlan(project, startAt: DateTime(2026, 1, 1)); }); } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('لا يمكن التصدير: $e'))); } }

  Future<void> _saveProject() async {
    setState(() => _savingProject = true);
    try {
      final id = await IrrigationProjectService.save(project, documentId: _savedDocumentId);
      if (!mounted) return;
      setState(() => _savedDocumentId = id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ التصميم في حسابك.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _savingProject = false);
    }
  }

  Future<void> _openSavedProjects() async {
    List<SavedIrrigationProject> items;
    try {
      items = await IrrigationProjectService.list();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
      return;
    }
    if (!mounted) return;
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد تصاميم محفوظة بعد. استخدم زر الحفظ أولاً.')),
      );
      return;
    }
    final selected = await showDialog<SavedIrrigationProject>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('تصاميمي المحفوظة'),
        children: [
          for (final item in items)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, item),
              child: ListTile(
                title: Text(item.name),
                subtitle: Text('مناطق: ${item.project.zones.length} — عناصر: ${item.project.placements.length}'),
              ),
            ),
        ],
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      project = selected.project;
      _savedDocumentId = selected.documentId;
      step = 0;
      bundle = null;
      analysis = null;
      mapIssues = const [];
      coverageReports = const [];
      maintenanceTasks = const [];
      reportDocument = null;
      routeHydraulics = const [];
      zoneReports = const [];
    });
  }

  Future<void> generateAndShareReport() async {
    try {
      final entitlement = await LandscapeSatelliteAccessService.getCurrentEntitlement();
      final hasSatellite = entitlement.active && entitlement.maxFeddan > 0;
      final alerts = hasSatellite ? await MapAlertService.watchAlerts().first : const <MapAlert>[];
      final alertsWithNotes = await Future.wait(alerts.map((alert) async {
        final notes = await MapAlertService.loadInspectionNotes(alertId: alert.id);
        return notes.isEmpty ? alert : alert.copyWith(inspectionResult: notes.join(' | '));
      }));
      final report = await const IrrigationReportService().build(
        project: project,
        coverageReports: coverageReports,
        routeHydraulics: routeHydraulics,
        zoneReports: zoneReports,
        satelliteAlerts: alertsWithNotes,
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
    // حد المساحة بالفدان قيد اشتراك أقمار اللاندسكيب فقط؛ التصميم بدون
    // اشتراك يحفظ الحدود كما رسمها المستخدم.
    final entitlement = await LandscapeSatelliteAccessService.getCurrentEntitlement();
    final satelliteLimitApplies = entitlement.active && entitlement.maxFeddan > 0;
    if (satelliteLimitApplies && !entitlement.allows(result.areaFeddan)) {
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
      appBar: AppBar(
        title: const Text('مصمم شبكة الري واللاندسكيب'),
        actions: [
          IconButton(
            onPressed: _savingProject ? null : _saveProject,
            tooltip: 'حفظ التصميم',
            icon: const Icon(Icons.save_outlined),
          ),
          IconButton(
            onPressed: _openSavedProjects,
            tooltip: 'تصاميمي المحفوظة',
            icon: const Icon(Icons.folder_open),
          ),
        ],
      ),
      body: Column(children: [
        Stepper(currentStep: step, onStepTapped: (i) => setState(() => step = i), controlsBuilder: (_, __) => const SizedBox.shrink(), steps: [for (var i = 0; i < steps.length; i++) Step(title: Text(steps[i]), content: _stepContent(i), isActive: step >= i, state: step > i ? StepState.complete : StepState.indexed)]),
        if (step == steps.length - 1) Expanded(child: _review()),
      ]),
    ),
  );

  Widget _stepContent(int i) => Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(switch(i) { 0 => 'حدود الموقع: ${project.siteBoundary.points.length} نقاط — المساحة ${project.siteBoundary.declaredArea?.toStringAsFixed(3) ?? '-'} فدان', 1 => 'عدد النباتات: ${project.plants.length} — Kc: ${project.plants.isEmpty ? '-' : project.plants.first.kc}', 2 => 'المناطق: ${project.zones.length} — عناصر الخريطة: ${project.placements.length} — مسارات المواسير: ${project.pipeRoutes.length}', 3 => 'المضخة: ${project.pump.nameAr} — ${project.pump.headM} m TDH', _ => 'شغّل الفحص ثم صدّر DXF وBOQ وجدول التشغيل.'}), if (i == 0) Align(alignment: Alignment.centerRight, child: Wrap(spacing: 8, children: [OutlinedButton.icon(onPressed: _editBoundary, icon: const Icon(Icons.map), label: const Text('فتح محرر الخريطة')), FilledButton.tonalIcon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LandscapePlannerScreen())), icon: const Icon(Icons.landscape_outlined), label: const Text('مصمم اللاندسكيب الجديد'))])), if (i == 2) Wrap(spacing: 8, children: [OutlinedButton.icon(onPressed: _editPlacements, icon: const Icon(Icons.water_drop), label: const Text('عناصر الشبكة')), OutlinedButton.icon(onPressed: _addPipeRoute, icon: const Icon(Icons.alt_route), label: const Text('رسم مسار ماسورة'))])] )));

  Widget _satelliteSection() => StreamBuilder<LandscapeSatelliteEntitlement>(
    stream: LandscapeSatelliteAccessService.watchEntitlement(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const SizedBox(height: 8);
      }
      final entitlement = snapshot.data;
      final hasSatellite = entitlement != null && entitlement.active && entitlement.maxFeddan > 0;
      return hasSatellite ? const IrrigationSatelliteAlertsPanel() : _satelliteLockedCard();
    },
  );

  Widget _satelliteLockedCard() => const Card(
    color: Color(0xFFF1F5F9),
    child: Padding(
      padding: EdgeInsets.all(12),
      child: Row(children: [
        Icon(Icons.satellite_alt, color: Colors.blueGrey),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'تنبيهات الأقمار الصناعية إضافة منفصلة عن المصمم. التصميم والفحص والتصدير شغالين بدونها.',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ]),
    ),
  );

  Widget _review() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _satelliteSection(),
      IrrigationReviewView(
        project: project,
        bundle: bundle,
        analysis: analysis,
        coverageReports: coverageReports,
        zoneReports: zoneReports,
        routeHydraulics: routeHydraulics,
        mapIssues: mapIssues,
        maintenanceTasks: maintenanceTasks,
        hasReport: reportDocument != null,
        onExport: exportProject,
        onShareReport: generateAndShareReport,
        onOpen3D: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Irrigation3DPreviewScreen(project: project),
          ),
        ),
      ),
    ],
  );

  IrrigationDesignProject _demoProject() {
    final points = const [GeoCoordinate(latitude: 30, longitude: 31), GeoCoordinate(latitude: 30, longitude: 31.001), GeoCoordinate(latitude: 30.001, longitude: 31.001)];
    final plant = PlantSpecies(id: 'plant-1', nameAr: 'زيتون', kc: .85, salinityResistance: .7, droughtResistance: .8);
    final equipment = IrrigationEquipment(id: 'rotor-1', nameAr: 'رشاش دوار', type: 'rotor', flowRateLpm: 12, operatingPressureBar: 2.5, quantity: 3);
    return IrrigationDesignProject(id: 'demo-project', nameAr: 'مشروع تجريبي', siteBoundary: SiteBoundary(id: 'boundary', points: points), plants: [plant], equipment: [equipment], zones: [IrrigationZone(id: 'zone-1', nameAr: 'المنطقة الأولى', method: 'rotor', plantId: plant.id, equipmentIds: [equipment.id], areaM2: 180, designFlowLpm: 36, applicationRateMmH: 8)], pump: Pump(id: 'pump-1', nameAr: 'مضخة رئيسية', type: 'centrifugal', flowRateLpm: 36, headM: 32, powerKw: 2.2, efficiency: .72), version: DesignVersion(major: 1, minor: 0, patch: 0, label: 'draft', createdAt: DateTime.now()));
  }
}
