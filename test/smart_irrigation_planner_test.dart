import 'package:flutter_test/flutter_test.dart';

import 'package:agri_app/models/farm_workspace_models.dart';
import 'package:agri_app/models/weather_forecast.dart';
import 'package:agri_app/services/smart_irrigation_planner.dart';

WeatherForecastDay forecastDay(
  DateTime date, {
  double rainMm = 0,
  int? rainProbability,
  double maxC = 30,
  double minC = 16,
  double? et0,
}) =>
    WeatherForecastDay(
      date: date,
      minimumTemperatureC: minC,
      maximumTemperatureC: maxC,
      precipitationMm: rainMm,
      weatherCode: rainMm > 0 ? 61 : 0,
      precipitationProbability: rainProbability,
      et0Mm: et0,
    );

WeatherSnapshot snapshot(List<WeatherForecastDay> days) => WeatherSnapshot(
      currentTemperatureC: 28,
      currentHumidityPercent: 55,
      currentWeatherCode: 0,
      days: days,
    );

FarmTask irrigationTask({
  DateTime? due,
  TaskKind kind = TaskKind.irrigation,
  String title = 'ري القطعة الشمالية',
  String notes = '',
  bool done = false,
}) =>
    FarmTask(
      id: 'task-1',
      ownerId: 'owner-1',
      title: title,
      notes: notes,
      dueAt: due ?? DateTime(2026, 11, 28, 8),
      kind: kind,
      done: done,
    );

