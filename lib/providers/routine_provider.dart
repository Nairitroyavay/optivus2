import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus2/repositories/routine_repository.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/models/task_model.dart';
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
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  const FixedScheduleTemplate({
    required this.templateId,
    required this.title,
    this.routineType = 'fixed_schedule',
    required this.startTime,
    required this.endTime,
    this.repeatRule = 'daily',
    this.category = '',
    this.notes = '',
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  FixedScheduleTemplate copyWith({
    String? title,
    String? startTime,
    String? endTime,
    String? category,
    String? notes,
    bool? isActive,
    String? updatedAt,
  }) =>
      FixedScheduleTemplate(
        templateId: templateId,
        title: title ?? this.title,
        routineType: routineType,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        repeatRule: repeatRule,
        category: category ?? this.category,
        notes: notes ?? this.notes,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toMap() => {
        'templateId': templateId,
        'title': title,
        'routineType': routineType,
        'startTime': startTime,
        'endTime': endTime,
        'repeatRule': repeatRule,
        'category': category,
        'notes': notes,
        'isActive': isActive,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory FixedScheduleTemplate.fromMap(Map<String, dynamic> m) =>
      FixedScheduleTemplate(
        templateId: _cleanRoutineString(m['templateId']),
        title: _cleanRoutineString(m['title']),
        routineType: 'fixed_schedule',
        startTime: _normalizeRoutineTime(m['startTime'], fallback: '09:00'),
        endTime: _normalizeRoutineTime(m['endTime'], fallback: '10:00'),
        repeatRule: m['repeatRule'] ?? 'daily',
        category: _cleanRoutineString(m['category']),
        notes: _cleanRoutineString(m['notes']),
        isActive: m['isActive'] ?? true,
        createdAt: _cleanRoutineString(m['createdAt']).isNotEmpty
            ? _cleanRoutineString(m['createdAt'])
            : DateTime.now().toIso8601String(),
        updatedAt: _cleanRoutineString(m['updatedAt']).isNotEmpty
            ? _cleanRoutineString(m['updatedAt'])
            : DateTime.now().toIso8601String(),
      );
}

/// Legacy UI adapter for screens that still edit/display minute-based blocks.
class FixedBlock {
  final String id;
  final String title;
  final String emoji;
  final int startMinute;
  final int endMinute;
  final String colorHex;

  const FixedBlock({
    required this.id,
    required this.title,
    required this.emoji,
    required this.startMinute,
    required this.endMinute,
    required this.colorHex,
  });

  String get startLabel => _routineTimeLabel(startMinute);
  String get endLabel => _routineTimeLabel(endMinute);

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'emoji': emoji,
        'startMinute': startMinute,
        'endMinute': endMinute,
        'colorHex': colorHex,
      };

  FixedScheduleTemplate toTemplate() {
    final now = DateTime.now().toIso8601String();
    return FixedScheduleTemplate(
      templateId: id,
      title: title,
      startTime: _routineTimeFromMinutes(startMinute),
      endTime: _routineTimeFromMinutes(endMinute),
      category: '',
      notes: '',
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory FixedBlock.fromTemplate(FixedScheduleTemplate template) => FixedBlock(
        id: template.templateId,
        title: template.title,
        emoji: _emojiForRoutineTitle(template.title),
        startMinute: _routineMinutesFromTime(template.startTime),
        endMinute: _routineMinutesFromTime(template.endTime),
        colorHex: '#CBD5E1',
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
      );

  // ── Convenience getters ──────────────────────────────────────────────────

  /// 0=Mon … 6=Sun
  DaySkinPlan skinPlanForDay(int weekdayIndex) =>
      skinCarePlans[weekdayIndex.clamp(0, 6)];

  DayMealPlan mealPlanForDay(int weekdayIndex) =>
      mealPlans[weekdayIndex.clamp(0, 6)];

  /// Classes for a given weekday (1=Mon … 7=Sun, same as DateTime.weekday)
  List<ClassItem> classesForDay(int weekday) =>
      classes.where((c) => c.weekday == weekday).toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));

  List<FixedBlock> get fixedBlocks =>
      fixedScheduleTemplates.map(FixedBlock.fromTemplate).toList();

  // ── Firestore serialization ─────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'templates': {
          'fixed_schedule':
              fixedScheduleTemplates.map((e) => e.toMap()).toList(),
        },
        'fixedScheduleSetUp': fixedScheduleSetUp,
        'skinCarePlans': skinCarePlans.map((e) => e.toMap()).toList(),
        'skinCareSetUp': skinCareSetUp,
        'mealPlans': mealPlans.map((e) => e.toMap()).toList(),
        'eatingSetUp': eatingSetUp,
        'classes': classes.map((e) => e.toMap()).toList(),
        'classesSetUp': classesSetUp,
        'longTermGoals': longTermGoals.map((e) => e.toMap()).toList(),
      };

  factory RoutineState.fromMap(Map<String, dynamic> m) {
    final templates = m['templates'] as Map<String, dynamic>? ?? {};
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFIER
// ─────────────────────────────────────────────────────────────────────────────

class RoutineNotifier extends StateNotifier<RoutineState> {
  final RoutineRepository _repo;
  final TaskService _taskService;
  Timer? _debounce;

  RoutineNotifier(this._repo, this._taskService) : super(const RoutineState()) {
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
  /// Always ends with a `_syncTasksToFirestore()` call so that task docs at
  /// `/users/{uid}/tasks` are up-to-date after every app start — not just
  /// after the user explicitly saves a routine change.
  Future<void> _loadRoutine() async {
    try {
      final saved = await _repo.loadRoutine();
      if (saved != null) {
        state = saved;
        // Re-sync tasks on every app start so Firestore tasks always reflect
        // the current config (idempotent: uses merge so in-progress tasks are
        // never overwritten).
        _syncTasksToFirestore();
      } else {
        state = const RoutineState();
      }
    } catch (e) {
      debugPrint('RoutineNotifier: failed to load routine: $e');
      state = const RoutineState();
    }
  }

  /// Debounced save — collapses rapid mutations into a single Firestore write.
  void _saveDebounced() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () {
      _repo.saveRoutine(state).then((_) {
        _syncTasksToFirestore();
      }).catchError((e) {
        debugPrint('RoutineNotifier: failed to save routine: $e');
      });
    });
  }

  void _syncTasksToFirestore() {
    final tasks = <TaskModel>[];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (int i = 0; i < 14; i++) {
      final date = today.add(Duration(days: i));
      final dateStr =
          '${date.year}_${date.month.toString().padLeft(2, '0')}_${date.day.toString().padLeft(2, '0')}';
      final dayIdx = (date.weekday - 1).clamp(0, 6);

      // 1. Fixed Blocks (from Templates)
      if (state.fixedScheduleSetUp) {
        for (final tmpl in state.fixedScheduleTemplates) {
          if (!tmpl.isActive) continue;

          final startMinutes = _routineMinutesFromTime(tmpl.startTime);
          final endMinutes = _routineMinutesFromTime(tmpl.endTime);

          final plannedStart = date.add(Duration(minutes: startMinutes));
          DateTime plannedEnd = date.add(Duration(minutes: endMinutes));
          if (plannedEnd.isBefore(plannedStart)) {
            plannedEnd =
                plannedEnd.add(const Duration(days: 1)); // crosses midnight
          }

          tasks.add(TaskModel(
            id: 'routine_${dateStr}_fixed_${tmpl.templateId}',
            type: TaskType.fixed,
            title: tmpl.title,
            emoji: _emojiForRoutineTitle(tmpl.title),
            color: '#CBD5E1', // Default grey, could be mapped by category
            plannedStart: plannedStart,
            plannedEnd: plannedEnd,
            createdAt: now,
            updatedAt: now,
          ));
        }
      }

      // 2. Skin Care
      if (state.skinCareSetUp) {
        final p = state.skinPlanForDay(dayIdx);
        if (p.morning.isNotEmpty) {
          tasks.add(TaskModel(
            id: 'routine_${dateStr}_skin_morning',
            type: TaskType.skinCare,
            title: 'Morning Skin Care',
            emoji: '🌿',
            color: '#A1F094', // kMint equiv
            plannedStart: date.add(const Duration(hours: 7, minutes: 30)),
            plannedEnd: date.add(const Duration(hours: 7, minutes: 45)),
            subtasks: p.morning
                .map((s) => Subtask(id: s.name, title: s.name))
                .toList(),
            createdAt: now,
            updatedAt: now,
          ));
        }
        if (p.afternoon.isNotEmpty) {
          tasks.add(TaskModel(
            id: 'routine_${dateStr}_skin_afternoon',
            type: TaskType.skinCare,
            title: 'Afternoon Skin Care',
            emoji: '💧',
            color: '#A1F094',
            plannedStart: date.add(const Duration(hours: 13, minutes: 0)),
            plannedEnd: date.add(const Duration(hours: 13, minutes: 15)),
            subtasks: p.afternoon
                .map((s) => Subtask(id: s.name, title: s.name))
                .toList(),
            createdAt: now,
            updatedAt: now,
          ));
        }
        if (p.night.isNotEmpty) {
          tasks.add(TaskModel(
            id: 'routine_${dateStr}_skin_night',
            type: TaskType.skinCare,
            title: 'Night Skin Care',
            emoji: '🌙',
            color: '#C084FC', // kPurple equiv
            plannedStart: date.add(const Duration(hours: 22, minutes: 0)),
            plannedEnd: date.add(const Duration(hours: 22, minutes: 15)),
            subtasks:
                p.night.map((s) => Subtask(id: s.name, title: s.name)).toList(),
            createdAt: now,
            updatedAt: now,
          ));
        }
      }

      // 3. Eating
      if (state.eatingSetUp) {
        final mp = state.mealPlanForDay(dayIdx);
        for (final meal in mp.meals) {
          // parse HH:MM AM/PM
          int hour = 0;
          int min = 0;
          try {
            final parts = meal.time.split(' ');
            if (parts.length == 2) {
              final timeParts = parts[0].split(':');
              hour = int.parse(timeParts[0]);
              min = int.parse(timeParts[1]);
              if (parts[1].toUpperCase() == 'PM' && hour != 12) hour += 12;
              if (parts[1].toUpperCase() == 'AM' && hour == 12) hour = 0;
            } else {
              // Fallback to 24hr format
              final timeParts = meal.time.split(':');
              hour = int.parse(timeParts[0]);
              min = int.parse(timeParts[1]);
            }
          } catch (_) {
            hour = 12; // fallback
          }
          final mealStart = date.add(Duration(hours: hour, minutes: min));
          tasks.add(TaskModel(
            id: 'routine_${dateStr}_meal_${meal.name.replaceAll(' ', '_')}',
            type: TaskType.eating,
            title: meal.name,
            emoji: meal.emoji,
            color: '#FF9560', // kRose equiv
            plannedStart: mealStart,
            plannedEnd: mealStart.add(const Duration(minutes: 30)),
            createdAt: now,
            updatedAt: now,
          ));
        }
      }

      // 4. Classes
      if (state.classesSetUp) {
        final classes = state.classesForDay(date.weekday);
        for (final c in classes) {
          int startH = 0, startM = 0;
          try {
            final sp = c.startTime.split(':');
            startH = int.parse(sp[0]);
            startM = int.parse(sp[1]);
          } catch (_) {}
          int endH = 0, endM = 0;
          try {
            final ep = c.endTime.split(':');
            endH = int.parse(ep[0]);
            endM = int.parse(ep[1]);
          } catch (_) {}

          tasks.add(TaskModel(
            id: 'routine_${dateStr}_class_${c.subject.replaceAll(' ', '_')}',
            type: TaskType.classBlock,
            title: c.subject,
            emoji: '🎓',
            color: c.colorHex,
            plannedStart: date.add(Duration(hours: startH, minutes: startM)),
            plannedEnd: date.add(Duration(hours: endH, minutes: endM)),
            subtasks: [
              Subtask(id: 'room', title: c.room),
              Subtask(id: 'prof', title: c.professor)
            ],
            createdAt: now,
            updatedAt: now,
          ));
        }
      }

      // 5. Long Term Goals
      final targetDate = DateTime(date.year, date.month, date.day);
      for (final g in state.longTermGoals) {
        final gStart =
            DateTime(g.startDate.year, g.startDate.month, g.startDate.day);
        final gEnd = DateTime(g.endDate.year, g.endDate.month, g.endDate.day);
        if (!targetDate.isBefore(gStart) && !targetDate.isAfter(gEnd)) {
          int h = 0, m = 0;
          try {
            if (g.dailyTaskTime != null) {
              final sp = g.dailyTaskTime!.split(':');
              h = int.parse(sp[0]);
              m = int.parse(sp[1]);
            }
          } catch (_) {}
          final plannedStart = date.add(Duration(hours: h, minutes: m));
          tasks.add(TaskModel(
            id: 'routine_${dateStr}_goal_${g.id}',
            type: TaskType.custom,
            title: g.title,
            emoji: g.emoji,
            color: g.colorHex,
            plannedStart: plannedStart,
            plannedEnd: plannedStart.add(const Duration(minutes: 30)),
            createdAt: now,
            updatedAt: now,
          ));
        }
      }
    }

    _taskService.syncRoutineTasks(tasks);
  }

  /// Force an immediate save (e.g. before app goes to background).
  Future<void> saveNow() => _repo.saveRoutine(state);

  // ── Fixed schedule templates ───────────────────────────────────────────────

  void setFixedScheduleTemplates(List<FixedScheduleTemplate> templates) {
    state = state.copyWith(
      fixedScheduleTemplates: templates,
      fixedScheduleSetUp: templates.isNotEmpty,
    );
    _saveDebounced();
  }

  void updateFixedScheduleTemplate(FixedScheduleTemplate updated) {
    final list = state.fixedScheduleTemplates
        .map((b) => b.templateId == updated.templateId ? updated : b)
        .toList();
    state = state.copyWith(fixedScheduleTemplates: list);
    _saveDebounced();
  }

  void addFixedScheduleTemplate(FixedScheduleTemplate template) {
    state = state.copyWith(
      fixedScheduleTemplates: [...state.fixedScheduleTemplates, template],
      fixedScheduleSetUp: true,
    );
    _saveDebounced();
  }

  void removeFixedScheduleTemplate(String templateId) {
    final templates = state.fixedScheduleTemplates
        .where((t) => t.templateId != templateId)
        .toList();
    state = state.copyWith(
      fixedScheduleTemplates: templates,
      fixedScheduleSetUp: templates.isNotEmpty,
    );
    _saveDebounced();
  }

  void reorderFixedScheduleTemplates(int oldIndex, int newIndex) {
    final list = List<FixedScheduleTemplate>.from(state.fixedScheduleTemplates);
    if (newIndex > oldIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = state.copyWith(fixedScheduleTemplates: list);
    _saveDebounced();
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
}

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

final routineProvider = StateNotifierProvider<RoutineNotifier, RoutineState>(
  (ref) => RoutineNotifier(
    ref.read(routineRepositoryProvider),
    ref.read(taskServiceProvider),
  ),
);

final customTasksProvider =
    StateProvider<Map<String, List<CustomTask>>>((ref) => {});

final isPremiumProvider = StateProvider<bool>((ref) => false);

enum RoutineFilter { all, fixedSchedule, skinCare, classes, eating }
