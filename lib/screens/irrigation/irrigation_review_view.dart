import 'package:material_ui/material_ui.dart';

import '../../models/irrigation_design_models.dart';
import '../../models/irrigation_operations_models.dart';
import '../../services/irrigation_coverage_analysis_service.dart';
import '../../services/irrigation_design_analysis_service.dart';
import '../../services/irrigation_export_service.dart';
import '../../services/irrigation_map_validation_service.dart';
import '../../services/irrigation_route_hydraulics_service.dart';
import '../../services/irrigation_zone_hydraulic_report_service.dart';

/// مراجعة التصميم قبل التصدير: صلاحية المشروع، مخرجات DXF/BOQ، وتحليل التغطية.
///
/// ويدجت عرضية خالصة (بدون Firebase) لتسهيل اختبارها، والتقاطها لأزرار
/// التصدير/المشاركة من الشاشة الأم.
class IrrigationReviewView extends StatelessWidget {
  final IrrigationDesignProject project;
  final IrrigationExportBundle? bundle;
  final IrrigationDesignAnalysis? analysis;
  final List<IrrigationZoneCoverageReport> coverageReports;
  final List<IrrigationZoneHydraulicReport> zoneReports;
  final List<IrrigationRouteHydraulicResult> routeHydraulics;
  final List<IrrigationMapIssue> mapIssues;
  final List<MaintenanceTask> maintenanceTasks;
  final bool hasReport;
  final VoidCallback onExport;
  final VoidCallback onShareReport;
  final VoidCallback onOpen3D;

  const IrrigationReviewView({
    super.key,
    required this.project,
    required this.bundle,
    required this.analysis,
    required this.coverageReports,
    required this.zoneReports,
    required this.routeHydraulics,
    required this.mapIssues,
    required this.maintenanceTasks,
    required this.hasReport,
    required this.onExport,
    required this.onShareReport,
    required this.onOpen3D,
  });

