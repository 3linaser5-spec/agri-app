import 'package:flutter_test/flutter_test.dart';

import 'package:agri_app/models/farm_workspace_models.dart';
import 'package:agri_app/services/season_comparison_service.dart';

CropSeason season({
  required String id,
  required String crop,
  required DateTime planting,
  String variety = '',
  double area = 1,
  double yieldKg = 1000,
  double pricePerKg = 10,
  List<CropExpense> expenses = const [],
  DateTime? harvest,
}) =>
    CropSeason(
      id: id,
      ownerId: 'owner',
      crop: crop,
      variety: variety,
      areaFeddan: area,
      plantingDate: planting,
      harvestDate: harvest,
      actualYieldKg: yieldKg,
      pricePerKg: pricePerKg,
      expenses: expenses,
    );

void main() {
  final tomato2025 = season(
    id: 'a',
    crop: 'طماطم',
    variety: 'هجين',
    planting: DateTime(2025, 9, 1),
    area: 2,
    yieldKg: 8000,
    pricePerKg: 5,
    expenses: [
      CropExpense(label: 'سماد', amount: 6000, date: DateTime(2025, 9, 10)),
      CropExpense(label: 'عمالة', amount: 4000, date: DateTime(2025, 10, 1)),
    ],
    harvest: DateTime(2025, 10, 1),
  );
  final tomato2026 = season(
    id: 'b',
    crop: 'طماطم',
    planting: DateTime(2026, 9, 5),
    area: 1,
    yieldKg: 5000,
    pricePerKg: 6,
    expenses: [
      CropExpense(label: 'سماد', amount: 9000, date: DateTime(2026, 9, 12)),
    ],
  );

  group('metrics', () {
    test('are normalized per feddan', () {
      final metrics = SeasonMetrics.fromSeason(
        tomato2025,
        now: DateTime(2025, 10, 1),
      );
      expect(metrics.areaFeddan, 2);
      expect(metrics.yieldPerFeddan, 4000);
      expect(metrics.revenue, 40000);
      expect(metrics.expenses, 10000);
      expect(metrics.costPerFeddan, 5000);
      expect(metrics.netProfit, 30000);
      expect(metrics.profitPerFeddan, 15000);
      expect(metrics.marginRatio, closeTo(0.75, 0.0001));
      expect(metrics.daysInSeason, 30);
    });

    test('zero area does not divide by zero', () {
      final zero = season(id: 'z', crop: 'قمح', planting: DateTime(2026), area: 0);
      final metrics = SeasonMetrics.fromSeason(zero);
      expect(metrics.yieldPerFeddan, 0);
      expect(metrics.profitPerFeddan, 0);
      expect(metrics.costPerFeddan, 0);
    });
  });

  group('comparison', () {
    late SeasonComparison comparison;

    setUp(() {
      comparison = SeasonComparisonService.compare(tomato2025, tomato2026)!;
    });

    test('compares two different seasons', () {
      expect(comparison, isNotNull);
      expect(SeasonComparisonService.compare(tomato2025, tomato2025), isNull);
    });

    test('computes deltas per feddan', () {
      expect(comparison.profitPerFeddanDelta, 6000);
      expect(comparison.profitDelta, -9000);
      expect(comparison.costPerFeddanDelta, 4000);
      expect(comparison.marginDelta, closeTo(-0.05, 0.0001));
      expect(comparison.profitChangeRatio, closeTo(-0.3, 0.0001));
      expect(comparison.betterSeason.id, 'b');
    });

    test('verdict names the better season with the difference', () {
      expect(comparison.verdict, contains('الثاني'));
      expect(comparison.verdict, contains('6000'));
    });

    test('labels and share text include crop and year', () {
      expect(SeasonComparisonService.seasonLabel(tomato2025), contains('طماطم'));
      expect(SeasonComparisonService.seasonLabel(tomato2025), contains('2025'));
      expect(SeasonComparisonService.seasonLabel(tomato2025), contains('هجين'));
      final text = SeasonComparisonService.shareText(comparison);
      expect(text, contains('مقارنة المواسم'));
      expect(text, contains('الربح لكل فدان'));
      expect(text, contains(comparison.verdict));
    });
  });

  group('selection helpers', () {
    final seasons = [tomato2025, tomato2026];

    test('automatic picks the newest season and its previous same crop', () {
      final automatic = SeasonComparisonService.automatic(seasons);
      expect(automatic, isNotNull);
      expect(automatic!.second.id, 'b');
      expect(automatic.first.id, 'a');
    });

    test('automatic falls back to the second newest of any crop', () {
      final wheat = season(
        id: 'w',
        crop: 'قمح',
        planting: DateTime(2026, 11, 1),
      );
      final automatic =
          SeasonComparisonService.automatic([tomato2025, wheat, tomato2026]);
      expect(automatic!.second.crop, 'قمح');
      expect(automatic.first.crop, 'طماطم');
    });

    test('automatic returns null with fewer than two seasons', () {
      expect(SeasonComparisonService.automatic([tomato2025]), isNull);
      expect(SeasonComparisonService.automatic(const []), isNull);
    });

    test('latestTwo and seasonsForCrop', () {
      expect(
        SeasonComparisonService.latestTwo(seasons).first.id,
        'b',
      );
      expect(
        SeasonComparisonService
            .seasonsForCrop(seasons, 'طماطم')
            .map((season) => season.id)
            .toList(),
        ['a', 'b'],
      );
      expect(
        SeasonComparisonService.seasonsForCrop(seasons, 'قمح'),
        isEmpty,
      );
    });

    test('yearly summaries aggregate by planting year', () {
      final summaries = SeasonComparisonService.yearlySummaries([
        tomato2025,
        tomato2026,
        season(id: 'c', crop: 'قمح', planting: DateTime(2026, 11), area: 3),
      ]);
      expect(summaries.length, 2);
      expect(summaries.first.year, 2025);
      expect(summaries.first.summary.seasons, 1);
      expect(summaries.last.year, 2026);
      expect(summaries.last.summary.seasons, 2);
      expect(summaries.last.profitPerFeddan, isNot(0));
      expect(summaries.last.seasons, 2);
    });

    test('best per crop keeps the highest profit per feddan', () {
      final best = SeasonComparisonService.bestPerCrop(seasons);
      expect(best['طماطم']!.id, 'b');
    });
  });
}
