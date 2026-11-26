import 'package:flutter_test/flutter_test.dart';

import 'package:agri_app/models/farm_workspace_models.dart';
import 'package:agri_app/models/irrigation_design_models.dart';
import 'package:agri_app/services/farm_report_service.dart';

void main() {
  CropSeason season({
    double area = 2,
    double expected = 2000,
    double? actual = 1800,
    double price = 12,
  }) =>
      CropSeason(
        id: 's',
        ownerId: 'u',
        crop: 'قمح',
        areaFeddan: area,
        plantingDate: DateTime(2026, 11, 1),
        expectedYieldKg: expected,
        actualYieldKg: actual,
        pricePerKg: price,
        expenses: [
          CropExpense(label: 'تقاوي', amount: 3000, date: DateTime(2026, 11, 2)),
        ],
      );

  IrrigationDesignProject project() => IrrigationDesignProject(
        id: 'p1',
        nameAr: 'حديقة المنزل',
        siteBoundary: SiteBoundary(
          id: 'b1',
          declaredArea: 800,
          points: const [
            GeoCoordinate(latitude: 30, longitude: 31),
            GeoCoordinate(latitude: 30, longitude: 31.01),
            GeoCoordinate(latitude: 30.01, longitude: 31.01),
          ],
        ),
        zones: [
          IrrigationZone(
            id: 'z1',
            nameAr: 'الحوش',
            method: 'drip',
            areaM2: 800,
            designFlowLpm: 30,
            applicationRateMmH: 4,
          ),
        ],
        pump: Pump(
          id: 'pump',
          type: 'centrifugal',
          flowRateLpm: 30,
          headM: 20,
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

  test('tasks CSV contains a header and one row per task', () {
    final tasks = [
      FarmTask(
        id: 'a',
        ownerId: 'u',
        title: 'ري "شمالي"',
        dueAt: DateTime(2026, 11, 26, 8),
        repeat: TaskRepeat.weekly,
        done: true,
      ),
      FarmTask(
        id: 'b',
        ownerId: 'u',
        title: 'تسميد',
        notes: 'بعد الري',
        dueAt: DateTime(2026, 11, 27, 8),
      ),
    ];
    final csv = FarmReportService.csvForTasks(tasks);
    final lines = csv.trim().split('\n');
    expect(lines.first, contains('المهمة'));
    expect(lines.length, 3);
    // علامات التنصيص داخل النص تُضاعف حتى يفتح الملف في Excel بشكل سليم.
    expect(csv, contains('"ري ""شمالي"""'));
    expect(csv, contains('"منجزة"'));
    expect(csv, contains('"قيد الانتظار"'));
    expect(csv, contains('26/11/2026'));
  });

  test('crop CSV includes profit columns and computed totals', () {
    final csv = FarmReportService.csvForCropSeasons([season()]);
    expect(csv, contains('صافي الربح'));
    expect(csv, contains('"1800"'));
    expect(csv, contains('"18600"')); // 1800×12 − 3000
    expect(csv, contains('"2.00"'));
  });

  test('crop CSV leaves the harvest date empty when missing', () {
    final csv = FarmReportService.csvForCropSeasons([season()]);
    final row = csv.trim().split('\n')[1];
    expect(row, contains('"قمح"'));
    expect(row, contains(',"",'));
  });

  test('empty collections still produce a valid header-only CSV', () {
    expect(FarmReportService.csvForTasks(const []).trim().split('\n').length, 1);
    expect(
      FarmReportService.csvForCropSeasons(const []).trim().split('\n').length,
      1,
    );
  });

  test('dates are formatted day/month/year', () {
    expect(FarmReportService.formatDate(DateTime(2026, 1, 5)), '5/1/2026');
  });

  test('crop summary text includes every key figure', () {
    final summary = CropProfitSummary.fromSeasons([season()]);
    final text = FarmReportService.cropSummaryText(summary);
    expect(text, contains('18600'));
    expect(text, contains('3000'));
    expect(text, contains('فدان'));
    expect(
      FarmReportService.cropSummaryText(summary, title: 'موسم القمح'),
      contains('موسم القمح'),
    );
  });

  test('design summary text lists the zones and totals', () {
    final text = FarmReportService.designSummaryText(project());
    expect(text, contains('حديقة المنزل'));
    expect(text, contains('800'));
    expect(text, contains('الحوش'));
    expect(text, contains('30.0'));
    expect(text, contains('نباتي'));
  });

  test('design summary falls back to the zone id when it has no name', () {
    final design = IrrigationDesignProject(
      id: 'p2',
      nameEn: 'Garden',
      siteBoundary: SiteBoundary(
        id: 'b2',
        points: const [
          GeoCoordinate(latitude: 30, longitude: 31),
          GeoCoordinate(latitude: 30, longitude: 31.01),
          GeoCoordinate(latitude: 30.01, longitude: 31.01),
        ],
      ),
      zones: [
        IrrigationZone(
          id: 'zone-x',
          method: 'drip',
          areaM2: 100,
          designFlowLpm: 10,
          applicationRateMmH: 2,
        ),
      ],
      pump: Pump(
        id: 'pump',
        type: 'centrifugal',
        flowRateLpm: 10,
        headM: 20,
        powerKw: 1,
        efficiency: .7,
      ),
      version: DesignVersion(
        major: 1,
        minor: 0,
        patch: 0,
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    final text = FarmReportService.designSummaryText(design);
    expect(text, contains('Garden'));
    expect(text, contains('zone-x'));
  });
}
