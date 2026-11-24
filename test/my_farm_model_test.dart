import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agri_app/models/my_farm_model.dart';

void main() {
  group('MyFarmProgram progress and task planning', () {
    test('done task indexes are filtered, de-duplicated and sorted', () {
      final program = _program().copyWithDoneTasks([2, 0, 0, 9, -1, 1]);

      expect(program.doneTasks, [0, 1, 2]);
      expect(program.doneCount, 3);
      expect(program.progress, 1);
      expect(program.isCompleted, isTrue);
      expect(program.status, 'completed');
    });

    test('partial completion keeps the program active', () {
      final program = _program().copyWithDoneTasks([0]);

      expect(program.progress, closeTo(1 / 3, 1e-9));
      expect(program.isCompleted, isFalse);
      expect(program.status, 'active');
      expect(program.isTaskDone(0), isTrue);
      expect(program.isTaskDone(1), isFalse);
    });

    test('splits tasks into today, overdue and next', () {
      final program = _program();

      expect(program.daysSinceStart, 0);
      expect(program.todayTasks.single['title'], 'ري');
      expect(program.overdueTasks.single['title'], 'تسميد');
      expect(program.nextTask?['title'], 'ري');
    });

    test('days since start and time progress follow the calendar', () {
      final program = _program(startDate: _todayMinus(3));

      expect(program.daysSinceStart, 3);
      expect(program.timeProgress, closeTo(3 / 5, 1e-9));
    });

    test('an empty task list has no progress', () {
      final program = _program(tasks: const []);

      expect(program.progress, 0);
      expect(program.timeProgress, 0);
      expect(program.isCompleted, isFalse);
      expect(program.nextTask, isNull);
    });
  });

  group('MyFarmProgram.fromData', () {
    test('parses stored fields and defaults the missing ones', () {
      final program = MyFarmProgram.fromData('farm-1', {
        'user_id': 'user-1',
        'template_name': 'طماطم',
        'tasks': [
          {'title': 'ري', 'day_from_start': 0},
          {'title': 'حصاد', 'day_from_start': '5'},
          'نص غير صالح',
        ],
        'done_tasks': ['0', 5, -2],
        'start_date': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
      });

      expect(program.id, 'farm-1');
      expect(program.userId, 'user-1');
      expect(program.templateEmoji, '🌱');
      expect(program.areaUnit, 'فدان');
      expect(program.status, 'active');
      expect(program.tasks, hasLength(2));
      expect(program.doneTasks, [0]);
      expect(program.inputValues, isEmpty);
      expect(
        program.startDate.isAtSameMomentAs(DateTime.utc(2026, 1, 1)),
        isTrue,
      );
    });

    test('ignores a malformed done_tasks field and bad maps', () {
      final program = MyFarmProgram.fromData('farm-2', {
        'tasks': 'not-a-list',
        'done_tasks': 'not-a-list',
        'input_values': 42,
        'start_date': 'invalid',
      });

      expect(program.tasks, isEmpty);
      expect(program.doneTasks, isEmpty);
      expect(program.inputValues, isEmpty);
    });
  });

  group('copyWithIrrigationPlan', () {
    test('keeps the rest of the program untouched', () {
      final program = _program().copyWithDoneTasks([0]);
      final updated = program.copyWithIrrigationPlan({'mode': 'drip'});

      expect(updated.irrigationPlan, {'mode': 'drip'});
      expect(updated.doneTasks, [0]);
      expect(updated.status, 'active');
      expect(updated.id, program.id);
      expect(program.irrigationPlan, isEmpty);
    });
  });
}

DateTime _todayMinus(int days) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day).subtract(Duration(days: days));
}

MyFarmProgram _program({
  List<Map<String, dynamic>>? tasks,
  DateTime? startDate,
}) =>
    MyFarmProgram(
      id: 'farm-1',
      userId: 'user-1',
      templateId: 'tomato',
      templateName: 'طماطم',
      templateEmoji: '🍅',
      sectionId: 'vegetables',
      sectionName: 'خضروات',
      governorate: 'القاهرة',
      climateZone: 'B',
      inputValues: const {},
      tasks: tasks ??
          const [
            {'title': 'ري', 'day_from_start': 0},
            {'title': 'تسميد', 'day_from_start': -1},
            {'title': 'حصاد', 'day_from_start': 5},
          ],
      materials: const [],
      financial: const {},
      startDate: startDate ?? DateTime.now(),
      createdAt: DateTime.now(),
    );
