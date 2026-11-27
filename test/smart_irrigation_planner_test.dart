import 'package:flutter_test/flutter_test.dart';

import 'package:agri_app/models/farm_team_models.dart';
import 'package:agri_app/services/irrigation_weather_service.dart';
import 'package:agri_app/services/smart_irrigation_planner.dart';

FarmTask irrigationTask({
  String id = 't1',
  DateTime? dueAt,
  String notes = '',
  bool done = false,
}) =>
    FarmTask(
      id: id,
      ownerId: 'owner',
      title: 'ري',
      dueAt: dueAt ?? DateTime(2026, 11, 27, 7),
      notes: notes,
      kind: TaskKind.irrigation,
      done: done,
    );

IrrigationWeather weather({
  double rainToday = 0,
  double rainTomorrow = 0,
  double popToday = 0,
  double popTomorrow = 0,
  double maxTemp = 30,
}) =>
    IrrigationWeather(
      fetchedAt: DateTime(2026, 11, 26, 20),
      rainTodayMm: rainToday,
      rainTomorrowMm: rainTomorrow,
      rainChanceToday: popToday,
      rainChanceTomorrow: popTomorrow,
      maxTempToday: maxTemp,
      maxTempTomorrow: maxTemp,
    );

void main() {
  group('classify', () {
    final today = DateTime(2026, 11, 27, 7);

    test('pushes irrigation after rain to the day after the rain', () {
      final adjustment = SmartIrrigationPlanner.classify(
        irrigationTask(dueAt: today),
        weather(rainToday: 6, popToday: 80),
        today,
      )!;
      expect(adjustment.action, IrrigationAction.postpone);
      expect(adjustment.suggestedDueAt, DateTime(2026, 11, 28, 7));
      expect(adjustment.severity, greaterThanOrEqualTo(2));
    });

    test('high rain chance alone is enough to postpone', () {
      final adjustment = SmartIrrigationPlanner.classify(
        irrigationTask(dueAt: today),
        weather(popToday: 60),
        today,
      )!;
      expect(adjustment.action, IrrigationAction.postpone);
    });

    test('moves irrigation earlier when it will be very hot', () {
      final adjustment = SmartIrrigationPlanner.classify(
        irrigationTask(dueAt: today),
        weather(maxTemp: 41),
        today,
      )!;
      expect(adjustment.action, IrrigationAction.advance);
      expect(adjustment.suggestedDueAt.hour, 6);
      expect(adjustment.severity, 2);
    });

    test('skips finishing notes and non irrigation tasks', () {
      expect(
        SmartIrrigationPlanner.classify(
          irrigationTask(dueAt: today, notes: 'تم الري أمس'),
          weather(rainToday: 10),
          today,
        ),
        isNull,
      );
      expect(
        SmartIrrigationPlanner.classify(
          FarmTask(
            id: 'x',
            ownerId: 'o',
            title: 'رش',
            dueAt: today,
            kind: TaskKind.spraying,
          ),
          weather(rainToday: 10),
          today,
        ),
        isNull,
      );
    });

    test('done tasks are ignored', () {
      expect(
        SmartIrrigationPlanner.classify(
          irrigationTask(dueAt: today, done: true),
          weather(rainToday: 10),
          today,
        ),
        isNull,
      );
    });
  });

  group('plan', () {
    final now = DateTime(2026, 11, 27, 7);

    test('keeps the most urgent adjustment per task', () {
      final tasks = [
        irrigationTask(id: 'a', dueAt: now),
        irrigationTask(id: 'b', dueAt: now.add(const Duration(days: 3))),
        irrigationTask(id: 'c', dueAt: now, notes: 'تم الري'),
      ];
      final plan = SmartIrrigationPlanner.plan(
        tasks,
        weather(rainToday: 5, rainTomorrow: 2),
        now,
      );
      expect(plan.map((a) => a.taskId).toList(), ['a', 'b']);
      expect(plan.first.suggestedDueAt.day, 29);
    });

    test('total water saving accumulates per feddan', () {
      final plan = SmartIrrigationPlanner.plan(
        [irrigationTask(id: 'a', dueAt: now)],
        weather(rainToday: 5, popToday: 70),
        now,
      );
      expect(plan.single.estimatedWaterSavingMm, greaterThan(0));
      expect(
        SmartIrrigationPlanner.totalWaterSaving(plan),
        plan.single.estimatedWaterSavingMm,
      );
      expect(SmartIrrigationPlanner.totalWaterSaving(const []), 0);
    });

    test('applyTo moves the due date and keeps the note', () {
      final task = irrigationTask(dueAt: now);
      final adjustment = SmartIrrigationPlanner.classify(
        task,
        weather(rainToday: 5),
        now,
      )!;
      final updated = adjustment.applyTo(task);
      expect(updated.dueAt, adjustment.suggestedDueAt);
      expect(updated.notes, contains('الري الذكي'));
      expect(updated.kind, TaskKind.irrigation);
    });
  });
}
