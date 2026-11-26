import 'package:flutter_test/flutter_test.dart';

import 'package:agri_app/models/farm_workspace_models.dart';

void main() {
  group('FarmTask edge cases', () {
    test('daily occurrences fill the requested window without duplicates', () {
      final task = FarmTask(
        id: 't',
        ownerId: 'u',
        title: 'رش',
        dueAt: DateTime(2026, 11, 20, 7),
        repeat: TaskRepeat.daily,
      );
      final occurrences =
          task.upcomingOccurrences(DateTime(2026, 11, 26, 9), days: 2);
      expect(occurrences, isNotEmpty);
      expect(occurrences.length, lessThanOrEqualTo(3));
      expect(occurrences.toSet().length, occurrences.length);
      for (final occurrence in occurrences) {
        expect(occurrence.isAfter(DateTime(2026, 11, 26)), isTrue);
      }
    });

    test('a one-off overdue task has no upcoming occurrences', () {
      final task = FarmTask(
        id: 't',
        ownerId: 'u',
        title: 'حصاد',
        dueAt: DateTime(2026, 11, 1, 7),
      );
      expect(task.upcomingOccurrences(DateTime(2026, 11, 26), days: 7), isEmpty);
    });

    test('copyWith keeps untouched fields', () {
      final task = FarmTask(
        id: 't',
        ownerId: 'u',
        title: 'ري',
        notes: 'ملاحظة',
        dueAt: DateTime(2026, 11, 26, 8),
        repeat: TaskRepeat.monthly,
        reminderEnabled: false,
      );
      final updated = task.copyWith(title: 'ري عميق', done: true);
      expect(updated.title, 'ري عميق');
      expect(updated.done, isTrue);
      expect(updated.notes, 'ملاحظة');
      expect(updated.repeat, TaskRepeat.monthly);
      expect(updated.reminderEnabled, isFalse);
      expect(updated.id, 't');
    });

    test('parsing tolerates missing and malformed fields', () {
      final task = FarmTask.fromMap('x', {
        'title': '  ',
        'due_at': 'not-a-date',
        'repeat': 'unknown',
        'done': 'yes',
        'reminder_enabled': null,
      });
      expect(task.title, 'مهمة');
      expect(task.repeat, TaskRepeat.none);
      expect(task.done, isFalse);
      expect(task.reminderEnabled, isTrue);
      expect(task.plotId, isNull);
    });
  });

  group('CropSeason edges', () {
    test('parses expenses and ignores malformed entries', () {
      final season = CropSeason.fromMap('s', {
        'crop': 'ذرة',
        'area_feddan': '3',
        'planting_date': '2026-05-01T00:00:00.000',
        'harvest_date': null,
        'expected_yield_kg': 1000,
        'actual_yield_kg': null,
        'price_per_kg': 8,
        'expenses': [
          {'label': 'سماد', 'amount': 500, 'date': '2026-05-02T00:00:00.000'},
          'invalid',
          {'amount': 'x'},
        ],
      });
      expect(season.areaFeddan, 3);
      expect(season.expenses.length, 2);
      expect(season.expenses.first.amount, 500);
      expect(season.effectiveYieldKg, 1000);
      expect(season.harvestDate, isNull);
    });

    test('copyWith replaces only the requested values', () {
      final season = CropSeason(
        id: 's',
        ownerId: 'u',
        crop: 'بصل',
        areaFeddan: 1,
        plantingDate: DateTime(2026, 1, 1),
        expectedYieldKg: 1000,
        pricePerKg: 5,
      );
      final updated = season.copyWith(
        actualYieldKg: 1200,
        harvestDate: DateTime(2026, 5, 1),
      );
      expect(updated.actualYieldKg, 1200);
      expect(updated.expectedYieldKg, 1000);
      expect(updated.harvestDate, DateTime(2026, 5, 1));
      expect(updated.crop, 'بصل');
    });

    test('days in season use the harvest date when available', () {
      final season = CropSeason(
        id: 's',
        ownerId: 'u',
        crop: 'بصل',
        plantingDate: DateTime(2026, 1, 1),
        harvestDate: DateTime(2026, 1, 31),
      );
      expect(season.daysInSeason(DateTime(2026, 6, 1)), 30);
      final open = CropSeason(
        id: 's2',
        ownerId: 'u',
        crop: 'بصل',
        plantingDate: DateTime(2026, 1, 1),
      );
      expect(open.daysInSeason(DateTime(2026, 1, 11)), 10);
    });

    test('an empty summary reports zeros instead of crashing', () {
      final summary = CropProfitSummary.fromSeasons(const []);
      expect(summary.seasons, 0);
      expect(summary.profitPerFeddan, 0);
      expect(summary.marginRatio, 0);
    });

    test('FarmSite parsing falls back to a readable name', () {
      final site = FarmSite.fromMap('site', {
        'owner_id': 'u',
        'name': '',
        'created_at': null,
      });
      expect(site.name, 'مزرعة بدون اسم');
      expect(site.createdAt, isNotNull);
      expect(site.toMap()['owner_id'], 'u');
    });
  });
}
