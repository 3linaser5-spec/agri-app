import 'package:flutter_test/flutter_test.dart';

import 'package:agri_app/models/farm_workspace_models.dart';

void main() {
  group('FarmTask recurrence', () {
    FarmTask task({
      TaskRepeat repeat = TaskRepeat.weekly,
      DateTime? due,
      bool done = false,
    }) =>
        FarmTask(
          id: 'task-1',
          ownerId: 'user-1',
          title: 'ري',
          dueAt: due ?? DateTime(2026, 11, 26, 8),
          repeat: repeat,
          done: done,
        );

    test('weekly task moves seven days after completion', () {
      final next = task().nextOccurrenceAfter(DateTime(2026, 11, 28, 15));
      expect(next, DateTime(2026, 12, 5, 8));
    });

    test('monthly task clamps to the last day of a shorter month', () {
      final next = task(
        repeat: TaskRepeat.monthly,
        due: DateTime(2026, 1, 31, 7, 30),
      ).nextOccurrenceAfter(DateTime(2026, 1, 31));
      expect(next, DateTime(2026, 2, 28, 7, 30));
    });

    test('monthly task rolls over to the next year', () {
      final next = task(
        repeat: TaskRepeat.monthly,
        due: DateTime(2026, 12, 15, 6),
      ).nextOccurrenceAfter(DateTime(2026, 12, 15));
      expect(next, DateTime(2027, 1, 15, 6));
    });

    test('one-off task has no next occurrence', () {
      expect(
        task(repeat: TaskRepeat.none).nextOccurrenceAfter(DateTime.now()),
        isNull,
      );
    });

    test('overdue and due-today ignore completed tasks', () {
      final now = DateTime(2026, 11, 26, 12);
      expect(task(due: DateTime(2026, 11, 20, 8)).isOverdue(now), isTrue);
      expect(
        task(due: DateTime(2026, 11, 20, 8), done: true).isOverdue(now),
        isFalse,
      );
      expect(task(due: DateTime(2026, 11, 26, 6)).isDueToday(now), isTrue);
      expect(task(due: DateTime(2026, 11, 27, 6)).isDueToday(now), isFalse);
    });

    test('upcoming occurrences include the weekly cycle in the window', () {
      final occurrences = task(due: DateTime(2026, 11, 26, 8))
          .upcomingOccurrences(DateTime(2026, 11, 26, 9), days: 15);
      expect(occurrences.first, DateTime(2026, 11, 26, 8));
      expect(occurrences, contains(DateTime(2026, 12, 3, 8)));
      expect(occurrences, contains(DateTime(2026, 12, 10, 8)));
    });

    test('upcoming occurrences of an overdue task start from today', () {
      final occurrences = task(due: DateTime(2026, 11, 1, 8))
          .upcomingOccurrences(DateTime(2026, 11, 26, 9), days: 7);
      expect(occurrences.first.isAfter(DateTime(2026, 11, 26, 8)), isTrue);
      expect(occurrences.length, lessThanOrEqualTo(2));
    });

    test('round-trips through the map representation', () {
      final original = task(
        due: DateTime(2026, 11, 30, 9, 15),
        repeat: TaskRepeat.biweekly,
      ).copyWith(plotId: 'plot-1', notes: 'رطوبة منخفضة');
      final restored = FarmTask.fromMap(original.id, original.toMap());
      expect(restored.dueAt, original.dueAt);
      expect(restored.repeat, TaskRepeat.biweekly);
      expect(restored.plotId, 'plot-1');
      expect(restored.notes, 'رطوبة منخفضة');
    });
  });

  group('CropSeason profit', () {
    CropSeason season({
      double area = 2,
      double expected = 4000,
      double? actual,
      double price = 10,
      List<CropExpense> expenses = const [],
    }) =>
        CropSeason(
          id: 'season-1',
          ownerId: 'user-1',
          crop: 'طماطم',
          areaFeddan: area,
          plantingDate: DateTime(2026, 9, 1),
          harvestDate: DateTime(2026, 12, 20),
          expectedYieldKg: expected,
          actualYieldKg: actual,
          pricePerKg: price,
          expenses: expenses,
        );

    test('uses expected yield until an actual yield is recorded', () {
      expect(season().effectiveYieldKg, 4000);
      expect(season(actual: 3500).effectiveYieldKg, 3500);
    });

    test('computes revenue, expenses, net profit and per-feddan values', () {
      final value = season(
        actual: 5000,
        expenses: [
          CropExpense(label: 'تقاوي', amount: 4000, date: DateTime(2026, 9, 1)),
          CropExpense(label: 'عمالة', amount: 6000, date: DateTime(2026, 10, 1)),
        ],
      );
      expect(value.totalExpenses, 10000);
      expect(value.revenue, 50000);
      expect(value.netProfit, 40000);
      expect(value.profitPerFeddan, 20000);
      expect(value.yieldPerFeddan, 2500);
      expect(value.costPerFeddan, 5000);
      expect(value.marginRatio, closeTo(0.8, 1e-9));
    });

    test('does not divide by zero when the area is missing', () {
      final value = season(area: 0);
      expect(value.profitPerFeddan, 0);
      expect(value.yieldPerFeddan, 0);
    });

    test('summary aggregates seasons correctly', () {
      final summary = CropProfitSummary.fromSeasons([
        season(actual: 5000, expenses: [
          CropExpense(label: 'أ', amount: 10000, date: DateTime(2026, 9, 1)),
        ]),
        season(area: 1, expected: 2000, price: 5),
      ]);
      expect(summary.seasons, 2);
      expect(summary.areaFeddan, 3);
      expect(summary.yieldKg, 7000);
      expect(summary.revenue, 60000);
      expect(summary.expenses, 10000);
      expect(summary.netProfit, 50000);
    });

    test('a loss is reported as a negative margin, not zero', () {
      final value = season(actual: 100, price: 5, expenses: [
        CropExpense(label: 'تقاوي', amount: 5000, date: DateTime(2026, 9, 1)),
      ]);
      expect(value.netProfit, lessThan(0));
      expect(value.marginRatio, lessThan(0));
    });
  });

  test('FarmPlot keeps the owner and site when parsed', () {
    final plot = FarmPlot.fromMap('plot-1', {
      'owner_id': 'user-1',
      'site_id': 'site-1',
      'name': 'القطعة الشمالية',
      'crop': 'برسيم',
      'area_feddan': 1.5,
      'irrigation_method': 'تنقيط',
      'created_at': '2026-11-01T10:00:00.000',
    });
    expect(plot.siteId, 'site-1');
    expect(plot.areaFeddan, 1.5);
    expect(plot.toMap()['owner_id'], 'user-1');
  });
}
