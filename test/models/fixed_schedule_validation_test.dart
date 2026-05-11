import 'package:flutter_test/flutter_test.dart';
import 'package:optivus2/models/fixed_schedule_validation.dart';

void main() {
  group('validateFixedScheduleTemplateCandidate', () {
    test('blocks blank title', () {
      final error = validateFixedScheduleTemplateCandidate(
        title: '   ',
        startTime: '09:00',
        endTime: '10:00',
        existingTemplates: const [],
      );
      expect(error, 'Title cannot be blank.');
    });

    test('blocks overlap unless allowOverlap is true', () {
      final existing = [
        {
          'templateId': 'work_block',
          'title': 'Work',
          'startTime': '09:00',
          'endTime': '10:00',
        },
      ];

      final blocked = validateFixedScheduleTemplateCandidate(
        title: 'Class',
        startTime: '09:30',
        endTime: '10:30',
        existingTemplates: existing,
        allowOverlap: false,
      );
      expect(
        blocked,
        'Time overlaps with another task. Adjust times or allow overlaps.',
      );

      final allowed = validateFixedScheduleTemplateCandidate(
        title: 'Class',
        startTime: '09:30',
        endTime: '10:30',
        existingTemplates: existing,
        allowOverlap: true,
      );
      expect(allowed, isNull);
    });
  });

  group('normalizeFixedScheduleTemplateMap', () {
    test('preserves createdAt when present', () {
      final normalized = normalizeFixedScheduleTemplateMap(
        {
          'templateId': 'focus',
          'title': 'Focus',
          'startTime': '09:00',
          'endTime': '10:00',
          'createdAt': '2026-01-01T00:00:00.000Z',
          'updatedAt': '2026-01-01T00:10:00.000Z',
          'legacyField': 'keep-me',
        },
        index: 0,
      );

      expect(normalized['templateId'], 'focus');
      expect(normalized['createdAt'], '2026-01-01T00:00:00.000Z');
      expect(normalized['legacyField'], 'keep-me');
    });

    test('preserves reminderEnabled and reminderOffsetMinutes', () {
      final normalized = normalizeFixedScheduleTemplateMap(
        {
          'templateId': 'focus',
          'title': 'Focus',
          'startTime': '09:00',
          'endTime': '10:00',
          'reminderEnabled': true,
          'reminderOffsetMinutes': 15,
        },
        index: 0,
      );

      expect(normalized['reminderEnabled'], isTrue);
      expect(normalized['reminderOffsetMinutes'], 15);
    });

    test('safely defaults missing reminderOffsetMinutes', () {
      final normalized = normalizeFixedScheduleTemplateMap(
        {
          'title': 'Focus',
          'startTime': '09:00',
          'endTime': '10:00',
        },
        index: 0,
      );

      expect(normalized['reminderEnabled'], isFalse);
      expect(normalized['reminderOffsetMinutes'], 5); // default
    });
  });
}
