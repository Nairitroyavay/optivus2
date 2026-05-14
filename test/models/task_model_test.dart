import 'package:flutter_test/flutter_test.dart';
import 'package:optivus2/models/task_model.dart';

void main() {
  group('TaskModel Idempotency', () {
    test('buildRoutineInstanceKey generates stable deterministic IDs', () {
      final start = DateTime(2026, 5, 13, 9, 0);
      final end = DateTime(2026, 5, 13, 10, 0);

      final key1 = buildRoutineInstanceKey(
        scheduledDate: '2026-05-13',
        sourceRoutineType: 'fixed_schedule',
        templateId: 'tpl_abc_123',
        title: 'Sleep',
        plannedStart: start,
        plannedEnd: end,
      );

      final key2 = buildRoutineInstanceKey(
        scheduledDate: '2026-05-13',
        sourceRoutineType: 'fixed_schedule',
        templateId: 'tpl_abc_123',
        title: 'Sleep',
        plannedStart: start,
        plannedEnd: end,
      );

      expect(key1, key2);
      expect(key1, 'routine_2026-05-13_fixed_schedule_tpl_abc_123_0900_1000');
    });

    test(
        'buildRoutineInstanceKey generates fallback IDs when templateId is empty',
        () {
      final start = DateTime(2026, 5, 13, 9, 0);
      final end = DateTime(2026, 5, 13, 10, 0);

      final key = buildRoutineInstanceKey(
        scheduledDate: '2026-05-13',
        sourceRoutineType: 'fixed_schedule',
        templateId: '',
        title: 'Morning Run',
        plannedStart: start,
        plannedEnd: end,
      );

      expect(key, 'routine_2026-05-13_fixed_schedule_morning_run_0900_1000');
    });

    test('buildRoutineInstanceKey correctly normalizes inputs', () {
      final start = DateTime(2026, 5, 13, 15, 30);
      final end = DateTime(2026, 5, 13, 16, 45);

      final key = buildRoutineInstanceKey(
        scheduledDate: '2026-05-13',
        sourceRoutineType: '  SKIN care!! ',
        templateId: '   ',
        title: '  @# My Routine !! ',
        plannedStart: start,
        plannedEnd: end,
      );

      expect(key, 'routine_2026-05-13_skin_care_my_routine_1530_1645');
    });
  });
}
