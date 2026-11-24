import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/irrigation_design_models.dart';
import '../models/map_alert_model.dart';
import 'irrigation_coverage_analysis_service.dart';
import 'irrigation_route_hydraulics_service.dart';
import 'irrigation_zone_hydraulic_report_service.dart';

class IrrigationReportDocument {
  final String fileName;
  final String summaryText;
  final Uint8List pdfBytes;

  const IrrigationReportDocument({
    required this.fileName,
    required this.summaryText,
    required this.pdfBytes,
  });
}

class IrrigationReportService {
  const IrrigationReportService();

  Future<IrrigationReportDocument> build({
    required IrrigationDesignProject project,
    required List<IrrigationZoneCoverageReport> coverageReports,
    required List<IrrigationRouteHydraulicResult> routeHydraulics,
    required List<IrrigationZoneHydraulicReport> zoneReports,
    List<MapAlert> satelliteAlerts = const [],
    DateTime? generatedAt,
  }) async {
    final date = generatedAt ?? DateTime.now();
    final lines = <String>[
      'Irrigation Design Report / تقرير تصميم الري',
      'Project: ${project.nameEn.isEmpty ? project.id : project.nameEn}',
      'Generated: ${date.toIso8601String()}',
      'Boundary area: ${project.siteBoundary.declaredArea?.toStringAsFixed(3) ?? '-'} feddan',
      'Zones: ${project.zones.length}',
      'Map elements: ${project.placements.length}',
      'Pipe routes: ${project.pipeRoutes.length}',
      '',
      'Zone hydraulic and pump compatibility:',
      ...zoneReports.map((report) =>
          '${report.zoneId}: ${report.pumpAdequate ? 'OK' : 'REVIEW'}; flow ${report.designFlowLpm.toStringAsFixed(1)} L/min; TDH ${report.requiredHeadM.toStringAsFixed(1)} m; ${report.recommendations.join(' ')}'),
      '',
      'Pipe route hydraulics:',
      ...routeHydraulics.map((route) =>
          '${route.routeId}: length ${route.lengthM.toStringAsFixed(1)} m; velocity ${route.hydraulic.velocityMps.toStringAsFixed(2)} m/s; friction loss ${route.hydraulic.pipeFrictionHeadM.toStringAsFixed(2)} m; TDH ${route.hydraulic.totalDynamicHeadM.toStringAsFixed(2)} m'),
      '',
      'Coverage (preliminary; field calibration required):',
      ...coverageReports.map((report) =>
          '${report.zoneId}: covered ${report.coverage.coveredAreaM2.toStringAsFixed(1)} m2; dry ${report.coverage.dryAreaM2.toStringAsFixed(1)} m2; overlap ${report.coverage.overlapAreaM2.toStringAsFixed(1)} m2; samples ${report.sampledPoints}; warnings ${report.warnings.join(', ')}'),
      '',
      'Satellite alerts requiring field inspection:',
      ...satelliteAlerts.map((alert) =>
          '${alert.zoneId ?? 'Zone غير محدد'}: ${alert.title}; coordinates ${alert.latitude.toStringAsFixed(6)}, ${alert.longitude.toStringAsFixed(6)}; status ${alert.status}; inspection result: ${alert.inspectionResult ?? 'لم تُسجل نتيجة بعد'}.'),
      '',
      'Satellite analysis source names are intentionally omitted from this report.',
      'Potential problem locations must be verified in the field before action.',
    ];
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Header(level: 0, child: pw.Text('Irrigation Design Report')),
          ...lines.map((line) => pw.Paragraph(text: line)),
        ],
      ),
    );
    return IrrigationReportDocument(
      fileName: 'irrigation-report-${project.id}.pdf',
      summaryText: lines.join('\n'),
      pdfBytes: await document.save(),
    );
  }
}
