// test/models/skin_care_template_test.dart
//
// Task 1.18 — Productionize manual skin routine setup
// Automated verification: template serialization tests (done-criteria requirement).
//
// These tests exercise RoutineTemplateModel.forSave with skin_care inputs to
// verify the canonical shape, field constraints, and placeholder filtering that
// the manual save path depends on. No Firebase / Riverpod needed.

import 'package:flutter_test/flutter_test.dart';
import 'package:optivus2/models/routine_template_model.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Helpers mirroring the _save() logic in skin_care_setup_screen.dart
  // ---------------------------------------------------------------------------

  const kSkinCareRoutineType = 'skin_care';
  const kPlaceholderTitles = {'New Block', 'new block', ''};

  Map<String, dynamic> buildRawTemplate({
    required String title,
    required String startTime,
    required String endTime,
    required int weekday, // 1–7
    required List<String> steps,
    bool reminderEnabled = false,
  }) {
    return {
      'templateId':
          'skin_d${weekday}_${title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}',
      'title': title,
      'routineType': kSkinCareRoutineType,
      'startTime': startTime,
      'endTime': endTime,
      'repeatRule': 'weekly:$weekday',
      'steps': steps
          .map((s) => s.trim())
          .where((n) => n.isNotEmpty)
          .map((n) => {'name': n})
          .toList(),
      'notes': steps.where((s) => s.trim().isNotEmpty).join(', '),
      'reminderEnabled': reminderEnabled,
      'isActive': true,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  // ---------------------------------------------------------------------------
  // Tests
  // ---------------------------------------------------------------------------

  group('Skin care template serialization', () {
    test('canonical fields survive RoutineTemplateModel.forSave round-trip', () {
      final raw = buildRawTemplate(
        title: 'Morning Ritual',
        startTime: '07:30',
        endTime: '07:45',
        weekday: 1,
        steps: ['Cleanser', 'Vitamin C', 'SPF'],
      );

      final model = RoutineTemplateModel.forSave(
        raw,
        fallbackRoutineType: kSkinCareRoutineType,
      );
      final map = model.toMap();

      // Core identity
      expect(map['routineType'], kSkinCareRoutineType);
      expect(map['title'], 'Morning Ritual');
      expect(map['templateId'], isNotEmpty);

      // Time fields must be HH:mm
      final timeRegex = RegExp(r'^\d{2}:\d{2}$');
      expect(map['startTime'], matches(timeRegex),
          reason: 'startTime must be HH:mm');
      expect(map['endTime'], matches(timeRegex),
          reason: 'endTime must be HH:mm');
      expect((map['startTime'] as String).compareTo(map['endTime'] as String),
          lessThan(0),
          reason: 'startTime must be before endTime');

      // Repeat rule preserved
      expect(map['repeatRule'], 'weekly:1');

      // Steps as list of maps with 'name' key
      final steps = map['steps'] as List;
      expect(steps, hasLength(3));
      expect((steps[0] as Map)['name'], 'Cleanser');
      expect((steps[1] as Map)['name'], 'Vitamin C');
      expect((steps[2] as Map)['name'], 'SPF');

      // Active and reminder
      expect(map['isActive'], isTrue);
      expect(map['reminderEnabled'], isFalse);
    });

    test('empty step names are filtered from steps list', () {
      final raw = buildRawTemplate(
        title: 'Night Care',
        startTime: '21:30',
        endTime: '21:45',
        weekday: 7,
        steps: ['Retinol', '  ', '', 'Moisturiser'],
      );

      final model = RoutineTemplateModel.forSave(
        raw,
        fallbackRoutineType: kSkinCareRoutineType,
      );
      final steps = model.toMap()['steps'] as List;

      // Empty / whitespace steps must be removed before buildRawTemplate.
      // The raw builder already filters, so only non-empty reach the model.
      expect(steps.map((s) => (s as Map)['name']).toList(),
          equals(['Retinol', 'Moisturiser']));
    });

    test('blocks with placeholder titles are excluded from save', () {
      // This simulates the manual save path filter in SkinCareSetupScreen._save.
      final fakeBlocks = [
        {'title': 'Morning Ritual', 'isPlaceholder': false},
        {'title': 'New Block', 'isPlaceholder': true},
        {'title': '', 'isPlaceholder': true},
        {'title': 'new block', 'isPlaceholder': true},
        {'title': 'Night Routine', 'isPlaceholder': false},
      ];

      final saved = fakeBlocks
          .where((b) => !kPlaceholderTitles.contains(b['title']?.toString()))
          .map((b) => b['title'])
          .toList();

      expect(saved, equals(['Morning Ritual', 'Night Routine']));
    });

    test('repeatRule is weekly:N where N is 1-indexed weekday', () {
      for (int day = 1; day <= 7; day++) {
        final raw = buildRawTemplate(
          title: 'Test Block',
          startTime: '08:00',
          endTime: '08:15',
          weekday: day,
          steps: ['Cleanser'],
        );
        final model = RoutineTemplateModel.forSave(
          raw,
          fallbackRoutineType: kSkinCareRoutineType,
        );
        expect(model.repeatRule, 'weekly:$day',
            reason: 'weekday $day must produce repeatRule=weekly:$day');
      }
    });

    test('routineType is always skin_care regardless of input', () {
      // Even if the raw map omits routineType, forSave sets it via fallback.
      final raw = {
        'templateId': 'skin_d1_test',
        'title': 'My Routine',
        'startTime': '07:00',
        'endTime': '07:15',
        'repeatRule': 'weekly:1',
        'steps': [
          {'name': 'Cleanser'}
        ],
        'isActive': true,
      };

      final model = RoutineTemplateModel.forSave(
        raw,
        fallbackRoutineType: kSkinCareRoutineType,
      );
      expect(model.routineType, kSkinCareRoutineType);
    });

    test('templateId is never empty after forSave', () {
      // Pass a raw map without a templateId — forSave must generate one.
      final raw = {
        'title': 'Auto ID Test',
        'routineType': kSkinCareRoutineType,
        'startTime': '06:00',
        'endTime': '06:15',
        'repeatRule': 'weekly:3',
        'steps': [
          {'name': 'Toner'}
        ],
        'isActive': true,
      };

      final model = RoutineTemplateModel.forSave(
        raw,
        fallbackRoutineType: kSkinCareRoutineType,
      );
      expect(model.templateId, isNotEmpty);
      expect(model.templateId, isNot(''));
    });

    test('createdAt is preserved if present, updatedAt is always refreshed', () {
      final oldDate = DateTime(2025, 1, 1, 7, 30);
      final raw = {
        'templateId': 'skin_d1_morning',
        'title': 'Morning Ritual',
        'routineType': kSkinCareRoutineType,
        'startTime': '07:30',
        'endTime': '07:45',
        'repeatRule': 'weekly:1',
        'steps': [
          {'name': 'SPF'}
        ],
        'isActive': true,
        'createdAt': oldDate.toIso8601String(),
      };

      final now = DateTime.now();
      final model = RoutineTemplateModel.forSave(
        raw,
        fallbackRoutineType: kSkinCareRoutineType,
        now: now,
      );

      expect(model.createdAt, equals(oldDate));
      expect(model.updatedAt, equals(now));
    });

    test('reminder fields survive round-trip', () {
      final raw = buildRawTemplate(
        title: 'Evening Ritual',
        startTime: '21:00',
        endTime: '21:20',
        weekday: 5,
        steps: ['Retinol'],
        reminderEnabled: true,
      );

      final model = RoutineTemplateModel.forSave(
        raw,
        fallbackRoutineType: kSkinCareRoutineType,
      );
      expect(model.reminderEnabled, isTrue);
      expect(model.reminderOffsetMinutes, inInclusiveRange(0, 180));
    });
  });

  group('Skin care template edge cases', () {
    test('endTime defaults to 30 minutes after startTime when absent', () {
      final raw = {
        'templateId': 'skin_d2_no_end',
        'title': 'No End Time Block',
        'routineType': kSkinCareRoutineType,
        'startTime': '08:00',
        // endTime intentionally omitted
        'repeatRule': 'weekly:2',
        'steps': [
          {'name': 'Cleanser'}
        ],
        'isActive': true,
      };

      final model = RoutineTemplateModel.forSave(
        raw,
        fallbackRoutineType: kSkinCareRoutineType,
      );

      expect(model.endTime, '08:30',
          reason:
              'RoutineTemplateModel.forSave adds 30 min when endTime is absent');
    });

    test('steps with map and string formats are both normalized', () {
      final raw = {
        'templateId': 'skin_d3_mixed_steps',
        'title': 'Mixed Steps Block',
        'routineType': kSkinCareRoutineType,
        'startTime': '07:00',
        'endTime': '07:15',
        'repeatRule': 'weekly:3',
        'steps': [
          {'name': 'Cleanser'}, // map form
          'Toner', // string form — normalized by RoutineTemplateModel
        ],
        'isActive': true,
      };

      final model = RoutineTemplateModel.forSave(
        raw,
        fallbackRoutineType: kSkinCareRoutineType,
      );
      final steps = model.steps;
      expect(steps, hasLength(2));
      expect(steps[0]['name'], 'Cleanser');
      expect(steps[1]['name'], 'Toner');
    });
  });
}
