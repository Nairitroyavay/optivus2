// test/models/supplement_template_test.dart
//
// Pure-Dart unit tests for supplement template parsing and validation helpers.
// No Firebase dependencies.
//
// Covers:
//   • _SupplementItem.toTemplate() canonical field contract
//   • _validate() blocks empty name / empty dosage / bad time
//   • _normalizeTime() accepts valid times, falls back on garbage
//   • _normalizeTimingRule() canonicalises known and unknown values
//   • RoutineTemplateModel.forSave() round-trips supplement map (timingRule in extra)

import 'package:flutter_test/flutter_test.dart';
import 'package:optivus2/models/routine_template_model.dart';

// ── Private helpers mirrored from supplement_setup_screen.dart ───────────────
// These are private to the screen so we replicate them here for pure-Dart tests.

String _normalizeTime(String raw) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(raw.trim());
  if (match == null) return '08:00';
  final hour = (int.tryParse(match.group(1)!) ?? 8).clamp(0, 23);
  final minute = (int.tryParse(match.group(2)!) ?? 0).clamp(0, 59);
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

String _normalizeTimingRule(String raw) {
  final clean = raw.trim().toLowerCase();
  const allowed = {
    'after breakfast',
    'after workout',
    'after lunch',
    'before bed',
  };
  if (allowed.contains(clean)) return clean;
  if (clean.contains('workout') || clean.contains('exercise')) {
    return 'after workout';
  }
  if (clean.contains('lunch')) return 'after lunch';
  if (clean.contains('bed') || clean.contains('night')) return 'before bed';
  return 'after breakfast';
}

String _endTime(String startTime, int durationMinutes) {
  final parts = startTime.split(':');
  final hour = int.tryParse(parts.first) ?? 8;
  final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  final start = DateTime(2026, 1, 1, hour, minute);
  final end = start.add(Duration(minutes: durationMinutes));
  return '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
}

/// Minimal mirror of _SupplementItem.toTemplate() for pure-Dart testing.
Map<String, dynamic> _toTemplate({
  required String templateId,
  required String title,
  required String dosage,
  required String time,
  int durationMinutes = 5,
  String repeatRule = 'daily',
  String timingRule = 'after breakfast',
  String notes = '',
  List<String> warnings = const [],
  double confidence = 0.75,
  bool reminderEnabled = false,
}) {
  final now = DateTime.now().toIso8601String();
  return {
    'templateId': templateId,
    'title': title.trim(),
    'routineType': 'supplements',
    'startTime': time,
    'endTime': _endTime(time, durationMinutes),
    'repeatRule': repeatRule,
    'timingRule': timingRule,
    'weekdayRule': repeatRule,
    'dosage': dosage.trim(),
    'notes': notes.trim(),
    'warnings': warnings,
    'confidence': confidence,
    'reminderEnabled': reminderEnabled,
    'isActive': true,
    'createdAt': now,
    'updatedAt': now,
  };
}

