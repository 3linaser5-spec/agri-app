import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:agri_app/models/irrigation_design_models.dart';
import 'package:agri_app/screens/irrigation/irrigation_review_view.dart';
import 'package:agri_app/services/irrigation_coverage_analysis_service.dart';
import 'package:agri_app/services/irrigation_design_analysis_service.dart';
import 'package:agri_app/services/irrigation_export_service.dart';

void main() {
  testWidgets('يعرض ملخص التصدير ونتائج فحص التغطية بعد التحليل', (
    tester,
  ) async {
    final project = _project();
    final bundle = const IrrigationExportService().export(project);
    final analysis = const IrrigationDesignAnalysisService().analyze(project);
    final coverage = const IrrigationCoverageAnalysisService().analyze(project);
    var exportTaps = 0;
    var reportTaps = 0;

    await tester.pumpWidget(
      _host(
        IrrigationReviewView(
          project: project,
          bundle: bundle,
          analysis: analysis,
          coverageReports: coverage,
          zoneReports: const [],
          routeHydraulics: const [],
          mapIssues: const [],
          maintenanceTasks: const [],
          hasReport: false,
          onExport: () => exportTaps++,
          onShareReport: () => reportTaps++,
          onOpen3D: () {},
        ),
      ),
    );

    expect(find.text('المشروع صالح للتصدير'), findsOneWidget);
    expect(find.textContaining('DXF: ${bundle.dxf.length}'), findsOneWidget);
    expect(find.textContaining('مغطى:'), findsOneWidget);
    expect(find.textContaining('عينات:'), findsOneWidget);
    expect(find.text('إنشاء ومشاركة تقرير PDF'), findsOneWidget);

    final exportButton = find.text('إنشاء DXF وBOQ وجدول التشغيل');
    await tester.ensureVisible(exportButton);
    await tester.tap(exportButton);
    expect(exportTaps, 1);

    final reportButton = find.text('إنشاء ومشاركة تقرير PDF');
    await tester.ensureVisible(reportButton);
    await tester.tap(reportButton);
    expect(reportTaps, 1);
  });

  testWidgets('لا يعرض أقسام التحليل قبل تشغيل الفحص', (tester) async {
    await tester.pumpWidget(
      _host(
        IrrigationReviewView(
          project: _project(),
          bundle: null,
          analysis: null,
          coverageReports: const [],
          zoneReports: const [],
          routeHydraulics: const [],
          mapIssues: const [],
          maintenanceTasks: const [],
          hasReport: true,
          onExport: () {},
          onShareReport: () {},
          onOpen3D: () {},
        ),
      ),
    );

    expect(find.text('المشروع صالح للتصدير'), findsOneWidget);
    expect(find.text('فحص التغطية'), findsNothing);
    expect(find.textContaining('DXF:'), findsNothing);
    expect(find.text('مشاركة تقرير PDF مرة أخرى'), findsOneWidget);
  });
}

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

IrrigationDesignProject _project() {
  final equipment = IrrigationEquipment(
    id: 'spray-1',
    type: 'spray',
    flowRateLpm: 12,
    operatingPressureBar: 2,
  );
  return IrrigationDesignProject(
    id: 'project-1',
    siteBoundary: SiteBoundary(
      id: 'boundary-1',
      points: const [
        GeoCoordinate(latitude: 30, longitude: 31),
        GeoCoordinate(latitude: 30, longitude: 31.001),
        GeoCoordinate(latitude: 30.001, longitude: 31.001),
      ],
    ),
    equipment: [equipment],
    placements: [
      IrrigationMapPlacement(
        id: 'spray-placement-1',
        kind: 'spray',
        coordinate: const GeoCoordinate(latitude: 30, longitude: 31.0005),
        zoneId: 'zone-1',
      ),
    ],
    zones: [
      IrrigationZone(
        id: 'zone-1',
        method: 'spray',
        equipmentIds: [equipment.id],
        areaM2: 100,
        designFlowLpm: 20,
        applicationRateMmH: 8,
      ),
    ],
    pump: Pump(
      id: 'pump-1',
      type: 'centrifugal',
      flowRateLpm: 20,
      headM: 25,
      powerKw: 1.5,
      efficiency: 0.7,
    ),
    version: DesignVersion(
      major: 1,
      minor: 0,
      patch: 0,
      createdAt: DateTime.utc(2026, 11, 20),
    ),
  );
}