void main() {
  final now = DateTime(2026, 11, 27, 9);

  group('isIrrigationTask', () {
    test('uses the explicit kind', () {
      expect(SmartIrrigationPlanner.isIrrigationTask(irrigationTask()), isTrue);
    });

    test('detects irrigation keywords in title or notes', () {
      expect(
        SmartIrrigationPlanner.isIrrigationTask(
          irrigationTask(kind: TaskKind.general, title: 'سقي الخيار'),
        ),
        isTrue,
      );
      expect(
        SmartIrrigationPlanner.isIrrigationTask(
          irrigationTask(
            kind: TaskKind.general,
            title: 'مراجعة الحقل',
            notes: 'قبل الري',
          ),
        ),
        isTrue,
      );
      expect(
        SmartIrrigationPlanner.isIrrigationTask(
          irrigationTask(kind: TaskKind.general, title: 'تسميد'),
        ),
        isFalse,
      );
    });
  });

  group('rain postpones irrigation', () {
    test('moves the task to the day after the last rainy day', () {
      final weather = snapshot([
        forecastDay(DateTime(2026, 11, 27), rainMm: 5, rainProbability: 80),
        forecastDay(DateTime(2026, 11, 28), rainMm: 8, rainProbability: 90),
        forecastDay(DateTime(2026, 11, 29)),
      ]);
      final adjustment =
          SmartIrrigationPlanner.adjust(irrigationTask(), weather, now);
      expect(adjustment, isNotNull);
      expect(adjustment!.action, IrrigationAction.postpone);
      expect(adjustment.suggestedDueAt, DateTime(2026, 11, 29, 8));
      expect(adjustment.changesDay, isTrue);
      expect(adjustment.severity, 3);
      expect(adjustment.waterSavingMm, closeTo(13, 0.01));
      expect(adjustment.headline, contains('أمطار'));
      expect(adjustment.reason, contains('13.0'));
    });

    test('does not move a task due after the rain', () {
      final weather = snapshot([
        forecastDay(DateTime(2026, 11, 27), rainMm: 6, rainProbability: 85),
        forecastDay(DateTime(2026, 11, 28)),
        forecastDay(DateTime(2026, 11, 29)),
        forecastDay(DateTime(2026, 11, 30)),
      ]);
      final task = irrigationTask(due: DateTime(2026, 11, 30, 8));
      expect(SmartIrrigationPlanner.adjust(task, weather, now), isNull);
    });

    test('ignores past rainy days', () {
      final weather = snapshot([
        forecastDay(DateTime(2026, 11, 26), rainMm: 9, rainProbability: 90),
        forecastDay(DateTime(2026, 11, 28), maxC: 28),
      ]);
      expect(
        SmartIrrigationPlanner.adjust(irrigationTask(), weather, now),
        isNull,
      );
    });

    test('probability alone is enough to postpone', () {
      final weather = snapshot([
        forecastDay(DateTime(2026, 11, 28), rainMm: 1, rainProbability: 60),
      ]);
      final adjustment =
          SmartIrrigationPlanner.adjust(irrigationTask(), weather, now);
      expect(adjustment, isNotNull);
      expect(adjustment!.action, IrrigationAction.postpone);
      expect(adjustment.suggestedDueAt, DateTime(2026, 11, 29, 8));
    });
  });

  group('heat advances irrigation to early morning', () {
    test('same day at 6 am', () {
      final weather = snapshot([
        forecastDay(DateTime(2026, 11, 27), maxC: 41),
        forecastDay(DateTime(2026, 11, 28), maxC: 40),
      ]);
      final adjustment =
          SmartIrrigationPlanner.adjust(irrigationTask(), weather, now);
      expect(adjustment, isNotNull);
      expect(adjustment!.action, IrrigationAction.advance);
      expect(adjustment.suggestedDueAt, DateTime(2026, 11, 28, 6));
      expect(adjustment.changesDay, isFalse);
      expect(adjustment.severity, 2);
      expect(adjustment.actionLabel, 'تقديم');
    });

    test('no adjustment when already scheduled at 6 am or earlier', () {
      final weather = snapshot([
        forecastDay(DateTime(2026, 11, 28), maxC: 40),
      ]);
      final task = irrigationTask(due: DateTime(2026, 11, 28, 5, 30));
      expect(SmartIrrigationPlanner.adjust(task, weather, now), isNull);
    });

    test('mild weather means no noise', () {
      final weather = snapshot([
        forecastDay(DateTime(2026, 11, 28), maxC: 30, et0: 6),
      ]);
      expect(
        SmartIrrigationPlanner.adjust(irrigationTask(), weather, now),
        isNull,
      );
    });
  });

  group('guards', () {
    final rainy = snapshot([
      forecastDay(DateTime(2026, 11, 27), rainMm: 10, rainProbability: 95),
    ]);

    test('skips done tasks', () {
      expect(
        SmartIrrigationPlanner.adjust(
          irrigationTask(done: true),
          rainy,
          now,
        ),
        isNull,
      );
    });

    test('skips non-irrigation tasks', () {
      expect(
        SmartIrrigationPlanner.adjust(
          irrigationTask(kind: TaskKind.fertilizing, title: 'تسميد يوريا'),
          rainy,
          now,
        ),
        isNull,
      );
    });

    test('skips tasks far beyond the planning horizon', () {
      expect(
        SmartIrrigationPlanner.adjust(
          irrigationTask(due: DateTime(2026, 12, 10)),
          rainy,
          now,
        ),
        isNull,
      );
    });

    test('empty forecast changes nothing', () {
      expect(
        SmartIrrigationPlanner.adjust(irrigationTask(), snapshot(const []), now),
        isNull,
      );
    });
  });

  group('plan', () {
    test('orders by severity and sums the water saving', () {
      final weather = snapshot([
        forecastDay(DateTime(2026, 11, 27), maxC: 25),
        forecastDay(DateTime(2026, 11, 28), rainMm: 6, rainProbability: 80),
      ]);
      final tasks = [
        FarmTask(
          id: 'heat',
          ownerId: 'owner',
          title: 'ري الصوب',
          dueAt: DateTime(2026, 11, 30, 8),
          kind: TaskKind.irrigation,
        ),
        FarmTask(
          id: 'rain',
          ownerId: 'owner',
          title: 'ري الحقل',
          dueAt: DateTime(2026, 11, 28, 8),
          kind: TaskKind.irrigation,
        ),
        FarmTask(
          id: 'other',
          ownerId: 'owner',
          title: 'صيانة',
          dueAt: DateTime(2026, 11, 28, 8),
        ),
      ];
      final adjustments = SmartIrrigationPlanner.plan(tasks, weather, now);
      expect(adjustments.length, 1);
      expect(adjustments.first.taskId, 'rain');
      expect(
        SmartIrrigationPlanner.totalWaterSaving(adjustments),
        closeTo(6, 0.01),
      );
      expect(
        SmartIrrigationPlanner.topAdjustment(adjustments)?.taskId,
        'rain',
      );
      expect(SmartIrrigationPlanner.topAdjustment(const []), isNull);
    });
  });

  group('FarmTask new fields', () {
    test('map round trip keeps kind, site and assignment', () {
      final task = FarmTask(
        id: 't1',
        ownerId: 'owner',
        siteId: 'site-1',
        plotId: 'plot-1',
        title: 'ري',
        dueAt: DateTime(2026, 11, 28, 7),
        kind: TaskKind.irrigation,
        assignedToUid: 'worker-1',
        assignedToName: 'محمد',
        assignedByUid: 'eng-1',
        memberUids: const ['owner', 'worker-1'],
      );
      final restored = FarmTask.fromMap('t1', task.toMap());
      expect(restored.kind, TaskKind.irrigation);
      expect(restored.siteId, 'site-1');
      expect(restored.assignedToUid, 'worker-1');
      expect(restored.assigneeLabel, 'محمد');
      expect(restored.memberUids, ['owner', 'worker-1']);
      expect(restored.isAssignedTo('worker-1'), isTrue);
      expect(restored.isAssignedTo('other'), isFalse);
    });

    test('legacy task maps default safely', () {
      final restored = FarmTask.fromMap('old', {
        'owner_id': 'owner',
        'title': 'مهمة',
        'due_at': '2026-11-28T08:00:00.000',
        'repeat': 'none',
        'done': false,
        'reminder_enabled': true,
      });
      expect(restored.kind, TaskKind.general);
      expect(restored.siteId, isNull);
      expect(restored.memberUids, isEmpty);
      expect(restored.assigneeLabel, 'مهمة شخصية');
    });
  });
}
