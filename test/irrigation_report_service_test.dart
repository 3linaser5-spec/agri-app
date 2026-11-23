import 'package:flutter_test/flutter_test.dart';
import 'package:agri_app/models/irrigation_design_models.dart';
import 'package:agri_app/services/irrigation_report_service.dart';

void main() {
  test('creates a PDF report without exposing satellite source names', () async {
    final project = IrrigationDesignProject(
      id: 'report-project',
      nameEn: 'Landscape test',
      siteBoundary: SiteBoundary(
        id: 'boundary',
        points: const [
          GeoCoordinate(latitude: 30, longitude: 31),
          GeoCoordinate(latitude: 30, longitude: 31.01),
          GeoCoordinate(latitude: 30.01, longitude: 31.01),
        ],
        areaUnit: 'feddan',
        declaredArea: 1,
      ),
      pump: Pump(
        id: 'pump',
        type: 'centrifugal',
        flowRateLpm: 40,
        headM: 30,
        powerKw: 2,
        efficiency: .7,
      ),
      version: DesignVersion(
        major: 1,
        minor: 0,
        patch: 0,
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    final report = await const IrrigationReportService().build(
      project: project,
      coverageReports: const [],
      routeHydraulics: const [],
      zoneReports: const [],
      generatedAt: DateTime(2026, 1, 1),
    );

    expect(report.fileName, contains('report-project'));
    expect(report.pdfBytes.take(4), orderedEquals([37, 80, 68, 70]));
    expect(report.summaryText, isNot(contains('NASA')));
    expect(report.summaryText, isNot(contains('Sentinel-2')));
  });
}