  @override
  Widget build(BuildContext context) {
    final bundle = this.bundle;
    final analysis = this.analysis;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: onOpen3D,
          icon: const Icon(Icons.view_in_ar),
          label: const Text('فتح معاينة 3D مبسطة'),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.check_circle, color: Colors.green),
            title: const Text('المشروع صالح للتصدير'),
            subtitle: Text(
              '${project.zones.length} Zones • ${project.equipment.length} معدات • الإصدار ${project.version}',
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: onExport,
          icon: const Icon(Icons.file_download),
          label: const Text('إنشاء DXF وBOQ وجدول التشغيل'),
        ),
        ElevatedButton.icon(
          onPressed: onShareReport,
          icon: const Icon(Icons.picture_as_pdf),
          label: Text(
            hasReport ? 'مشاركة تقرير PDF مرة أخرى' : 'إنشاء ومشاركة تقرير PDF',
          ),
        ),
        if (bundle != null) ...[
          Text('DXF: ${bundle.dxf.length} حرف'),
          Text('بنود BOQ: ${bundle.boq.length}'),
          ...bundle.schedule.map(
            (line) => ListTile(
              title: Text(line.zoneName),
              subtitle: Text(
                '${line.runtimeMinutes.toStringAsFixed(1)} دقيقة تشغيل',
              ),
            ),
          ),
        ],
        if (analysis != null) ...[
          const ListTile(
            title: Text('فحص التغطية'),
            subtitle: Text(
              'تحليل شبكي حسب المدى والاتجاه والعوائق؛ يلزم اختبار ضغط ميداني قبل التنفيذ',
            ),
          ),
          ...coverageReports.map(
            (report) => ListTile(
              leading: Icon(
                report.warnings.length <= 1 ? Icons.check_circle : Icons.warning,
                color: report.warnings.length <= 1
                    ? Colors.green
                    : Colors.orange,
              ),
              title: Text(
                '${report.zoneId} — ${report.irrigationElementCount} عناصر',
              ),
              subtitle: Text(
                'مغطى: ${report.coverage.coveredAreaM2.toStringAsFixed(1)} م² — '
                'جاف: ${report.coverage.dryAreaM2.toStringAsFixed(1)} م² — '
                'تداخل: ${report.coverage.overlapAreaM2.toStringAsFixed(1)} م² — '
                'عينات: ${report.sampledPoints}',
              ),
            ),
          ),
          ListTile(
            title: const Text('توافق الـZones مع المضخة'),
            trailing: Text(
              '${zoneReports.where((report) => report.pumpAdequate).length}/${zoneReports.length} صالح',
            ),
          ),
          ...zoneReports.map(
            (report) => ListTile(
              leading: Icon(
                report.pumpAdequate ? Icons.check_circle : Icons.warning,
                color: report.pumpAdequate ? Colors.green : Colors.orange,
              ),
              title: Text(
                '${report.zoneId} — ${report.designFlowLpm.toStringAsFixed(1)} L/min',
              ),
              subtitle: Text(
                report.recommendations.isEmpty
                    ? 'المضخة مناسبة — TDH مطلوب: ${report.requiredHeadM.toStringAsFixed(1)} م'
                    : report.recommendations.join(' '),
              ),
            ),
          ),
          ListTile(
            title: const Text('الفحص الهيدروليكي للمواسير'),
            trailing: Text('${routeHydraulics.length} مسارات'),
          ),
          ...routeHydraulics.map(
            (item) => ListTile(
              leading: Icon(
                item.hydraulic.warnings.isEmpty
                    ? Icons.check_circle
                    : Icons.warning,
                color: item.hydraulic.warnings.isEmpty
                    ? Colors.green
                    : Colors.orange,
              ),
              title: Text(
                '${item.routeId} — ${item.lengthM.toStringAsFixed(1)} م',
              ),
              subtitle: Text(
                'الفقد: ${item.hydraulic.pipeFrictionHeadM.toStringAsFixed(2)} م — '
                'TDH: ${item.hydraulic.totalDynamicHeadM.toStringAsFixed(2)} م — '
                'سرعة: ${item.hydraulic.velocityMps.toStringAsFixed(2)} م/ث',
              ),
            ),
          ),
          ListTile(
            title: const Text('فحص عناصر الخريطة'),
            trailing: Text(
              mapIssues.isEmpty ? 'صالح' : '${mapIssues.length} ملاحظات',
            ),
          ),
          ...mapIssues.map(
            (issue) => ListTile(
              leading: const Icon(Icons.location_off, color: Colors.orange),
              title: Text(issue.message),
              subtitle: Text(issue.subjectId),
            ),
          ),
          ListTile(
            title: const Text('خطة التشغيل والصيانة'),
            trailing: Text('${maintenanceTasks.length} مهام'),
          ),
          ...maintenanceTasks.map(
            (task) => ListTile(
              leading: const Icon(Icons.qr_code_2),
              title: Text(task.title),
              subtitle: Text('${task.assetId} — ${task.qrCode}'),
            ),
          ),
          ListTile(
            title: const Text('تكلفة تقديرية'),
            trailing: Text(analysis.totalCost.toStringAsFixed(2)),
          ),
          ListTile(
            title: const Text('حالة الفحص'),
            trailing: Text(analysis.valid ? 'صالح' : 'يحتاج مراجعة'),
          ),
          ...analysis.issues.map(
            (issue) => ListTile(
              leading: const Icon(Icons.warning, color: Colors.orange),
              title: Text(issue.message),
              subtitle: Text(issue.subjectId),
            ),
          ),
          ListTile(
            title: const Text('مهام الصيانة المبدئية'),
            trailing: Text(
              const IrrigationDesignAnalysisService()
                  .buildMaintenancePlan(project, startAt: DateTime(2026, 1, 1))
                  .length
                  .toString(),
            ),
          ),
        ],
      ],
    );
  }
}