/// Minimal validation mirror of _SupplementSetupScreenState._validate().
String? _validate(List<Map<String, dynamic>> items) {
  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    final title = (item['title'] as String? ?? '').trim();
    final dosage = (item['dosage'] as String? ?? '').trim();
    final time = (item['time'] as String? ?? '');
    final label = 'Supplement ${i + 1}';
    if (title.isEmpty) return '$label: name is required.';
    if (dosage.isEmpty) return '$label ($title): dosage is required.';
    final timeOk = RegExp(r'^\d{2}:\d{2}$').hasMatch(time);
    if (!timeOk) return '$label ($title): time must be in HH:MM format.';
  }
  return null;
}

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('_toTemplate() — canonical field contract', () {
    test('emits all required fields', () {
      final map = _toTemplate(
        templateId: 'vit_d',
        title: 'Vitamin D',
        dosage: '1000 IU',
        time: '08:00',
        timingRule: 'after breakfast',
        notes: 'Take with food',
      );

      expect(map['templateId'], 'vit_d');
      expect(map['title'], 'Vitamin D');
      expect(map['routineType'], 'supplements');
      expect(map['startTime'], '08:00');
      expect(map['endTime'], '08:05'); // +5 min default duration
      expect(map['repeatRule'], 'daily');
      expect(map['timingRule'], 'after breakfast');
      expect(map['dosage'], '1000 IU');
      expect(map['notes'], 'Take with food');
      expect(map['isActive'], true);
      expect(map['reminderEnabled'], false);
      expect(map['warnings'], isA<List>());
      expect(map['createdAt'], isNotEmpty);
      expect(map['updatedAt'], isNotEmpty);
    });

    test('trims whitespace from title and dosage', () {
      final map = _toTemplate(
        templateId: 'id1',
        title: '  Creatine  ',
        dosage: ' 5 g  ',
        time: '08:00',
      );
      expect(map['title'], 'Creatine');
      expect(map['dosage'], '5 g');
    });

    test('endTime is 5 minutes after startTime by default', () {
      final map = _toTemplate(
        templateId: 'id2',
        title: 'Omega 3',
        dosage: '1 capsule',
        time: '13:00',
      );
      expect(map['startTime'], '13:00');
      expect(map['endTime'], '13:05');
    });

    test('reminderEnabled true is preserved', () {
      final map = _toTemplate(
        templateId: 'id3',
        title: 'Magnesium',
        dosage: '400 mg',
        time: '22:00',
        reminderEnabled: true,
      );
      expect(map['reminderEnabled'], true);
    });

    test('weeklyRule is copied from repeatRule', () {
      final map = _toTemplate(
        templateId: 'id4',
        title: 'Protein',
        dosage: '1 scoop',
        time: '18:30',
        repeatRule: 'weekly:1,2,3,4,5',
      );
      expect(map['weekdayRule'], 'weekly:1,2,3,4,5');
    });
  });

  // ── _normalizeTime ──────────────────────────────────────────────────────────

  group('_normalizeTime()', () {
    test('passes valid HH:MM unchanged', () {
      expect(_normalizeTime('08:30'), '08:30');
      expect(_normalizeTime('22:00'), '22:00');
      expect(_normalizeTime('00:00'), '00:00');
    });

    test('pads single-digit hour', () {
      expect(_normalizeTime('8:00'), '08:00');
      expect(_normalizeTime('9:30'), '09:30');
    });

    test('falls back to 08:00 on garbage input', () {
      expect(_normalizeTime('not-a-time'), '08:00');
      expect(_normalizeTime(''), '08:00');
      expect(_normalizeTime('99:99'), '23:59'); // clamp
    });

    test('clamps out-of-range hours and minutes', () {
      expect(_normalizeTime('25:00'), '23:00'); // hour clamped to 23
      expect(_normalizeTime('08:61'), '08:59'); // minute clamped to 59
    });
  });

  // ── _normalizeTimingRule ────────────────────────────────────────────────────

  group('_normalizeTimingRule()', () {
    test('returns exact known values unchanged', () {
      expect(_normalizeTimingRule('after breakfast'), 'after breakfast');
      expect(_normalizeTimingRule('after workout'), 'after workout');
      expect(_normalizeTimingRule('after lunch'), 'after lunch');
      expect(_normalizeTimingRule('before bed'), 'before bed');
    });

    test('handles case-insensitive known values', () {
      expect(_normalizeTimingRule('After Breakfast'), 'after breakfast');
      expect(_normalizeTimingRule('BEFORE BED'), 'before bed');
    });

    test('maps workout synonyms', () {
      expect(_normalizeTimingRule('post exercise'), 'after workout');
      expect(_normalizeTimingRule('after workout session'), 'after workout');
    });

    test('maps lunch synonym', () {
      expect(_normalizeTimingRule('midday lunch'), 'after lunch');
    });

    test('maps night/bed synonyms', () {
      expect(_normalizeTimingRule('at night'), 'before bed');
      expect(_normalizeTimingRule('bedtime'), 'before bed');
    });

    test('falls back to after breakfast for unknown values', () {
      expect(_normalizeTimingRule('whenever'), 'after breakfast');
      expect(_normalizeTimingRule(''), 'after breakfast');
    });
  });

  // ── _validate ───────────────────────────────────────────────────────────────

  group('_validate()', () {
    test('returns null for a valid single item', () {
      expect(
        _validate([
          {'title': 'Vitamin D', 'dosage': '1000 IU', 'time': '08:00'},
        ]),
        isNull,
      );
    });

    test('returns null for an empty list (no supplements)', () {
      expect(_validate([]), isNull);
    });

    test('blocks empty name', () {
      final error = _validate([
        {'title': '', 'dosage': '500 mg', 'time': '08:00'},
      ]);
      expect(error, isNotNull);
      expect(error, contains('name is required'));
    });

    test('blocks whitespace-only name', () {
      final error = _validate([
        {'title': '   ', 'dosage': '500 mg', 'time': '08:00'},
      ]);
      expect(error, isNotNull);
      expect(error, contains('name is required'));
    });

    test('blocks empty dosage', () {
      final error = _validate([
        {'title': 'Creatine', 'dosage': '', 'time': '08:00'},
      ]);
      expect(error, isNotNull);
      expect(error, contains('dosage is required'));
      expect(error, contains('Creatine'));
    });

    test('blocks invalid time format', () {
      final error = _validate([
        {'title': 'Omega 3', 'dosage': '1 cap', 'time': 'morning'},
      ]);
      expect(error, isNotNull);
      expect(error, contains('HH:MM format'));
    });

    test('blocks on second invalid item, first valid', () {
      final error = _validate([
        {'title': 'Vitamin D', 'dosage': '1000 IU', 'time': '08:00'},
        {'title': 'Creatine', 'dosage': '', 'time': '18:30'},
      ]);
      expect(error, isNotNull);
      expect(error, contains('Supplement 2'));
      expect(error, contains('Creatine'));
    });

    test('passes for multiple valid items', () {
      expect(
        _validate([
          {'title': 'Vitamin D', 'dosage': '1000 IU', 'time': '08:00'},
          {'title': 'Creatine', 'dosage': '5 g', 'time': '18:30'},
          {'title': 'Magnesium', 'dosage': '400 mg', 'time': '22:00'},
        ]),
        isNull,
      );
    });
  });

  // ── RoutineTemplateModel round-trip ─────────────────────────────────────────

  group('RoutineTemplateModel.forSave() — supplement round-trip', () {
    test('preserves dosage', () {
      final map = _toTemplate(
        templateId: 'creatine',
        title: 'Creatine',
        dosage: '5 g',
        time: '18:30',
      );
      final model = RoutineTemplateModel.forSave(
        map,
        fallbackRoutineType: 'supplements',
      );
      // dosage is not a first-class field on the model; it lands in extra.
      expect(model.extra['dosage'], '5 g');
      expect(model.toMap()['dosage'], '5 g');
    });

    test('preserves timingRule in extra', () {
      final map = _toTemplate(
        templateId: 'magnesium',
        title: 'Magnesium',
        dosage: '400 mg',
        time: '22:00',
        timingRule: 'before bed',
      );
      final model = RoutineTemplateModel.forSave(
        map,
        fallbackRoutineType: 'supplements',
      );
      expect(model.extra['timingRule'], 'before bed');
      expect(model.toMap()['timingRule'], 'before bed');
    });

    test('preserves reminderEnabled', () {
      final map = _toTemplate(
        templateId: 'omega',
        title: 'Omega 3',
        dosage: '1 capsule',
        time: '13:00',
        reminderEnabled: true,
      );
      final model = RoutineTemplateModel.forSave(
        map,
        fallbackRoutineType: 'supplements',
      );
      expect(model.reminderEnabled, true);
    });

    test('generates a stable templateId when provided', () {
      final map = _toTemplate(
        templateId: 'vit_d',
        title: 'Vitamin D',
        dosage: '1000 IU',
        time: '08:00',
      );
      final model = RoutineTemplateModel.forSave(
        map,
        fallbackRoutineType: 'supplements',
      );
      expect(model.templateId, 'vit_d');
    });

    test('generates a deterministic templateId when none provided', () {
      final map = {
        'title': 'Vitamin B12',
        'routineType': 'supplements',
        'startTime': '09:00',
        'dosage': '500 mcg',
        'repeatRule': 'daily',
      };
      final m1 = RoutineTemplateModel.forSave(map,
          fallbackRoutineType: 'supplements', now: DateTime(2026, 1, 1));
      final m2 = RoutineTemplateModel.forSave(map,
          fallbackRoutineType: 'supplements', now: DateTime(2026, 1, 2));
      // ID must be stable across different `now` values.
      expect(m1.templateId, m2.templateId);
      expect(m1.templateId, startsWith('tpl_'));
    });

    test('routineType is always supplements', () {
      final map = _toTemplate(
        templateId: 'x',
        title: 'Zinc',
        dosage: '15 mg',
        time: '08:00',
      );
      final model = RoutineTemplateModel.forSave(
        map,
        fallbackRoutineType: 'supplements',
      );
      expect(model.routineType, 'supplements');
    });
  });
}
