import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus2/core/constants/event_names.dart';
import 'package:optivus2/repositories/routine_repository.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/models/fixed_schedule_validation.dart';
import 'package:optivus2/models/routine_template_model.dart';
import 'package:optivus2/models/task_model.dart';
import 'package:optivus2/services/event_service.dart';
import 'package:optivus2/services/task_service.dart';
// ─────────────────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────────────────

String _cleanRoutineString(Object? value) => value?.toString().trim() ?? '';

String _normalizeRoutineTime(Object? value, {required String fallback}) {
  final match =
      RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(_cleanRoutineString(value));
  if (match == null) return fallback;
  final hour = int.tryParse(match.group(1)!);
  final minute = int.tryParse(match.group(2)!);
  if (hour == null || minute == null) return fallback;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return fallback;
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

List<int> _routineIntList(Object? value) {
  if (value is! List) return const [5, 10];
  final values = value
      .whereType<Object>()
      .map((item) {
        if (item is int) return item;
        if (item is num) return item.round();
        return int.tryParse(item.toString()) ?? 0;
      })
      .where((item) => item > 0)
      .toSet()
      .toList()
    ..sort();
  return values.isEmpty ? const [5] : values;
}

int _routineMinutesFromTime(String value) {
  final normalized = _normalizeRoutineTime(value, fallback: '00:00');
  final parts = normalized.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

String _routineTimeFromMinutes(int minutes) {
  final normalized = minutes.clamp(0, 1439);
  final hour = normalized ~/ 60;
  final minute = normalized % 60;
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

String _routineTimeLabel(int minutes) {
  final normalized = minutes.clamp(0, 1439);
  final hour = normalized ~/ 60;
  final minute = normalized % 60;
  final suffix = hour < 12 ? 'AM' : 'PM';
  final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
  return '${hour12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $suffix';
}

String _emojiForRoutineTitle(String title) {
  final key = title.toLowerCase();
  if (key.contains('sleep')) return '🛏️';
  if (key.contains('class') || key.contains('study')) return '🎓';
  if (key.contains('work')) return '💼';
  if (key.contains('gym') || key.contains('workout')) return '💪';
  if (key.contains('meal') || key.contains('dinner') || key.contains('food')) {
    return '🍽️';
  }
  return '📌';
}

String _routineDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String _routineSlug(String value) {
  final slug = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return slug.isEmpty ? 'template' : slug;
}

/// Capitalizes the first character of [value]; leaves the rest unchanged.
String _capitalize(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1);
}



List<FixedScheduleTemplate> canonicalizeFixedScheduleTemplates(
  List<FixedScheduleTemplate> templates, {
  bool touchUpdatedAt = false,
}) {
  return [
    for (var i = 0; i < templates.length; i++)
      FixedScheduleTemplate.fromMap(
        normalizeFixedScheduleTemplateMap(
          templates[i].toMap(),
          index: i,
          touchUpdatedAt: touchUpdatedAt,
        ),
      ),
  ];
}

String? validateFixedScheduleTemplateDraft({
  required String title,
  required String startTime,
  required String endTime,
  required List<FixedScheduleTemplate> existingTemplates,
  String? currentTemplateId,
  bool allowOverlap = false,
}) {
  return validateFixedScheduleTemplateCandidate(
    title: title,
    startTime: startTime,
    endTime: endTime,
    existingTemplates:
        existingTemplates.map((template) => template.toMap()).toList(),
    currentTemplateId: currentTemplateId,
    allowOverlap: allowOverlap,
  );
}



DateTime _dateTimeFromRoutineTime(DateTime date, String value,
    {required String fallback}) {
  final minutes = _routineMinutesFromTime(
    _normalizeRoutineTime(value, fallback: fallback),
  );
  return DateTime(date.year, date.month, date.day).add(
    Duration(minutes: minutes),
  );
}

DateTime _routineEndAfterStart(DateTime date, String start, String end,
    {String fallbackEnd = '10:00'}) {
  final plannedStart = _dateTimeFromRoutineTime(date, start, fallback: '09:00');
  var plannedEnd = _dateTimeFromRoutineTime(date, end, fallback: fallbackEnd);
  if (!plannedEnd.isAfter(plannedStart)) {
    plannedEnd = plannedEnd.add(const Duration(days: 1));
  }
  return plannedEnd;
}

String _normalizeMealTime(String value) {
  final raw = value.trim();
  final match = RegExp(r'^(\d{1,2}):(\d{2})\s*([AaPp][Mm])$').firstMatch(raw);
  if (match != null) {
    var hour = int.tryParse(match.group(1)!) ?? 12;
    final minute = int.tryParse(match.group(2)!) ?? 0;
    final suffix = match.group(3)!.toUpperCase();
    if (suffix == 'PM' && hour != 12) hour += 12;
    if (suffix == 'AM' && hour == 12) hour = 0;
    return _normalizeRoutineTime('$hour:${minute.toString().padLeft(2, '0')}',
        fallback: '12:00');
  }
  return _normalizeRoutineTime(raw, fallback: '12:00');
}

bool _repeatRuleMatchesDate(String repeatRule, DateTime date) {
  final rule = repeatRule.trim().toLowerCase();
  if (rule.isEmpty || rule == 'daily') return true;
  if (rule == 'once' || rule == 'none') return false;

  final weekly = RegExp(r'^weekly:(.+)$').firstMatch(rule);
  if (weekly != null) {
    final weekdays = weekly
        .group(1)!
        .split(',')
        .map((part) => int.tryParse(part.trim()))
        .whereType<int>()
        .toSet();
    return weekdays.contains(date.weekday);
  }

  final weekday =
      RegExp(r'^(weekday|mess_menu_weekday):(\d)$').firstMatch(rule);
  if (weekday != null) return int.parse(weekday.group(2)!) == date.weekday;

  // monthly:14 → matches every 14th of the month
  final monthly = RegExp(r'^monthly:(\d{1,2})$').firstMatch(rule);
  if (monthly != null) {
    return int.tryParse(monthly.group(1)!) == date.day;
  }

  debugPrint(
      '[RoutineProvider] Unknown repeat rule: $repeatRule. Failing safely.');
  return false;
}

/// A fixed block template on the 24-hour schedule (from onboarding "Set Your Fixed Schedule")
class FixedScheduleTemplate {
  final String templateId;
  final String title;
  final String routineType;
  final String startTime; // "HH:mm" in 24h format
  final String endTime; // "HH:mm" in 24h format
  final String repeatRule;
  final String category;
  final String notes;
  final bool reminderEnabled;
  final int reminderOffsetMinutes;
  final bool isActive;
  final String createdAt;
  final String updatedAt;
  final Map<String, dynamic> extra;

  const FixedScheduleTemplate({
    required this.templateId,
    required this.title,
    this.routineType = 'fixed_schedule',
    required this.startTime,
    required this.endTime,
    this.repeatRule = 'daily',
    this.category = '',
    this.notes = '',
    this.reminderEnabled = false,
    this.reminderOffsetMinutes = 5,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.extra = const {},
  });

  FixedScheduleTemplate copyWith({
    String? title,
    String? startTime,
    String? endTime,
    String? category,
    String? notes,
    String? repeatRule,
    bool? reminderEnabled,
    int? reminderOffsetMinutes,
    bool? isActive,
    String? updatedAt,
    Map<String, dynamic>? extra,
  }) =>
      FixedScheduleTemplate(
        templateId: templateId,
        title: title ?? this.title,
        routineType: routineType,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        repeatRule: repeatRule ?? this.repeatRule,
        category: category ?? this.category,
        notes: notes ?? this.notes,
        reminderEnabled: reminderEnabled ?? this.reminderEnabled,
        reminderOffsetMinutes:
            reminderOffsetMinutes ?? this.reminderOffsetMinutes,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        extra: extra ?? this.extra,
      );

  Map<String, dynamic> toMap() => {
        ...extra,
        'templateId': templateId,
        'title': title,
        'routineType': routineType,
        'startTime': startTime,
        'endTime': endTime,
        'repeatRule': repeatRule,
        'category': category,
        'notes': notes,
        'reminderEnabled': reminderEnabled,
        'reminderOffsetMinutes': reminderOffsetMinutes,
        'isActive': isActive,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory FixedScheduleTemplate.fromMap(Map<String, dynamic> m) =>
      FixedScheduleTemplate(
        templateId: _fixedTemplateId(m),
        title: _cleanRoutineString(m['title'] ?? m['name']),
        routineType: 'fixed_schedule',
        startTime: _normalizeRoutineTime(
          m['startTime'] ?? m['time'],
          fallback: '09:00',
        ),
        endTime: _normalizeRoutineTime(m['endTime'], fallback: '10:00'),
        repeatRule:
            _cleanRoutineString(m['repeatRule'] ?? m['weekdayRule']).isNotEmpty
                ? _cleanRoutineString(m['repeatRule'] ?? m['weekdayRule'])
                : 'daily',
        category: _cleanRoutineString(m['category']),
        notes: _cleanRoutineString(m['notes']),
        reminderEnabled: m['reminderEnabled'] == true,
        reminderOffsetMinutes:
            ((m['reminderOffsetMinutes'] as num?)?.toInt() ?? 5).clamp(0, 180),
        isActive: _fixedTemplateIsActive(m),
        createdAt: _cleanRoutineString(m['createdAt']).isNotEmpty
            ? _cleanRoutineString(m['createdAt'])
            : DateTime.now().toIso8601String(),
        updatedAt: _cleanRoutineString(m['updatedAt']).isNotEmpty
            ? _cleanRoutineString(m['updatedAt'])
            : DateTime.now().toIso8601String(),
        extra: _fixedTemplateExtra(m),
      );
}

const _fixedScheduleKnownKeys = {
  'templateId',
  'title',
  'routineType',
  'startTime',
  'endTime',
  'repeatRule',
  'category',
  'notes',
  'reminderEnabled',
  'reminderOffsetMinutes',
  'isActive',
  'createdAt',
  'updatedAt',
};

const _fixedBlockKnownKeys = {
  'id',
  'title',
  'emoji',
  'startMinute',
  'endMinute',
  'colorHex',
  'repeatRule',
  'category',
  'notes',
  'reminderEnabled',
  'reminderOffsetMinutes',
  'createdAt',
  'updatedAt',
};

bool _fixedTemplateIsActive(Map<String, dynamic> map) {
  if (map['isActive'] is bool) return map['isActive'] as bool;
  final lifecycle =
      _cleanRoutineString(map['state'] ?? map['status']).toLowerCase();
  return lifecycle != 'inactive' &&
      lifecycle != 'archived' &&
      lifecycle != 'deleted';
}

Map<String, dynamic> _fixedTemplateExtra(Map<String, dynamic> map) => {
      for (final entry in map.entries)
        if (!_fixedScheduleKnownKeys.contains(entry.key))
          entry.key.toString(): entry.value,
    };

Map<String, dynamic> _fixedBlockExtra(Map<String, dynamic> map) => {
      for (final entry in map.entries)
        if (!_fixedBlockKnownKeys.contains(entry.key))
          entry.key.toString(): entry.value,
    };

String _fixedTemplateId(Map<String, dynamic> map) {
  final explicit = _cleanRoutineString(map['templateId'] ?? map['id']);
  if (explicit.isNotEmpty) return explicit;
  return RoutineTemplateModel.forSave(
    map,
    fallbackRoutineType: 'fixed_schedule',
  ).templateId;
}

/// Legacy UI adapter for screens that still edit/display minute-based blocks.
class FixedBlock {
  final String id;
  final String title;
  final String emoji;
  final int startMinute;
  final int endMinute;
  final String colorHex;
  final String repeatRule;
  final String category;
  final String notes;
  final bool reminderEnabled;
  final int reminderOffsetMinutes;
  final String createdAt;
  final String updatedAt;
  final Map<String, dynamic> extra;

  const FixedBlock({
    required this.id,
    required this.title,
    required this.emoji,
    required this.startMinute,
    required this.endMinute,
    required this.colorHex,
    this.repeatRule = 'daily',
    this.category = '',
    this.notes = '',
    this.reminderEnabled = false,
    this.reminderOffsetMinutes = 5,
    this.createdAt = '',
    this.updatedAt = '',
    this.extra = const {},
  });

  String get startLabel => _routineTimeLabel(startMinute);
  String get endLabel => _routineTimeLabel(endMinute);

  Map<String, dynamic> toMap() => {
        ...extra,
        'id': id,
        'title': title,
        'emoji': emoji,
        'startMinute': startMinute,
        'endMinute': endMinute,
        'colorHex': colorHex,
        'repeatRule': repeatRule,
        'category': category,
        'notes': notes,
        'reminderEnabled': reminderEnabled,
        'reminderOffsetMinutes': reminderOffsetMinutes,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  FixedScheduleTemplate toTemplate() {
    final now = DateTime.now().toIso8601String();
    return FixedScheduleTemplate(
      templateId: id,
      title: title,
      startTime: _routineTimeFromMinutes(startMinute),
      endTime: _routineTimeFromMinutes(endMinute),
      repeatRule: repeatRule,
      category: category,
      notes: notes,
      reminderEnabled: reminderEnabled,
      reminderOffsetMinutes: reminderOffsetMinutes,
      isActive: true,
      createdAt: createdAt.isNotEmpty ? createdAt : now,
      updatedAt: updatedAt.isNotEmpty ? updatedAt : now,
      extra: extra,
    );
  }

  factory FixedBlock.fromTemplate(FixedScheduleTemplate template) => FixedBlock(
        id: template.templateId,
        title: template.title,
        emoji: _emojiForRoutineTitle(template.title),
        startMinute: _routineMinutesFromTime(template.startTime),
        endMinute: _routineMinutesFromTime(template.endTime),
        colorHex: '#CBD5E1',
        repeatRule: template.repeatRule,
        category: template.category,
        notes: template.notes,
        reminderEnabled: template.reminderEnabled,
        reminderOffsetMinutes: template.reminderOffsetMinutes,
        createdAt: template.createdAt,
        updatedAt: template.updatedAt,
        extra: template.extra,
      );

  factory FixedBlock.fromMap(Map<String, dynamic> m) => FixedBlock(
        id: _cleanRoutineString(m['id']),
        title: _cleanRoutineString(m['title']),
        emoji: _cleanRoutineString(m['emoji']).isNotEmpty
            ? _cleanRoutineString(m['emoji'])
            : _emojiForRoutineTitle(_cleanRoutineString(m['title'])),
        startMinute: ((m['startMinute'] as num?)?.toInt() ?? 0).clamp(0, 1439),
        endMinute: ((m['endMinute'] as num?)?.toInt() ?? 0).clamp(0, 1439),
        colorHex: _cleanRoutineString(m['colorHex']).isNotEmpty
            ? _cleanRoutineString(m['colorHex'])
            : '#CBD5E1',
        repeatRule: _cleanRoutineString(m['repeatRule']).isNotEmpty
            ? _cleanRoutineString(m['repeatRule'])
            : 'daily',
        category: _cleanRoutineString(m['category']),
        notes: _cleanRoutineString(m['notes']),
        reminderEnabled: m['reminderEnabled'] == true,
        reminderOffsetMinutes:
            ((m['reminderOffsetMinutes'] as num?)?.toInt() ?? 5).clamp(0, 180),
        createdAt: _cleanRoutineString(m['createdAt']),
        updatedAt: _cleanRoutineString(m['updatedAt']),
        extra: _fixedBlockExtra(m),
      );
}

/// One skin-care step
class SkinStep {
  final String emoji;
  final String name;
  final String tag;
  const SkinStep({required this.emoji, required this.name, required this.tag});

  Map<String, dynamic> toMap() => {'emoji': emoji, 'name': name, 'tag': tag};

  factory SkinStep.fromMap(Map<String, dynamic> m) => SkinStep(
        emoji: m['emoji'] ?? '',
        name: m['name'] ?? '',
        tag: m['tag'] ?? '',
      );
}

/// Skin care plan for one day: three time slots
class DaySkinPlan {
  final List<SkinStep> morning;
  final List<SkinStep> afternoon;
  final List<SkinStep> night;
  const DaySkinPlan({
    this.morning = const [],
    this.afternoon = const [],
    this.night = const [],
  });

  bool get isEmpty => morning.isEmpty && afternoon.isEmpty && night.isEmpty;

  DaySkinPlan copyWith({
    List<SkinStep>? morning,
    List<SkinStep>? afternoon,
    List<SkinStep>? night,
  }) =>
      DaySkinPlan(
        morning: morning ?? this.morning,
        afternoon: afternoon ?? this.afternoon,
        night: night ?? this.night,
      );

  Map<String, dynamic> toMap() => {
        'morning': morning.map((e) => e.toMap()).toList(),
        'afternoon': afternoon.map((e) => e.toMap()).toList(),
        'night': night.map((e) => e.toMap()).toList(),
      };

  factory DaySkinPlan.fromMap(Map<String, dynamic> m) => DaySkinPlan(
        morning: (m['morning'] as List? ?? [])
            .map((e) => SkinStep.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
        afternoon: (m['afternoon'] as List? ?? [])
            .map((e) => SkinStep.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
        night: (m['night'] as List? ?? [])
            .map((e) => SkinStep.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

/// One meal slot
class MealItem {
  final String emoji;
  final String name;
  final String time; // "08:00 AM"
  const MealItem({required this.emoji, required this.name, required this.time});

  Map<String, dynamic> toMap() => {'emoji': emoji, 'name': name, 'time': time};

  factory MealItem.fromMap(Map<String, dynamic> m) => MealItem(
        emoji: m['emoji'] ?? '',
        name: m['name'] ?? '',
        time: m['time'] ?? '',
      );
}

/// Eating plan for one day
class DayMealPlan {
  final List<MealItem> meals;
  const DayMealPlan({this.meals = const []});

  bool get isEmpty => meals.isEmpty;

  List<MealItem> get all => meals;

  DayMealPlan copyWith({
    List<MealItem>? meals,
  }) =>
      DayMealPlan(
        meals: meals ?? this.meals,
      );

  Map<String, dynamic> toMap() => {
        'meals': meals.map((e) => e.toMap()).toList(),
      };

  factory DayMealPlan.fromMap(Map<String, dynamic> m) => DayMealPlan(
        meals: (m['meals'] as List? ?? [])
            .map((e) => MealItem.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

/// One class in the weekly timetable
class ClassItem {
  final String subject;
  final String room;
  final String professor;
  final String startTime; // "09:00"
  final String endTime; // "10:00"
  final int weekday; // 1=Mon … 7=Sun
  final String colorHex;
  const ClassItem({
    required this.subject,
    required this.room,
    required this.professor,
    required this.startTime,
    required this.endTime,
    required this.weekday,
    required this.colorHex,
  });

  Map<String, dynamic> toMap() => {
        'subject': subject,
        'room': room,
        'professor': professor,
        'startTime': startTime,
        'endTime': endTime,
        'weekday': weekday,
        'colorHex': colorHex,
      };

  factory ClassItem.fromMap(Map<String, dynamic> m) => ClassItem(
        subject: m['subject'] ?? '',
        room: m['room'] ?? '',
        professor: m['professor'] ?? '',
        startTime: m['startTime'] ?? '',
        endTime: m['endTime'] ?? '',
        weekday: m['weekday'] ?? 1,
        colorHex: m['colorHex'] ?? '#FFFFFF',
      );
}

class CustomTask {
  final String id;
  final String title;
  final String emoji;
  final String time; // "HH:MM"
  final DateTime date;
  final Color color;

  const CustomTask({
    required this.id,
    required this.title,
    required this.emoji,
    required this.time,
    required this.date,
    required this.color,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'emoji': emoji,
        'time': time,
        'date': date.toIso8601String(),
        'color': color.toARGB32(),
      };

  factory CustomTask.fromMap(Map<String, dynamic> m) => CustomTask(
        id: m['id'] ?? '',
        title: m['title'] ?? '',
        emoji: m['emoji'] ?? '',
        time: m['time'] ?? '',
        date: DateTime.parse(m['date']),
        color: Color(m['color'] ?? 0xFF000000),
      );
}

/// Long-term commitments set by the User or AI
class LongTermGoal {
  final String id;
  final String title;
  final String emoji;
  final DateTime startDate;
  final DateTime endDate;
  final String? dailyTaskTime; // "HH:MM"
  final String colorHex;

  const LongTermGoal({
    required this.id,
    required this.title,
    required this.emoji,
    required this.startDate,
    required this.endDate,
    this.dailyTaskTime,
    required this.colorHex,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'emoji': emoji,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'dailyTaskTime': dailyTaskTime,
        'colorHex': colorHex,
      };

  factory LongTermGoal.fromMap(Map<String, dynamic> m) => LongTermGoal(
        id: m['id'] ?? '',
        title: m['title'] ?? '',
        emoji: m['emoji'] ?? '',
        startDate: DateTime.parse(m['startDate']),
        endDate: DateTime.parse(m['endDate']),
        dailyTaskTime: m['dailyTaskTime'],
        colorHex: m['colorHex'] ?? '#FFFFFF',
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// STATE CLASSES
// ─────────────────────────────────────────────────────────────────────────────

class RoutineState {
  // Fixed 24h schedule blocks (from onboarding)
  final List<FixedScheduleTemplate> fixedScheduleTemplates;
  final bool fixedScheduleSetUp;

  // Skin care: 7 days (0=Mon … 6=Sun)
  final List<DaySkinPlan> skinCarePlans;
  final bool skinCareSetUp;

  // Eating: 7 days
  final List<DayMealPlan> mealPlans;
  final bool eatingSetUp;

  // Classes
  final List<ClassItem> classes;
  final bool classesSetUp;

  // Long-Term Goals
  final List<LongTermGoal> longTermGoals;

  // Raw v1 routine templates not yet represented by the legacy setup models
  // above, e.g. supplements or custom one-off/repeating templates.
  final Map<String, List<Map<String, dynamic>>> routineTemplates;

  const RoutineState({
    this.fixedScheduleTemplates = const [],
    this.fixedScheduleSetUp = false,
    List<DaySkinPlan>? skinCarePlans,
    this.skinCareSetUp = false,
    List<DayMealPlan>? mealPlans,
    this.eatingSetUp = false,
    this.classes = const [],
    this.classesSetUp = false,
    this.longTermGoals = const [],
    this.routineTemplates = const {},
  })  : skinCarePlans = skinCarePlans ??
            const [
              DaySkinPlan(),
              DaySkinPlan(),
              DaySkinPlan(),
              DaySkinPlan(),
              DaySkinPlan(),
              DaySkinPlan(),
              DaySkinPlan(),
            ],
        mealPlans = mealPlans ??
            const [
              DayMealPlan(),
              DayMealPlan(),
              DayMealPlan(),
              DayMealPlan(),
              DayMealPlan(),
              DayMealPlan(),
              DayMealPlan(),
            ];

  RoutineState copyWith({
    List<FixedScheduleTemplate>? fixedScheduleTemplates,
    bool? fixedScheduleSetUp,
    List<DaySkinPlan>? skinCarePlans,
    bool? skinCareSetUp,
    List<DayMealPlan>? mealPlans,
    bool? eatingSetUp,
    List<ClassItem>? classes,
    bool? classesSetUp,
    List<LongTermGoal>? longTermGoals,
    Map<String, List<Map<String, dynamic>>>? routineTemplates,
  }) =>
      RoutineState(
        fixedScheduleTemplates:
            fixedScheduleTemplates ?? this.fixedScheduleTemplates,
        fixedScheduleSetUp: fixedScheduleSetUp ?? this.fixedScheduleSetUp,
        skinCarePlans: skinCarePlans ?? this.skinCarePlans,
        skinCareSetUp: skinCareSetUp ?? this.skinCareSetUp,
        mealPlans: mealPlans ?? this.mealPlans,
        eatingSetUp: eatingSetUp ?? this.eatingSetUp,
        classes: classes ?? this.classes,
        classesSetUp: classesSetUp ?? this.classesSetUp,
        longTermGoals: longTermGoals ?? this.longTermGoals,
        routineTemplates: routineTemplates ?? this.routineTemplates,
      );

  // ── Convenience getters ──────────────────────────────────────────────────

  /// 0=Mon … 6=Sun
  DaySkinPlan skinPlanForDay(int weekdayIndex) =>
      skinCarePlans[weekdayIndex.clamp(0, 6)];

  /// Returns skin care templates whose repeatRule matches [date], sorted by
  /// startTime ascending. Used by the routine tab to show exact user-set times.
  List<Map<String, dynamic>> skinCareTemplatesForDate(DateTime date) {
    final templates = routineTemplates['skin_care'] ?? const [];
    return (templates
        .where((t) =>
            _repeatRuleMatchesDate(t['repeatRule']?.toString() ?? '', date))
        .toList())
      ..sort((a, b) => (a['startTime']?.toString() ?? '')
          .compareTo(b['startTime']?.toString() ?? ''));
  }

  DayMealPlan mealPlanForDay(int weekdayIndex) =>
      mealPlans[weekdayIndex.clamp(0, 6)];

  /// Classes for a given weekday (1=Mon … 7=Sun, same as DateTime.weekday)
  List<ClassItem> classesForDay(int weekday) =>
      classes.where((c) => c.weekday == weekday).toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));

  List<FixedBlock> get fixedBlocks =>
      fixedScheduleTemplates.map(FixedBlock.fromTemplate).toList();

  // ── Firestore serialization ─────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    final templates = <String, dynamic>{
      for (final entry in routineTemplates.entries)
        entry.key: entry.value
            .map(
              (e) => RoutineTemplateModel.forSave(
                e,
                fallbackRoutineType: entry.key,
              ).toMap(),
            )
            .toList(),
      'fixed_schedule': fixedScheduleTemplates.map((e) => e.toMap()).toList(),
    };

    return {
      'templates': templates,
      'fixedScheduleSetUp': fixedScheduleSetUp,
      'skinCarePlans': skinCarePlans.map((e) => e.toMap()).toList(),
      'skinCareSetUp': skinCareSetUp,
      'mealPlans': mealPlans.map((e) => e.toMap()).toList(),
      'eatingSetUp': eatingSetUp,
      'classes': classes.map((e) => e.toMap()).toList(),
      'classesSetUp': classesSetUp,
      'longTermGoals': longTermGoals.map((e) => e.toMap()).toList(),
    };
  }

  factory RoutineState.fromMap(Map<String, dynamic> m) {
    final templates = m['templates'] is Map
        ? Map<String, dynamic>.from(m['templates'] as Map)
        : <String, dynamic>{};
    final fixedSchedule = templates['fixed_schedule'] ?? m['fixedSchedule'];
    final fixedScheduleTemplates = fixedSchedule is List
        ? fixedSchedule
            .map((e) =>
                FixedScheduleTemplate.fromMap(Map<String, dynamic>.from(e)))
            .toList()
        : (m['fixedBlocks'] as List? ?? [])
            .map((e) => FixedBlock.fromMap(Map<String, dynamic>.from(e)))
            .map((block) => block.toTemplate())
            .toList();
    final routineTemplates = <String, List<Map<String, dynamic>>>{
      for (final entry in templates.entries)
        if (entry.value is List)
          entry.key: (entry.value as List)
              .whereType<Map>()
              .map(
                (item) => RoutineTemplateModel.forSave(
                  Map<String, dynamic>.from(item),
                  fallbackRoutineType: entry.key.toString(),
                ).toMap(),
              )
              .toList(),
    };
    return RoutineState(
      fixedScheduleTemplates: fixedScheduleTemplates,
      fixedScheduleSetUp:
          m['fixedScheduleSetUp'] ?? fixedScheduleTemplates.isNotEmpty,
      skinCarePlans: (m['skinCarePlans'] as List?)
          ?.map((e) => DaySkinPlan.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      skinCareSetUp: m['skinCareSetUp'] ?? false,
      mealPlans: (m['mealPlans'] as List?)
          ?.map((e) => DayMealPlan.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      eatingSetUp: m['eatingSetUp'] ?? false,
      classes: (m['classes'] as List? ?? [])
          .map((e) => ClassItem.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      classesSetUp: m['classesSetUp'] ?? false,
      longTermGoals: (m['longTermGoals'] as List? ?? [])
          .map((e) => LongTermGoal.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      routineTemplates: routineTemplates,
    );
  }
}

const _kTerminalTaskStates = {'completed', 'skipped', 'abandoned', 'cancelled'};

class _MaterializationCandidate {
  final TaskModel task;
  final Map<String, dynamic> configFields;
  final Map<String, dynamic> materializationMeta;
  final bool reminderEnabled;
  final int reminderOffsetMinutes;

  const _MaterializationCandidate({
    required this.task,
    required this.configFields,
    required this.materializationMeta,
    required this.reminderEnabled,
    required this.reminderOffsetMinutes,
  });
}

List<_MaterializationCandidate> _candidatesForDate(
  RoutineState state,
  DateTime date,
) {
  final scheduledDate = _routineDateKey(date);
  final candidates = <_MaterializationCandidate>[];
  final seenIds = <String>{};

  void addCandidate({
    required String routineType,
    required String templateId,
    required String title,
    required TaskType taskType,
    required DateTime plannedStart,
    required DateTime plannedEnd,
    required String repeatRule,
    String? emoji,
    String? color,
    String? parentRoutine,
    String notes = '',
    bool reminderEnabled = false,
    int reminderOffsetMinutes = 5,
    AlarmTier alarmTier = AlarmTier.gentle,
    String alarmSound = 'steady',
    String alarmSoundAsset =
        'assets/audio/ambient_atmospheric/ambient_atmospheric_01.mp3',
    bool alarmVoiceEnabled = true,
    String alarmCoachVoiceAsset =
        'assets/audio/healing_432hz/healing_432hz_01.mp3',
    String alarmVibrationPattern = 'standard',
    List<int> alarmSnoozeDurations = const [5, 10],
    List<Subtask> subtasks = const [],
    List<String> identityTags = const [],
  }) {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty || !plannedEnd.isAfter(plannedStart)) return;

    final id = buildRoutineInstanceKey(
      scheduledDate: scheduledDate,
      sourceRoutineType: routineType,
      templateId: templateId,
      title: cleanTitle,
      plannedStart: plannedStart,
      plannedEnd: plannedEnd,
    );
    if (!seenIds.add(id)) return;

    final now = DateTime.now();
    final task = TaskModel(
      id: id,
      type: taskType,
      parentRoutine: parentRoutine ?? templateId,
      title: cleanTitle,
      emoji: emoji,
      color: color,
      identityTags: identityTags,
      alarmTier: alarmTier,
      alarmSound: alarmSound,
      alarmSoundAsset: alarmSoundAsset,
      alarmVoiceEnabled: alarmVoiceEnabled,
      alarmCoachVoiceAsset: alarmCoachVoiceAsset,
      alarmVibrationPattern: alarmVibrationPattern,
      alarmSnoozeDurations: alarmSnoozeDurations,
      plannedStart: plannedStart,
      plannedEnd: plannedEnd,
      subtasks: subtasks,
      createdAt: now,
      updatedAt: now,
    );

    candidates.add(_MaterializationCandidate(
      task: task,
      configFields: {
        'taskId': task.id,
        'type': task.type.toJson(),
        'parentRoutine': task.parentRoutine,
        'title': task.title,
        if (task.emoji != null) 'emoji': task.emoji,
        if (task.color != null) 'color': task.color,
        'identityTags': task.identityTags,
        'alarmTier': task.alarmTier.name,
        'alarmSound': task.alarmSound,
        'alarmSoundAsset': task.alarmSoundAsset,
        'alarmVoiceEnabled': task.alarmVoiceEnabled,
        'alarmCoachVoiceAsset': task.alarmCoachVoiceAsset,
        'alarmVibrationPattern': task.alarmVibrationPattern,
        'alarmSnoozeDurations': task.alarmSnoozeDurations,
        'plannedStart': Timestamp.fromDate(task.plannedStart),
        'plannedEnd': Timestamp.fromDate(task.plannedEnd),
        'subtasks': task.subtasks.map((s) => s.toMap()).toList(),
        if (notes.trim().isNotEmpty) 'notes': notes.trim(),
        'reminderEnabled': reminderEnabled,
        'reminderOffsetMinutes': reminderOffsetMinutes.clamp(0, 180),
        'schemaVersion': task.schemaVersion,
      },
      materializationMeta: {
        'state': task.state.toJson(),
        'status': task.state.toJson(),
        'sourceRoutineType': routineType,
        'routineTemplateId': templateId,
        'scheduledDate': scheduledDate,
        'repeatRule': repeatRule,
        'materializedFromTemplateAt': Timestamp.fromDate(now),
      },
      reminderEnabled: reminderEnabled,
      reminderOffsetMinutes: reminderOffsetMinutes.clamp(0, 180),
    ));
  }

  if (state.fixedScheduleSetUp) {
    for (final template in state.fixedScheduleTemplates) {
      if (!template.isActive) continue;
      if (!_repeatRuleMatchesDate(template.repeatRule, date)) continue;
      final plannedStart = _dateTimeFromRoutineTime(
        date,
        template.startTime,
        fallback: '09:00',
      );
      addCandidate(
        routineType: 'fixed_schedule',
        templateId: template.templateId,
        title: template.title,
        taskType: TaskType.fixed,
        plannedStart: plannedStart,
        plannedEnd: _routineEndAfterStart(
          date,
          template.startTime,
          template.endTime,
        ),
        repeatRule: template.repeatRule,
        emoji: _emojiForRoutineTitle(template.title),
        color: '#CBD5E1',
        notes: template.notes,
        reminderEnabled: template.reminderEnabled,
        reminderOffsetMinutes: template.reminderOffsetMinutes,
        identityTags: [
          if (template.category.trim().isNotEmpty) template.category.trim(),
        ],
      );
    }
  }

  final weekdayIndex = (date.weekday - 1).clamp(0, 6);
  final hasSkinTemplates =
      (state.routineTemplates['skin_care'] ?? const []).isNotEmpty;
  final hasClassTemplates =
      (state.routineTemplates['classes'] ?? const []).isNotEmpty;
  final hasEatingTemplates =
      (state.routineTemplates['eating'] ?? const []).isNotEmpty;

  if (state.skinCareSetUp && !hasSkinTemplates) {
    final plan = state.skinPlanForDay(weekdayIndex);
    void addSkinSlot(
      String slot,
      String title,
      String time,
      String emoji,
      List<SkinStep> steps,
    ) {
      if (steps.isEmpty) return;
      final plannedStart = _dateTimeFromRoutineTime(date, time, fallback: time);
      addCandidate(
        routineType: 'skin_care',
        templateId: 'skin_${date.weekday}_$slot',
        title: title,
        taskType: TaskType.skinCare,
        plannedStart: plannedStart,
        plannedEnd: plannedStart.add(const Duration(minutes: 15)),
        repeatRule: 'weekday:${date.weekday}',
        emoji: emoji,
        color: slot == 'night' ? '#C084FC' : '#A1F094',
        subtasks: steps
            .map((step) =>
                Subtask(id: _routineSlug(step.name), title: step.name))
            .toList(),
        identityTags: const ['skin_care'],
      );
    }

    addSkinSlot('morning', 'Morning Skin Care', '07:30', '🌿', plan.morning);
    addSkinSlot(
        'afternoon', 'Afternoon Skin Care', '13:00', '💧', plan.afternoon);
    addSkinSlot('night', 'Night Skin Care', '22:00', '🌙', plan.night);
  }

  if (state.classesSetUp && !hasClassTemplates) {
    for (final item in state.classesForDay(date.weekday)) {
      final plannedStart = _dateTimeFromRoutineTime(
        date,
        item.startTime,
        fallback: '09:00',
      );
      addCandidate(
        routineType: 'classes',
        templateId:
            'class_${date.weekday}_${_routineSlug(item.subject)}_${_routineSlug(item.startTime)}',
        title: item.subject,
        taskType: TaskType.classBlock,
        plannedStart: plannedStart,
        plannedEnd: _routineEndAfterStart(
          date,
          item.startTime,
          item.endTime,
        ),
        repeatRule: 'weekly:${date.weekday}',
        emoji: '🎓',
        color: item.colorHex,
        subtasks: [
          if (item.room.trim().isNotEmpty)
            Subtask(id: 'room', title: item.room.trim()),
          if (item.professor.trim().isNotEmpty)
            Subtask(id: 'professor', title: item.professor.trim()),
        ],
        identityTags: const ['classes'],
      );
    }
  }

  if (state.eatingSetUp && !hasEatingTemplates) {
    for (final meal in state.mealPlanForDay(weekdayIndex).all) {
      final startTime = _normalizeMealTime(meal.time);
      final plannedStart =
          _dateTimeFromRoutineTime(date, startTime, fallback: '12:00');
      addCandidate(
        routineType: 'eating',
        templateId:
            'meal_${date.weekday}_${_routineSlug(meal.name)}_${_routineSlug(startTime)}',
        title: meal.name,
        taskType: TaskType.eating,
        plannedStart: plannedStart,
        plannedEnd: plannedStart.add(const Duration(minutes: 30)),
        repeatRule: 'mess_menu_weekday:${date.weekday}',
        emoji: meal.emoji.isNotEmpty ? meal.emoji : '🍽️',
        color: '#FF9560',
        identityTags: const ['eating'],
      );
    }
  }

  for (final entry in state.routineTemplates.entries) {
    final routineType = entry.key;
    if (routineType == 'fixed_schedule') continue;

    for (var i = 0; i < entry.value.length; i++) {
      final template = entry.value[i];
      if (template['isActive'] == false) continue;
      final repeatRule = _cleanRoutineString(template['repeatRule']).isEmpty
          ? 'daily'
          : _cleanRoutineString(template['repeatRule']);
      final targetDate = _cleanRoutineString(template['targetDate']);
      final startDate = _cleanRoutineString(template['startDate']);
      final endDate = _cleanRoutineString(template['endDate']);
      if (targetDate.isNotEmpty && targetDate != scheduledDate) continue;
      if (startDate.isNotEmpty && scheduledDate.compareTo(startDate) < 0) {
        continue;
      }
      if (endDate.isNotEmpty && scheduledDate.compareTo(endDate) > 0) {
        continue;
      }
      final repeatRuleKey = repeatRule.trim().toLowerCase();
      final repeatsToday = (repeatRuleKey == 'once' || repeatRuleKey == 'none')
          ? targetDate == scheduledDate
          : _repeatRuleMatchesDate(repeatRule, date);
      if (!repeatsToday) continue;

      final candidateRoutineType =
          _cleanRoutineString(template['routineType']).isNotEmpty
              ? _cleanRoutineString(template['routineType'])
              : routineType;
      final templateId = _cleanRoutineString(template['templateId']).isNotEmpty
          ? _cleanRoutineString(template['templateId'])
          : 'tpl_${RoutineTemplateModel.fromMap(Map<String, dynamic>.from(template), fallbackRoutineType: candidateRoutineType).generateDeterministicHash()}';
      final title = _cleanRoutineString(template['title']).isNotEmpty
          ? _cleanRoutineString(template['title'])
          : templateId;
      final startTime = _normalizeRoutineTime(
        template['startTime'],
        fallback: '09:00',
      );
      final hasExplicitEndTime =
          _cleanRoutineString(template['endTime']).isNotEmpty;
      final endTime = _normalizeRoutineTime(
        template['endTime'],
        fallback: '09:30',
      );
      final plannedStart =
          _dateTimeFromRoutineTime(date, startTime, fallback: '09:00');
      final subtasks = <Subtask>[
        for (final step in (template['steps'] as List? ?? const []))
          if (step is Map && _cleanRoutineString(step['name']).isNotEmpty)
            Subtask(
              id: _routineSlug(_cleanRoutineString(step['name'])),
              title: _cleanRoutineString(step['name']),
            )
          else if (step is String && step.trim().isNotEmpty)
            Subtask(id: _routineSlug(step), title: step.trim()),
        if (_cleanRoutineString(template['dosage']).isNotEmpty)
          Subtask(id: 'dosage', title: _cleanRoutineString(template['dosage'])),
        // timingRule: surface "After breakfast" / "Before bed" as a subtask
        // so the timeline task is self-descriptive without AI.
        if (_cleanRoutineString(template['timingRule']).isNotEmpty)
          Subtask(
            id: 'timing',
            title: _capitalize(_cleanRoutineString(template['timingRule'])),
          ),
        if (_cleanRoutineString(template['room']).isNotEmpty)
          Subtask(id: 'room', title: _cleanRoutineString(template['room'])),
        if (_cleanRoutineString(template['professor']).isNotEmpty)
          Subtask(
            id: 'professor',
            title: _cleanRoutineString(template['professor']),
          ),
        // notes: surface user's free-text note only when no steps are present
        // (steps already convey the detail).
        if (_cleanRoutineString(template['notes']).isNotEmpty &&
            (template['steps'] as List? ?? const []).isEmpty)
          Subtask(
            id: 'notes',
            title: _cleanRoutineString(template['notes']),
          ),
      ];

      addCandidate(
        routineType: candidateRoutineType,
        templateId: templateId,
        title: title,
        taskType: _taskTypeForRoutineType(candidateRoutineType),
        plannedStart: plannedStart,
        plannedEnd: hasExplicitEndTime
            ? _routineEndAfterStart(
                date,
                startTime,
                endTime,
                fallbackEnd: '09:30',
              )
            : plannedStart.add(const Duration(minutes: 30)),
        repeatRule: repeatRule,
        emoji: _cleanRoutineString(template['emoji']).isNotEmpty
            ? _cleanRoutineString(template['emoji'])
            : _emojiForRoutineTitle(title),
        color: _cleanRoutineString(template['colorHex']).isNotEmpty
            ? _cleanRoutineString(template['colorHex'])
            : null,
        notes: _cleanRoutineString(template['notes']),
        reminderEnabled: template['reminderEnabled'] == true,
        reminderOffsetMinutes:
            ((template['reminderOffsetMinutes'] as num?)?.toInt() ?? 5)
                .clamp(0, 180),
        alarmTier: AlarmTier.fromString(template['alarmTier'] as String?),
        alarmSound: _cleanRoutineString(template['alarmSound']).isNotEmpty
            ? _cleanRoutineString(template['alarmSound'])
            : 'steady',
        alarmSoundAsset:
            _cleanRoutineString(template['alarmSoundAsset']).isNotEmpty
                ? _cleanRoutineString(template['alarmSoundAsset'])
                : 'assets/audio/ambient_atmospheric/ambient_atmospheric_01.mp3',
        alarmVoiceEnabled: template['alarmVoiceEnabled'] as bool? ?? true,
        alarmVibrationPattern:
            _cleanRoutineString(template['alarmVibrationPattern']).isNotEmpty
                ? _cleanRoutineString(template['alarmVibrationPattern'])
                : 'standard',
        alarmSnoozeDurations: _routineIntList(
          template['alarmSnoozeDurations'],
        ),
        subtasks: subtasks,
        identityTags: [candidateRoutineType],
      );
    }
  }

  return candidates;
}

TaskType _taskTypeForRoutineType(String routineType) {
  switch (routineType) {
    case 'fixed_schedule':
      return TaskType.fixed;
    case 'skin_care':
      return TaskType.skinCare;
    case 'classes':
      return TaskType.classBlock;
    case 'eating':
      return TaskType.eating;
    default:
      return TaskType.custom;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFIER
// ─────────────────────────────────────────────────────────────────────────────

class RoutineNotifier extends StateNotifier<RoutineState> {
  final RoutineRepository _repo;
  final TaskService _taskService;
  final EventService _eventService;
  Timer? _debounce;

  RoutineNotifier(this._repo, this._taskService, this._eventService)
      : super(const RoutineState()) {
    _loadRoutine();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  // ── Persistence ─────────────────────────────────────────────────────────

  /// Load from Firestore. First-time users start with an empty routine until
  /// onboarding or setup screens save their actual schedule.
  ///
  /// Bootstrap-materialises today + the next 13 days so the Routine tab and
  /// any other consumer reading `/users/{uid}/tasks` immediately sees the
  /// latest config — without ever overwriting completed/skipped/abandoned
  /// historical tasks.
  Future<void> _loadRoutine() async {
    try {
      final saved = await _repo.loadRoutine();
      if (saved != null) {
        state = saved;
        unawaited(materializeForWindow(DateTime.now()));
      } else {
        state = const RoutineState();
      }
    } catch (e) {
      debugPrint('RoutineNotifier: failed to load routine: $e');
      state = const RoutineState();
    }
  }

  /// Debounced save — collapses rapid mutations into a single Firestore write.
  /// After the save, materialises **future days only** (tomorrow + 13 days)
  /// so an in-flight day's tasks are never edited mid-stream.
  void _saveDebounced() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () {
      _repo.saveRoutine(state).then((_) {
        unawaited(materializeFutureFromTomorrow());
      }).catchError((e) {
        debugPrint('RoutineNotifier: failed to save routine: $e');
      });
    });
  }

  /// Force an immediate save (e.g. before app goes to background).
  Future<void> saveNow() => _repo.saveRoutine(state);

  // ── Materialisation ─────────────────────────────────────────────────────

  /// Idempotently materialises every routine-derived task for [date].
  ///
  /// Per-task semantics:
  ///   • new task → `taskService.createTask()` (emits `task_scheduled` once)
  ///                  + a follow-up merge that adds materialisation metadata
  ///   • existing & terminal (completed/skipped/abandoned) → skip — history is preserved
  ///   • existing & non-terminal → merge config + metadata only (no event emitted)
  ///
  /// Used by the Routine tab when the user picks a date.
  Future<void> materializeForDate(DateTime date) async {
    final candidates = _candidatesForDate(state, date);
    if (candidates.isEmpty) return;

    final existing = await _repo.existingRoutineTaskStatesForDate(date);

    for (final c in candidates) {
      final existingState =
          existing[c.task.id] ?? await _repo.taskState(c.task.id);

      if (existingState != null &&
          _kTerminalTaskStates.contains(existingState.toLowerCase())) {
        continue; // do not overwrite history
      }

      try {
        if (existingState == null) {
          await _taskService.createTask(c.task);
          await _repo.mergeTaskFields(c.task.id, c.materializationMeta);
        } else {
          // Exclude user-editable fields so manual time/subtask edits survive
          // a re-materialization (e.g. template update on a future day).
          final safeMeta = Map<String, dynamic>.from(c.materializationMeta)
            ..remove('state')
            ..remove('status');

          await _repo.mergeTaskFields(c.task.id, {
            ...safeMeta,
            'schemaVersion': c.task.schemaVersion,
          });
        }
        if (c.reminderEnabled) {
          await _scheduleRoutineReminder(c);
        }
      } catch (e) {
        debugPrint('[RoutineNotifier] materialise failed for ${c.task.id}: $e');
      }
    }
  }

  Future<void> _scheduleRoutineReminder(_MaterializationCandidate c) async {
    final notificationId = 'routine_notification_${c.task.id}';
    final now = DateTime.now();
    final requestedFireAt = c.task.plannedStart.subtract(
      Duration(minutes: c.reminderOffsetMinutes),
    );
    final fireAt = requestedFireAt.isAfter(now)
        ? requestedFireAt
        : now.add(const Duration(minutes: 1));

    await _repo.saveScheduledNotification(notificationId, {
      'notificationId': notificationId,
      'notifId': notificationId,
      'taskId': c.task.id,
      if (c.task.parentRoutine != null) 'templateId': c.task.parentRoutine,
      'title': c.task.title,
      'category': 'task_reminder',
      'status': 'scheduled',
      'source': 'routine_template',
      'fireAt': Timestamp.fromDate(fireAt),
      'scheduledFor': Timestamp.fromDate(fireAt),
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });
    await _eventService.emit(
      eventName: EventNames.notificationScheduled,
      source: 'routine_materializer',
      eventId: 'event_$notificationId',
      payload: {
        'notifId': notificationId,
        'category': 'task_reminder',
        'taskId': c.task.id,
        'fireAt': fireAt.toIso8601String(),
      },
    );
  }

  /// Materialises [days] consecutive calendar days starting at [from].
  /// Used on app start (today + 13 days) and after onboarding.
  Future<void> materializeForWindow(DateTime from, {int days = 14}) async {
    final start = DateTime(from.year, from.month, from.day);
    for (int i = 0; i < days; i++) {
      await materializeForDate(start.add(Duration(days: i)));
    }
  }

  /// Materialises tomorrow + the following [days] days (default 13 → tomorrow
  /// through day 14). Used after a routine edit so today's tasks are never
  /// touched.
  Future<void> materializeFutureFromTomorrow({int days = 13}) async {
    final now = DateTime.now();
    final tomorrow =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    await materializeForWindow(tomorrow, days: days);
  }

  /// Scans all task documents whose plannedStart falls on [date], groups them
  /// by a stable content key (type + parentRoutine/title + hour + minute), and
  /// hard-deletes non-canonical duplicates that are still in a non-terminal
  /// state (scheduled/started/paused only — completed/skipped/abandoned tasks
  /// are NEVER removed).
  ///
  /// Within each group the canonical task is chosen as:
  ///   1. Highest lifecycle priority (completed > started > paused > scheduled)
  ///   2. Oldest createdAt within the same priority level
  ///
  /// Call this once after materialization for dates where duplicates are known
  /// to exist (e.g. users who completed onboarding before the Fix A patch).
  /// Do NOT run automatically across all historical dates — only on-demand or
  /// for the currently-selected date.
  Future<int> repairDuplicateRoutineTasksForDate(DateTime date) async {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    // Fetch all tasks for the day (raw Firestore docs).
    final snap = await _repo.rawTasksForDateRange(dayStart, dayEnd);
    if (snap.length <= 1) return 0;

    // Build a stable content key identical to the UI dedup key:
    //   'type_parentRoutine-or-slug(title)_HH_MM'
    String contentKey(Map<String, dynamic> d, String docId) {
      final type = (d['type'] as String? ?? 'custom');
      final parent = (d['parentRoutine'] as String? ?? '').trim();
      final title = (d['title'] as String? ?? '').trim().toLowerCase();
      final slot = parent.isNotEmpty
          ? parent
          : title
              .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
              .replaceAll(RegExp(r'^_+|_+$'), '');
      final ps = d['plannedStart'];
      DateTime? start;
      if (ps is Timestamp) start = ps.toDate();
      final h = (start?.hour ?? 0).toString().padLeft(2, '0');
      final m = (start?.minute ?? 0).toString().padLeft(2, '0');
      return '${type}_${slot.isEmpty ? docId : slot}_${h}_$m';
    }

    int priority(Map<String, dynamic> d) {
      final s = ((d['state'] as String?) ?? (d['status'] as String?) ?? '')
          .toLowerCase();
      if (s == 'completed') return 4;
      if (s == 'started') return 3;
      if (s == 'paused') return 2;
      if (s == 'scheduled') return 1;
      return 0;
    }

    // Group by content key. Each entry: {docId, data, priority, createdAt}.
    final groups = <String, List<({String id, Map<String, dynamic> d})>>{};
    for (final entry in snap.entries) {
      final key = contentKey(entry.value, entry.key);
      groups.putIfAbsent(key, () => []).add((id: entry.key, d: entry.value));
    }

    int deletedCount = 0;
    for (final group in groups.values) {
      if (group.length <= 1) continue;

      // Sort: highest priority first, oldest createdAt as tiebreaker.
      group.sort((a, b) {
        final pa = priority(a.d);
        final pb = priority(b.d);
        if (pa != pb) return pb.compareTo(pa); // descending priority
        final ca = _asDateTimeSafe(a.d['createdAt']);
        final cb = _asDateTimeSafe(b.d['createdAt']);
        return ca.compareTo(cb); // ascending createdAt (older first)
      });

      // Keep group[0] (canonical). Delete the rest if non-terminal.
      for (int i = 1; i < group.length; i++) {
        final dup = group[i];
        final state = ((dup.d['state'] as String?) ??
                (dup.d['status'] as String?) ??
                'scheduled')
            .toLowerCase();
        // Never delete completed/skipped/abandoned history.
        if (_kTerminalTaskStates.contains(state)) continue;
        try {
          await _taskService.deleteTask(dup.id);
          deletedCount++;
          debugPrint(
            '[RoutineNotifier] repairDuplicates: deleted dup ${dup.id} '
            '(kept ${group[0].id})',
          );
        } catch (e) {
          debugPrint(
            '[RoutineNotifier] repairDuplicates: failed to delete ${dup.id}: $e',
          );
        }
      }
    }

    if (deletedCount > 0) {
      debugPrint(
        '[RoutineNotifier] repairDuplicateRoutineTasksForDate '
        '(${_routineDateKey(date)}): removed $deletedCount duplicate(s)',
      );
    }
    return deletedCount;
  }

  static DateTime _asDateTimeSafe(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime(2000);
    return DateTime(2000);
  }

  // ── Fixed schedule templates ───────────────────────────────────────────────

  void setFixedScheduleTemplates(List<FixedScheduleTemplate> templates) {
    final normalizedTemplates = canonicalizeFixedScheduleTemplates(templates);
    state = state.copyWith(
      fixedScheduleTemplates: normalizedTemplates,
      fixedScheduleSetUp: normalizedTemplates.isNotEmpty,
    );
    _saveDebounced();
  }

  void updateFixedScheduleTemplate(FixedScheduleTemplate updated) {
    final list = state.fixedScheduleTemplates
        .map((b) => b.templateId == updated.templateId ? updated : b)
        .toList();
    setFixedScheduleTemplates(list);
  }

  void addFixedScheduleTemplate(FixedScheduleTemplate template) {
    setFixedScheduleTemplates([...state.fixedScheduleTemplates, template]);
  }

  void removeFixedScheduleTemplate(String templateId) {
    final templates = state.fixedScheduleTemplates
        .where((t) => t.templateId != templateId)
        .toList();
    setFixedScheduleTemplates(templates);
  }

  void reorderFixedScheduleTemplates(int oldIndex, int newIndex) {
    final list = List<FixedScheduleTemplate>.from(state.fixedScheduleTemplates);
    if (newIndex > oldIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    setFixedScheduleTemplates(list);
  }

  void setFixedBlocks(List<FixedBlock> blocks) {
    setFixedScheduleTemplates(
        blocks.map((block) => block.toTemplate()).toList());
  }

  void updateFixedBlock(FixedBlock updated) {
    updateFixedScheduleTemplate(updated.toTemplate());
  }

  // ── Skin care ────────────────────────────────────────────────────────────

  void setSkinCarePlan(int dayIndex, DaySkinPlan plan) {
    final plans = List<DaySkinPlan>.from(state.skinCarePlans);
    plans[dayIndex] = plan;
    state = state.copyWith(skinCarePlans: plans, skinCareSetUp: true);
    _saveDebounced();
  }

  void markSkinCareSetUp() {
    state = state.copyWith(skinCareSetUp: true);
    _saveDebounced();
  }

  // ── Eating ───────────────────────────────────────────────────────────────

  void setMealPlan(int dayIndex, DayMealPlan plan) {
    final plans = List<DayMealPlan>.from(state.mealPlans);
    plans[dayIndex] = plan;
    state = state.copyWith(mealPlans: plans, eatingSetUp: true);
    _saveDebounced();
  }

  void markEatingSetUp() {
    state = state.copyWith(eatingSetUp: true);
    _saveDebounced();
  }

  // ── Classes ──────────────────────────────────────────────────────────────

  void setClasses(List<ClassItem> classes) {
    state = state.copyWith(classes: classes, classesSetUp: true);
    _saveDebounced();
  }

  void addClass(ClassItem c) {
    state = state.copyWith(
      classes: [...state.classes, c],
      classesSetUp: true,
    );
    _saveDebounced();
  }

  void removeClass(ClassItem c) {
    state = state.copyWith(
      classes: state.classes
          .where((x) => x.subject != c.subject || x.weekday != c.weekday)
          .toList(),
    );
    _saveDebounced();
  }

  // ── Long-Term Goals ────────────────────────────────────────────────────────

  void setLongTermGoals(List<LongTermGoal> goals) {
    state = state.copyWith(longTermGoals: goals);
    _saveDebounced();
  }

  void addLongTermGoal(LongTermGoal goal) {
    state = state.copyWith(longTermGoals: [...state.longTermGoals, goal]);
    _saveDebounced();
  }

  void removeLongTermGoal(String id) {
    state = state.copyWith(
      longTermGoals: state.longTermGoals.where((g) => g.id != id).toList(),
    );
    _saveDebounced();
  }

  // ── Custom routine templates ─────────────────────────────────────────────

  Future<void> addCustomRoutineTemplate(Map<String, dynamic> template) async {
    final normalizedTemplate = RoutineTemplateModel.forSave(
      template,
      fallbackRoutineType: 'custom',
    ).toMap();
    final existing = state.routineTemplates['custom'] ?? const [];
    final nextTemplates = {
      ...state.routineTemplates,
      'custom': [
        ...existing,
        normalizedTemplate,
      ],
    };
    state = state.copyWith(routineTemplates: nextTemplates);
    await _repo.saveRoutine(state);
    await _emitTemplateCreated(normalizedTemplate,
        fallbackRoutineType: 'custom');
    await materializeFutureFromTomorrow(days: 30);
  }

  Future<void> setRoutineTemplates(
    String routineType,
    List<Map<String, dynamic>> templates, {
    Map<String, dynamic>? importMetadata,
    int materializeDays = 30,
  }) async {
    final normalized = templates
        .map((item) => Map<String, dynamic>.from(item))
        .map(
          (item) => RoutineTemplateModel.forSave(
            item,
            fallbackRoutineType: routineType,
          ).toMap(),
        )
        .where((item) => _cleanRoutineString(item['title']).isNotEmpty)
        .toList();
    final nextTemplates = {
      ...state.routineTemplates,
      routineType: normalized,
    };
    state = state.copyWith(routineTemplates: nextTemplates);
    await _repo.saveRoutineTemplates(
      routineType,
      normalized,
      importMetadata: importMetadata,
    );
    for (final template in normalized) {
      await _emitTemplateCreated(template, fallbackRoutineType: routineType);
    }
    await materializeForWindow(DateTime.now(), days: materializeDays);
  }

  Future<void> _emitTemplateCreated(
    Map<String, dynamic> template, {
    required String fallbackRoutineType,
  }) async {
    final templateId = _cleanRoutineString(template['templateId']);
    if (templateId.isEmpty) return;
    await _eventService.emit(
      eventName: EventNames.routineTemplateCreated,
      source: 'routine_setup',
      payload: {
        'templateId': templateId,
        'routineType': _cleanRoutineString(template['routineType']).isNotEmpty
            ? _cleanRoutineString(template['routineType'])
            : fallbackRoutineType,
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

final routineProvider = StateNotifierProvider<RoutineNotifier, RoutineState>(
  (ref) => RoutineNotifier(
    ref.read(routineRepositoryProvider),
    ref.read(taskServiceProvider),
    ref.read(eventServiceProvider),
  ),
);

final customTasksProvider =
    StateProvider<Map<String, List<CustomTask>>>((ref) => {});

final isPremiumProvider = StateProvider<bool>((ref) => false);

enum RoutineFilter {
  all,
  fixedSchedule,
  skinCare,
  supplements,
  classes,
  eating
}
