// lib/Routine Screen/routine_tab_impl.dart

import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:optivus2/core/constants/event_names.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/core/utils/uuid_generator.dart';
import 'package:optivus2/models/fitness_activity_model.dart';
import 'package:optivus2/models/suggestion_model.dart';
import 'package:optivus2/models/task_model.dart';
import 'package:optivus2/providers/routine_provider.dart';
import 'add_task_sheet.dart';
import 'skin_care_setup_screen.dart';
import 'eating_setup_screen.dart';
import 'class_setup_screen.dart';
import 'supplement_setup_screen.dart';

import 'fixed_schedule_setup_screen.dart';

import 'ai_routine_panel.dart';
import 'routine_settings_sheet.dart';
import 'glass_filter_dropdown.dart';
export 'glass_filter_dropdown.dart';
export 'package:optivus2/providers/routine_provider.dart' show RoutineFilter;
import 'timeline_section.dart';
import 'timeline_zoom_views.dart';

enum TimelineZoomLevel { day, week, month, year }

// DisplayBlock is now defined in timeline_section.dart

class RoutineTab extends ConsumerStatefulWidget {
  final RoutineFilter initialFilter;
  const RoutineTab({super.key, this.initialFilter = RoutineFilter.all});
  @override
  ConsumerState<RoutineTab> createState() => _RoutineTabState();
}

class _RoutineTabState extends ConsumerState<RoutineTab> {
  late RoutineFilter _filter;
  bool _aiOpen = false;
  bool _creatingTask = false;

  TimelineZoomLevel _zoomLevel = TimelineZoomLevel.day;
  bool _isZooming = false;

  DateTime? _activeDate;
  final Map<DateTime, GlobalKey> _dayKeys = {};

  String get _todayKey {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  String _dateKey(DateTime date) => '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  String _hex(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
  }

  GlobalKey _getKeyFor(DateTime d) {
    return _dayKeys.putIfAbsent(d, () => GlobalKey());
  }

  void _updateActiveDayFromScroll() {
    DateTime? newActiveDate = _activeDate;

    // Sort keys to evaluate top-to-bottom
    final sortedKeys = _dayKeys.keys.toList()..sort();

    for (final d in sortedKeys) {
      final ctx = _dayKeys[d]?.currentContext;
      if (ctx == null) {
        continue;
      }
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null) {
        continue;
      }
      final y = box.localToGlobal(Offset.zero).dy;
      // 260px corresponds roughly to the area just below the filters
      if (y <= 270) {
        newActiveDate = d;
      }
    }

    if (newActiveDate != null && newActiveDate != _activeDate) {
      Future.microtask(() {
        if (mounted) setState(() => _activeDate = newActiveDate);
      });
    }
  }

  Map<DateTime, List<DisplayBlock>> _buildAllBlocks(
    RoutineState s, {
    Map<DateTime, List<TaskModel>> tasksByDay = const {},
    required DateTime selectedDate,
  }) {
    final day = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    return {
      day: _buildBlocksForDay(
        s,
        day,
        firestoreTasks: tasksByDay[day] ?? const <TaskModel>[],
      ),
    };
  }

  List<DisplayBlock> _buildBlocksForDay(
    RoutineState s,
    DateTime date, {
    List<TaskModel> firestoreTasks = const [],
  }) {
    final dayIdx = (date.weekday - 1).clamp(0, 6);
    final blocks = <DisplayBlock>[];

    // Collect Firestore task IDs so we can deduplicate against routine blocks
    final firestoreTaskTimes = <String>{};

    // 1) First generate a flat list of actual scheduled events
    final scheduled = <DisplayBlock>[];

    // 1a) Inject Firestore-backed tasks (these carry lifecycle state)
    for (final task in firestoreTasks) {
      final timeStr =
          tlFmtMin(task.plannedStart.hour * 60 + task.plannedStart.minute);
      firestoreTaskTimes.add('${timeStr}_${task.title}');

      Color accent;
      String emoji;
      RoutineFilter blockType;
      switch (task.type) {
        case TaskType.skinCare:
          accent = kMint;
          emoji = task.emoji ?? '🌿';
          blockType = RoutineFilter.skinCare;
        case TaskType.eating:
          accent = kRose;
          emoji = task.emoji ?? '🍽️';
          blockType = RoutineFilter.eating;
        case TaskType.classBlock:
          accent = const Color(0xFF60B8FF);
          emoji = task.emoji ?? '🎓';
          blockType = RoutineFilter.classes;
        case TaskType.fixed:
          accent = kPurple;
          emoji = task.emoji ?? '📌';
          blockType = RoutineFilter.fixedSchedule;
        default:
          if (task.identityTags.contains('supplements')) {
            accent = const Color(0xFF14B8A6);
            emoji = task.emoji ?? '💊';
            blockType = RoutineFilter.supplements;
          } else {
            accent = kPurple;
            emoji = task.emoji ?? '✨';
            blockType = RoutineFilter.all;
          }
      }

      if (_filter != RoutineFilter.all && _filter != blockType) continue;

      final endTimeStr =
          tlFmtMin(task.plannedEnd.hour * 60 + task.plannedEnd.minute);

      scheduled.add(DisplayBlock(
        time: timeStr,
        title: task.title,
        subtitle: '$timeStr – $endTimeStr',
        accentColor: task.color != null ? tlHexColor(task.color!) : accent,
        emoji: emoji,
        type: blockType,
        subtasks: task.subtasks.map((st) => st.title).toList(),
        taskId: task.id,
        taskState: task.state,
        actualStart: task.actualStart,
        hasAlarm: task.alarmTier != AlarmTier.gentle,
      ));
    }

    // Fixed blocks repeat every day — include them for all days in the list
    if (_filter == RoutineFilter.all ||
        _filter == RoutineFilter.fixedSchedule) {
      for (final fb in s.fixedBlocks) {
        final timeStr = tlFmtMin(fb.startMinute);
        if (firestoreTaskTimes.contains('${timeStr}_${fb.title}')) continue;

        scheduled.add(DisplayBlock(
            time: timeStr,
            title: fb.title,
            subtitle: '${fb.startLabel} – ${fb.endLabel}',
            accentColor: tlHexColor(fb.colorHex),
            emoji: fb.emoji,
            type: RoutineFilter.all));
      }
    }

    if (_filter == RoutineFilter.all || _filter == RoutineFilter.skinCare) {
      for (final t in s.skinCareTemplatesForDate(date)) {
        final title = t['title']?.toString() ?? 'Skin Care';
        final startTime = t['startTime']?.toString() ?? '00:00';
        final endTime = t['endTime']?.toString() ?? startTime;
        final rawSteps = t['steps'];
        final steps = rawSteps is List
            ? rawSteps
                .map((e) =>
                    e is Map ? (e['name']?.toString() ?? '') : e.toString())
                .where((e) => e.isNotEmpty)
                .toList()
            : <String>[];
        if (firestoreTaskTimes.contains('${startTime}_$title')) continue;
        scheduled.add(DisplayBlock(
          time: startTime,
          title: title,
          subtitle: '$startTime – $endTime',
          accentColor: kMint,
          emoji: '🌿',
          type: RoutineFilter.skinCare,
          subtasks: steps,
        ));
      }
    }

    if (_filter == RoutineFilter.all || _filter == RoutineFilter.classes) {
      for (final c in s.classesForDay(date.weekday)) {
        if (firestoreTaskTimes.contains('${c.startTime}_${c.subject}')) {
          continue;
        }

        scheduled.add(DisplayBlock(
            time: c.startTime,
            title: c.subject,
            subtitle: '${c.room} · ${c.professor}',
            accentColor: tlHexColor(c.colorHex),
            emoji: '🎓',
            type: RoutineFilter.classes));
      }
    }

    if (_filter == RoutineFilter.all || _filter == RoutineFilter.eating) {
      for (final m in s.mealPlanForDay(dayIdx).all) {
        // Normalize time to HH:MM 24h for consistent display and sorting
        final normalizedTime = tlNormalizeTime(m.time);
        if (firestoreTaskTimes.contains('${normalizedTime}_${m.name}')) {
          continue;
        }

        scheduled.add(DisplayBlock(
            time: normalizedTime,
            title: m.name,
            subtitle: tlMealLabel(normalizedTime),
            accentColor: kRose,
            emoji: m.emoji,
            type: RoutineFilter.eating));
      }
    }

    // Long-Term Goals
    if (_filter == RoutineFilter.all) {
      final targetDate = DateTime(date.year, date.month, date.day);
      for (final g in s.longTermGoals) {
        final start =
            DateTime(g.startDate.year, g.startDate.month, g.startDate.day);
        final end = DateTime(g.endDate.year, g.endDate.month, g.endDate.day);

        // If the date is within the goal's duration
        if (!targetDate.isBefore(start) && !targetDate.isAfter(end)) {
          final timeStr = g.dailyTaskTime ?? '00:00';
          if (firestoreTaskTimes.contains('${timeStr}_${g.title}')) continue;

          scheduled.add(DisplayBlock(
            time: timeStr,
            title: g.title,
            subtitle: 'Long-Term Goal',
            accentColor: tlHexColor(g.colorHex),
            emoji: g.emoji,
            type: RoutineFilter.all,
          ));
        }
      }
    }

    scheduled.sort((a, b) => a.time.compareTo(b.time));

    // 2) Create the full 24-hour structure.
    for (int hour = 0; hour < 24; hour++) {
      final timeStr = '${hour.toString().padLeft(2, '0')}:00';

      // Find all scheduled tasks for this exact hour
      final tasksForHour = scheduled.where((b) {
        final bHour = int.tryParse(b.time.split(':')[0]) ?? 0;
        return bHour == hour;
      }).toList();

      if (tasksForHour.isEmpty) {
        // If hour is completely empty, add our empty placeholder
        blocks.add(DisplayBlock(
          time: timeStr,
          title: '',
          subtitle: '',
          accentColor: Colors.transparent,
          emoji: '',
          type: RoutineFilter.all,
          isEmptyPlaceholder: true,
        ));
      } else {
        // Otherwise, add all tasks that happen within this hour in order
        blocks.addAll(tasksForHour);
      }
    }

    // We don't sort here anymore, the list is already constructed in 00:00 - 23:59 order

    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      final nowMin = now.hour * 60 + now.minute;
      for (int i = 0; i < blocks.length - 1; i++) {
        if (nowMin >= tlParseMin(blocks[i].time) &&
            nowMin < tlParseMin(blocks[i + 1].time)) {
          final b = blocks[i];
          blocks[i] = DisplayBlock(
              time: b.time,
              title: b.title,
              subtitle: b.subtitle,
              accentColor: b.accentColor,
              emoji: b.emoji,
              type: b.type,
              subtasks: b.subtasks,
              isNow: true,
              taskId: b.taskId,
              taskState: b.taskState,
              actualStart: b.actualStart,
              hasAlarm: b.hasAlarm);
          break;
        }
      }
    }
    return blocks;
  }

  void _onFilter(RoutineFilter f, RoutineState s) {
    setState(() => _filter = f);
  }

  void _doSetup(RoutineFilter f) {
    if (f == RoutineFilter.skinCare) {
      Navigator.push(context, slideRoute(SkinCareSetupScreen(onComplete: () {
        ref.read(routineProvider.notifier).markSkinCareSetUp();
        setState(() => _filter = RoutineFilter.skinCare);
      })));
    } else if (f == RoutineFilter.eating) {
      Navigator.push(
          context,
          slideRoute(EatingSetupScreen(
              onComplete: () =>
                  setState(() => _filter = RoutineFilter.eating))));
    } else if (f == RoutineFilter.classes) {
      Navigator.push(context, slideRoute(ClassSetupScreen(onComplete: () {
        setState(() => _filter = RoutineFilter.classes);
      })));
    } else if (f == RoutineFilter.supplements) {
      Navigator.push(context, slideRoute(SupplementSetupScreen(onComplete: () {
        setState(() => _filter = RoutineFilter.supplements);
      })));
    } else if (f == RoutineFilter.fixedSchedule) {
      Navigator.push(context,
          slideRoute(FixedScheduleSetupScreen(onComplete: () {
        setState(() => _filter = RoutineFilter.fixedSchedule);
      })));
    }
  }

  void _openSettings(RoutineState s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RoutineSettingsSheet(
        setupDone: {
          RoutineFilter.skinCare: s.skinCareSetUp,
          RoutineFilter.supplements:
              (s.routineTemplates['supplements'] ?? const []).isNotEmpty,
          RoutineFilter.classes: s.classesSetUp,
          RoutineFilter.eating: s.eatingSetUp,
          RoutineFilter.fixedSchedule: s.fixedScheduleSetUp,
        },
        onSetup: (f) {
          Navigator.pop(context);
          _doSetup(f);
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final isTomorrow = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day + 1;

    const daysStr = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const mos = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC'
    ];

    final dayStr = daysStr[date.weekday - 1];
    final moStr = mos[date.month - 1];
    final dateStr = '$dayStr, $moStr ${date.day}, ${date.year}';

    if (isToday) return 'TODAY: $dateStr';
    if (isTomorrow) return 'TOMORROW: $dateStr';
    return dateStr.toUpperCase();
  }

  String _formatFlow(DateTime date) {
    if (_filter != RoutineFilter.all) return filterMetaData[_filter]!.label;

    switch (_zoomLevel) {
      case TimelineZoomLevel.week:
        return "This Week's Flow";
      case TimelineZoomLevel.month:
        return "This Month's Flow";
      case TimelineZoomLevel.year:
        return "This Year's Flow";
      case TimelineZoomLevel.day:
        final now = DateTime.now();
        final isToday = date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;
        final isTomorrow = date.year == now.year &&
            date.month == now.month &&
            date.day == now.day + 1;

        if (isToday) {
          return "Today's Flow";
        }
        if (isTomorrow) {
          return "Tomorrow's Flow";
        }

        const daysStr = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        const mos = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec'
        ];
        return '${daysStr[date.weekday - 1]}, ${mos[date.month - 1]} ${date.day} Flow';
    }
  }

  void _zoomOut() {
    if (_isZooming) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _isZooming = true;
      if (_zoomLevel == TimelineZoomLevel.day) {
        _zoomLevel = TimelineZoomLevel.week;
      } else if (_zoomLevel == TimelineZoomLevel.week) {
        _zoomLevel = TimelineZoomLevel.month;
      } else if (_zoomLevel == TimelineZoomLevel.month) {
        _zoomLevel = TimelineZoomLevel.year;
      }
    });
  }

  void _zoomIn() {
    if (_isZooming) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _isZooming = true;
      if (_zoomLevel == TimelineZoomLevel.year) {
        _zoomLevel = TimelineZoomLevel.month;
      } else if (_zoomLevel == TimelineZoomLevel.month) {
        _zoomLevel = TimelineZoomLevel.week;
      } else if (_zoomLevel == TimelineZoomLevel.week) {
        _zoomLevel = TimelineZoomLevel.day;
      }
    });
  }

  void _selectDate(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    ref.read(selectedRoutineDateProvider.notifier).state = day;
    setState(() => _activeDate = day);
    ref.read(routineProvider.notifier).materializeForDate(day);
  }

  void _openAddTaskSheet(DateTime selectedDate) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTaskSheet(
        initialDate: selectedDate,
        onSubmit: _handleAddTask,
      ),
    );
  }

  // Repeat rules that the Add Task flow recognises.
  static const _kValidRepeatPrefixes = {'none', 'daily', 'weekly:', 'monthly:'};

  Future<void> _handleAddTask(AddTaskRequest request) async {
    // Double-submission guard (belt-and-suspenders on top of sheet's _saving).
    if (_creatingTask) return;
    _creatingTask = true;
    try {
      // Pre-flight validation: blank title and invalid time range.
      if (request.title.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Task title cannot be empty.')),
          );
        }
        return;
      }
      if (!request.plannedEnd.isAfter(request.plannedStart)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('End time must be after start time.')),
          );
        }
        return;
      }
      // Validate repeat rule before branching.
      if (!_kValidRepeatPrefixes.any((p) => request.repeatRule.startsWith(p))) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unsupported repeat rule.')),
          );
        }
        return;
      }

      if (request.isOneOff) {
        await _createOneOffTask(request);
      } else {
        await _createRepeatingTemplate(request);
      }
      _selectDate(request.date);
    } finally {
      _creatingTask = false;
    }
  }

  Future<void> _handleStartTask(String taskId, TaskModel? task) async {
    final fitnessType = task == null ? null : _fitnessTypeForTask(task);
    if (task != null && fitnessType != null) {
      final encodedTaskId = Uri.encodeQueryComponent(task.id);
      context.push(
        '/fitness/pre-start?type=${fitnessType.toJson()}&routineTaskId=$encodedTaskId',
      );
      return;
    }

    await ref.read(taskServiceProvider).startTask(taskId);
  }

  FitnessActivityType? _fitnessTypeForTask(TaskModel task) {
    final text = [
      task.title,
      task.emoji ?? '',
      ...task.identityTags,
      task.parentRoutine ?? '',
    ].join(' ').toLowerCase();

    bool containsAny(Iterable<String> terms) =>
        terms.any((term) => text.contains(term));

    if (containsAny(const ['running', 'run', 'jog'])) {
      return FitnessActivityType.running;
    }
    if (containsAny(const ['walking', 'walk'])) {
      return FitnessActivityType.walking;
    }
    if (containsAny(const ['cycling', 'cycle', 'bike', 'biking'])) {
      return FitnessActivityType.cycling;
    }
    if (containsAny(const ['hiking', 'hike', 'trek'])) {
      return FitnessActivityType.hiking;
    }
    if (containsAny(const ['swimming', 'swim', 'pool'])) {
      return FitnessActivityType.swimming;
    }
    if (containsAny(const [
      'gym',
      'workout',
      'lift',
      'weights',
      'strength',
      'cardio',
      'exercise',
      'training',
      'yoga',
      'mobility',
      'fitness',
    ])) {
      return FitnessActivityType.gymWorkout;
    }
    return null;
  }

  Future<void> _createOneOffTask(AddTaskRequest request) async {
    final now = DateTime.now();
    final taskId = generateId();
    final task = TaskModel(
      id: taskId,
      type: _taskTypeForRoutineType(request.routineType),
      title: request.title,
      emoji: request.emoji,
      color: _hex(request.color),
      identityTags: [request.category],
      alarmTier: request.reminderEnabled ? AlarmTier.custom : AlarmTier.gentle,
      alarmSound: request.alarmSound,
      alarmSoundAsset: request.alarmSoundAsset,
      alarmVoiceEnabled: request.alarmVoiceEnabled,
      alarmVibrationPattern: request.alarmVibrationPattern,
      alarmSnoozeDurations: request.alarmSnoozeDurations,
      plannedStart: request.plannedStart,
      plannedEnd: request.plannedEnd,
      createdAt: now,
      updatedAt: now,
    );

    // createTask writes state, plannedStart/End and emits task_scheduled in one batch.
    await ref.read(taskServiceProvider).createTask(task);
    // Merge extra metadata fields not covered by TaskModel.toFirestore().
    // Tag one-off tasks explicitly so they're distinguishable from materialized
    // routine tasks and pinned to their target date.
    await ref.read(firestoreServiceProvider).saveUserSubdocument(
      'tasks',
      taskId,
      {
        'scheduledDate': _dateKey(request.date),
        'targetDate': _dateKey(request.date),
        'repeatRule': 'none',
        'isOneOff': true,
        'sourceRoutineType': request.routineType,
        'category': request.category,
        'notes': request.notes,
        'reminderEnabled': request.reminderEnabled,
        'alarmTier': request.reminderEnabled
            ? AlarmTier.custom.name
            : AlarmTier.gentle.name,
        'alarmSound': request.alarmSound,
        'alarmSoundAsset': request.alarmSoundAsset,
        'alarmVoiceEnabled': request.alarmVoiceEnabled,
        'alarmVibrationPattern': request.alarmVibrationPattern,
        'alarmSnoozeDurations': request.alarmSnoozeDurations,
      },
    );

    if (request.reminderEnabled) {
      try {
        await _scheduleReminder(
          taskId: taskId,
          title: request.title,
          fireAt: request.plannedStart.subtract(const Duration(minutes: 5)),
          source: 'manual_task',
        );
      } catch (e) {
        debugPrint('[RoutineTab] Reminder scheduling failed for $taskId: $e');
        // Task save succeeded — reminder failure is non-fatal.
      }
    }
  }

  // repeatRule is already in Firestore format (computed by AddTaskSheet)
  String _toFirestoreRepeatRule(AddTaskRequest request) => request.repeatRule;

  Future<void> _createRepeatingTemplate(AddTaskRequest request) async {
    final now = DateTime.now().toIso8601String();
    final templateId = generateId();
    final repeatRule = _toFirestoreRepeatRule(request);
    final template = {
      'templateId': templateId,
      'title': request.title,
      'routineType': request.routineType,
      'startTime': request.startTime,
      'endTime': request.endTime,
      'repeatRule': repeatRule,
      'category': request.category,
      'notes': request.notes,
      // Pin one-off templates to their target date so they never materialise
      // on other calendar days.
      if (repeatRule == 'none') 'targetDate': _dateKey(request.date),
      'reminderEnabled': request.reminderEnabled,
      'alarmTier': request.reminderEnabled
          ? AlarmTier.custom.name
          : AlarmTier.gentle.name,
      'alarmSound': request.alarmSound,
      'alarmSoundAsset': request.alarmSoundAsset,
      'alarmVoiceEnabled': request.alarmVoiceEnabled,
      'alarmVibrationPattern': request.alarmVibrationPattern,
      'alarmSnoozeDurations': request.alarmSnoozeDurations,
      'isActive': true,
      'startDate': _dateKey(request.date),
      'createdAt': now,
      'updatedAt': now,
    };

    // addCustomRoutineTemplate already emits routineTemplateCreated and
    // materialises future days; we only need to materialise the selected date.
    // Reminder scheduling is owned by RoutineProvider.materializeForDate() which
    // uses deterministic notification IDs (routine_notification_{taskId}).
    // Do NOT schedule reminders here — that would create duplicate notification
    // docs and duplicate notification_scheduled events.
    await ref.read(routineProvider.notifier).addCustomRoutineTemplate(template);
    await ref.read(routineProvider.notifier).materializeForDate(request.date);
  }

  Future<void> _scheduleReminder({
    required String taskId,
    required String title,
    required DateTime fireAt,
    required String source,
    String? templateId,
  }) async {
    final notificationId = generateId();
    final now = DateTime.now();
    final resolvedFireAt =
        fireAt.isAfter(now) ? fireAt : now.add(const Duration(minutes: 1));
    await ref.read(firestoreServiceProvider).saveScheduledNotification(
      notificationId,
      {
        'notificationId': notificationId,
        'notifId': notificationId,
        'taskId': taskId,
        if (templateId != null) 'templateId': templateId,
        'title': title,
        'category': 'task_reminder',
        'status': 'scheduled',
        'source': source,
        'fireAt': Timestamp.fromDate(resolvedFireAt),
        'scheduledFor': Timestamp.fromDate(resolvedFireAt),
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      },
    );
    await ref.read(eventServiceProvider).emit(
      eventName: EventNames.notificationScheduled,
      source: 'routine_tab',
      payload: {
        'notifId': notificationId,
        'category': 'task_reminder',
        'taskId': taskId,
        'fireAt': resolvedFireAt.toIso8601String(),
      },
    );
  }

  Future<void> _saveSuggestion(AiSuggestion suggestion) async {
    final now = DateTime.now();
    await ref.read(firestoreServiceProvider).saveSuggestion(
          suggestion.id,
          SuggestionModel(
            suggestionId: suggestion.id,
            title: suggestion.title,
            reason: suggestion.reason,
            emoji: suggestion.emoji,
            action: suggestion.action.name,
            status: 'generated',
            source: 'routine_ai_panel',
            createdAt: now,
            updatedAt: now,
          ).toMap(),
        );
    await ref.read(eventServiceProvider).emit(
      eventName: EventNames.suggestionGenerated,
      source: 'routine_ai_panel',
      payload: {'suggestionId': suggestion.id},
    );
  }

  Future<void> _acceptSuggestion(AiSuggestion suggestion) async {
    await ref.read(firestoreServiceProvider).saveSuggestion(
      suggestion.id,
      {
        'status': 'accepted',
        'acceptedAt': Timestamp.fromDate(DateTime.now()),
      },
    );
    await ref.read(eventServiceProvider).emit(
      eventName: EventNames.suggestionAccepted,
      source: 'routine_ai_panel',
      payload: {'suggestionId': suggestion.id},
    );
  }

  Future<void> _dismissSuggestion(AiSuggestion suggestion) async {
    await ref.read(firestoreServiceProvider).saveSuggestion(
      suggestion.id,
      {
        'status': 'dismissed',
        'dismissedAt': Timestamp.fromDate(DateTime.now()),
      },
    );
    await ref.read(eventServiceProvider).emit(
      eventName: EventNames.suggestionDismissed,
      source: 'routine_ai_panel',
      payload: {'suggestionId': suggestion.id},
    );
  }

  TaskType _taskTypeForRoutineType(String routineType) {
    switch (routineType) {
      case 'skin_care':
        return TaskType.skinCare;
      case 'classes':
        return TaskType.classBlock;
      case 'eating':
        return TaskType.eating;
      case 'fixed_schedule':
        return TaskType.fixed;
      case 'supplements':
        return TaskType.custom;
      default:
        return TaskType.custom;
    }
  }

  Widget _buildDayHeaderSliver(DateTime date) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    // Today's header is shown in the main section header, skip it
    if (isToday) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: TimelineDayHeader(label: _formatDate(date).toUpperCase()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(routineProvider);
    final selectedDate = ref.watch(selectedRoutineDateProvider);
    final selectedDayAsync = ref.watch(selectedRoutineTasksProvider);

    // Watch the 14-day window stream so zoom views have live Firestore-backed
    // task density. The day view below uses the selected day stream directly.
    final windowAsync = ref.watch(routineWindowTasksProvider);
    final windowTasks = windowAsync.valueOrNull ?? const <TaskModel>[];
    final selectedTasks = selectedDayAsync.valueOrNull ?? const <TaskModel>[];
    final tasksById = {
      for (final task in [...windowTasks, ...selectedTasks]) task.id: task,
    };
    final isTimelineLoading =
        selectedDayAsync.isLoading && selectedDayAsync.valueOrNull == null;
    final timelineError = selectedDayAsync.hasError
        ? (selectedDayAsync.error?.toString() ?? 'Could not load tasks.')
        : null;

    // Group the flat task list into a map keyed by calendar day (midnight).
    // This lets _buildBlocksForDay look up tasks per day in O(1).
    final tasksByDay = <DateTime, List<TaskModel>>{};
    for (final task in [...windowTasks, ...selectedTasks]) {
      final day = DateTime(
        task.plannedStart.year,
        task.plannedStart.month,
        task.plannedStart.day,
      );
      tasksByDay.putIfAbsent(day, () => []).add(task);
    }

    final days = _buildAllBlocks(
      s,
      tasksByDay: tasksByDay,
      selectedDate: selectedDate,
    );

    final displayDate = selectedDate;

    return LiquidBg(
      colors: const [Color(0xFFA3FF91), Color(0xFFEFFEEC)],
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(children: [
          SafeArea(
              bottom: false,
              child: Column(children: [
                // ─── Header: Info (Left) & Glass Action Island (Right) ───────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(_formatDate(displayDate).toUpperCase(),
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: kInk.withValues(alpha: 0.8),
                                    letterSpacing: 1.2)),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _HeaderActionButton(
                                icon: Icons.hub_rounded,
                                label: 'AI',
                                color: const Color(0xFF86EFAC),
                                onTap: () => setState(() => _aiOpen = true),
                              ),
                              const SizedBox(width: 10),
                              _HeaderActionButton(
                                icon: Icons.add_rounded,
                                label: 'Add',
                                color: const Color(0xFFD8B4FE),
                                onTap: () => _openAddTaskSheet(selectedDate),
                              ),
                              const SizedBox(width: 8),
                              _SettingsPill(onTap: () => _openSettings(s)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(_formatFlow(displayDate),
                                style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    color: kInk,
                                    letterSpacing: -1.0),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1),
                          ),
                          const SizedBox(width: 12),
                          GlassFilterDropdown(
                            selected: _filter,
                            routineState: s,
                            onSelected: (f) => _onFilter(f, s),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _DateStrip(
                        selectedDate: selectedDate,
                        onSelected: _selectDate,
                      ),
                    ],
                  ),
                ),

                // ─── Infinite Timeline Scroll ─────────────────────────────────
                Expanded(
                  child: GestureDetector(
                    onScaleUpdate: (details) {
                      if (details.scale < 0.75) {
                        _zoomOut();
                      } else if (details.scale > 1.3) {
                        _zoomIn();
                      }
                    },
                    onScaleEnd: (_) => setState(() => _isZooming = false),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child:
                              ScaleTransition(scale: animation, child: child)),
                      child: _zoomLevel == TimelineZoomLevel.week
                          ? TimelineWeekView(
                              activeDate: displayDate,
                              routineState: s,
                              filter: _filter,
                              tasksByDay: tasksByDay)
                          : _zoomLevel == TimelineZoomLevel.month
                              ? TimelineMonthView(
                                  activeDate: displayDate,
                                  routineState: s,
                                  filter: _filter,
                                  tasksByDay: tasksByDay)
                              : _zoomLevel == TimelineZoomLevel.year
                                  ? TimelineYearView(
                                      activeDate: displayDate,
                                      routineState: s,
                                      filter: _filter,
                                      tasksByDay: tasksByDay)
                                  // Default Day View
                                  : NotificationListener<ScrollNotification>(
                                      onNotification: (notif) {
                                        _updateActiveDayFromScroll();
                                        return false;
                                      },
                                      child: CustomScrollView(
                                        physics: const BouncingScrollPhysics(),
                                        slivers: [
                                          if (isTimelineLoading)
                                            const SliverToBoxAdapter(
                                              child: TimelineStatusState(
                                                icon: Icons
                                                    .hourglass_empty_rounded,
                                                title: 'Loading timeline',
                                                message:
                                                    'Fetching tasks for this day.',
                                              ),
                                            )
                                          else if (timelineError != null)
                                            SliverToBoxAdapter(
                                              child: TimelineStatusState(
                                                icon:
                                                    Icons.error_outline_rounded,
                                                title: 'Timeline unavailable',
                                                message: timelineError,
                                              ),
                                            )
                                          else
                                            for (final entry
                                                in days.entries) ...[
                                              // Day anchor (used for scroll detection)
                                              SliverToBoxAdapter(
                                                // Add key to SizedBox so it provides a RenderBox instead of RenderSliver
                                                child: SizedBox(
                                                    key: _getKeyFor(entry.key),
                                                    height: 1),
                                              ),
                                              // Day header — skip for today (already shown in main header)
                                              _buildDayHeaderSliver(entry.key),
                                              // Only show empty state for filters when there's actually nothing scheduled
                                              // (Filtering still drops blocks if they don't match, so if scheduled is empty we show 24 nulls)
                                              if (entry.value.every((b) =>
                                                      b.isEmptyPlaceholder) &&
                                                  _filter != RoutineFilter.all)
                                                SliverToBoxAdapter(
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 20,
                                                            bottom: 60),
                                                    child: TimelineEmptyState(
                                                        filter: _filter,
                                                        onSetup: () =>
                                                            _doSetup(_filter)),
                                                  ),
                                                )
                                              else if (entry.value.every(
                                                  (b) => b.isEmptyPlaceholder))
                                                SliverToBoxAdapter(
                                                  child: TimelineDayEmptyState(
                                                    onAdd: () =>
                                                        _openAddTaskSheet(
                                                            entry.key),
                                                  ),
                                                )
                                              else
                                                SliverPadding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          bottom: 24),
                                                  sliver: SliverList(
                                                    delegate:
                                                        SliverChildBuilderDelegate(
                                                      (_, i) => TimelineRow(
                                                        block: entry.value[i],
                                                        index: i,
                                                        showHourLabel: i == 0 ||
                                                            entry.value[i].time
                                                                        .split(
                                                                            ':')[
                                                                    0] !=
                                                                entry
                                                                    .value[
                                                                        i - 1]
                                                                    .time
                                                                    .split(
                                                                        ':')[0],
                                                        isLast: i ==
                                                            entry.value.length -
                                                                1,
                                                        onStart: (taskId) =>
                                                            _handleStartTask(
                                                          taskId,
                                                          tasksById[taskId],
                                                        ),
                                                        onComplete: (taskId) => ref
                                                            .read(
                                                                taskServiceProvider)
                                                            .completeTask(
                                                                taskId),
                                                        onPause: (taskId) => ref
                                                            .read(
                                                                taskServiceProvider)
                                                            .pauseTask(taskId),
                                                        onResume: (taskId) => ref
                                                            .read(
                                                                taskServiceProvider)
                                                            .resumeTask(taskId),
                                                        onSkip: (taskId) => ref
                                                            .read(
                                                                taskServiceProvider)
                                                            .skipTask(taskId),
                                                        onAbandon: (taskId) => ref
                                                            .read(
                                                                taskServiceProvider)
                                                            .abandonTask(
                                                                taskId),
                                                      ),
                                                      childCount:
                                                          entry.value.length,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          const SliverPadding(
                                              padding:
                                                  EdgeInsets.only(bottom: 120)),
                                        ],
                                      ),
                                    ),
                    ),
                  ),
                ),
              ])),

          // ─── AI dim overlay ───────────────────────────────────────────
          if (_aiOpen)
            Positioned.fill(
              bottom: 340,
              child: GestureDetector(
                onTap: () => setState(() => _aiOpen = false),
                child: Container(color: Colors.black.withValues(alpha: 0.18)),
              ),
            ),

          // ─── AI Panel ────────────────────────────────────────────────
          if (_aiOpen)
            Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AiRoutinePanel(
                  routineState: s,
                  todayTasks: (ref.read(customTasksProvider)[_todayKey] ?? []),
                  onAddTask: (t) async {
                    await _createOneOffTask(AddTaskRequest(
                      repeatRule: 'none',
                      title: t.title,
                      date: t.date,
                      time: TimeOfDay(
                        hour: int.tryParse(t.time.split(':').first) ?? 9,
                        minute: t.time.split(':').length > 1
                            ? int.tryParse(t.time.split(':')[1]) ?? 0
                            : 0,
                      ),
                      durationMinutes: 30,
                      routineType: 'custom',
                      category: 'Personal',
                      notes: 'Added from AI suggestion.',
                      reminderEnabled: false,
                      emoji: t.emoji,
                      color: t.color,
                    ));
                    final map = Map<String, List<CustomTask>>.from(
                        ref.read(customTasksProvider));
                    map[_todayKey] = [...(map[_todayKey] ?? []), t];
                    ref.read(customTasksProvider.notifier).state = map;
                  },
                  onRemoveTask: (id) {
                    final map = Map<String, List<CustomTask>>.from(
                        ref.read(customTasksProvider));
                    map[_todayKey] = (map[_todayKey] ?? [])
                        .where((t) => t.id != id)
                        .toList();
                    ref.read(customTasksProvider.notifier).state = map;
                  },
                  onSuggestionGenerated: _saveSuggestion,
                  onSuggestionAccepted: _acceptSuggestion,
                  onSuggestionDismissed: _dismissSuggestion,
                )),

          // ─── Setup Popup Overlays ──────────────────────────────────
          if (!s.skinCareSetUp && _filter == RoutineFilter.skinCare)
            Positioned.fill(
              child: _buildSetupPopup(
                emoji: '🌿',
                title: 'No skin care today',
                subtitle:
                    'Set up your skin care routine\nand it will appear here automatically',
                buttonText: 'Set up Skin Care',
                filter: RoutineFilter.skinCare,
                buttonColors: [
                  const Color(0xFFC4F6BB),
                  const Color(0xFFA1F094)
                ],
                shadowColor: const Color(0xFFA1F094).withValues(alpha: 0.4),
                glassColor: const Color(0xFF051105)
                    .withValues(alpha: 0.20), // Slight deep green tint
              ),
            ),

          if (!s.classesSetUp && _filter == RoutineFilter.classes)
            Positioned.fill(
              child: _buildSetupPopup(
                emoji: '🎓',
                title: 'No classes today',
                subtitle:
                    'Set up your class schedule\nand it will appear here automatically',
                buttonText: 'Set up Classes',
                filter: RoutineFilter.classes,
                buttonColors: [
                  const Color(0xFF90C2F9),
                  const Color(0xFF60B8FF)
                ],
                shadowColor: const Color(0xFF60B8FF).withValues(alpha: 0.4),
                glassColor: const Color(0xFF050811)
                    .withValues(alpha: 0.20), // Slight deep blue tint
              ),
            ),

          if (!s.eatingSetUp && _filter == RoutineFilter.eating)
            Positioned.fill(
              child: _buildSetupPopup(
                emoji: '🍽️',
                title: 'No meals today',
                subtitle:
                    'Set up your eating routine\nand it will appear here automatically',
                buttonText: 'Set up Eating Routine',
                filter: RoutineFilter.eating,
                buttonColors: [
                  const Color(0xFFFFD480),
                  const Color(0xFFFFB830)
                ],
                shadowColor: const Color(0xFFFFB830).withValues(alpha: 0.4),
                glassColor: const Color(0xFF110800)
                    .withValues(alpha: 0.20), // Slight deep amber/brown tint
              ),
            ),
          if ((s.routineTemplates['supplements'] ?? const []).isEmpty &&
              _filter == RoutineFilter.supplements)
            Positioned.fill(
              child: _buildSetupPopup(
                emoji: '💊',
                title: 'No supplements today',
                subtitle:
                    'Set up supplements\nand they will appear here automatically',
                buttonText: 'Set up Supplements',
                filter: RoutineFilter.supplements,
                buttonColors: [
                  const Color(0xFF5EEAD4),
                  const Color(0xFF14B8A6)
                ],
                shadowColor: const Color(0xFF14B8A6).withValues(alpha: 0.4),
                glassColor: const Color(0xFF021312).withValues(alpha: 0.20),
              ),
            ),
        ]),
      ),
    );
  }

  void _absorbSetupPopupTap() {}

  Widget _buildSetupPopup({
    required String emoji,
    required String title,
    required String subtitle,
    required String buttonText,
    required RoutineFilter filter,
    required List<Color> buttonColors,
    required Color shadowColor,
    required Color glassColor,
  }) {
    return GestureDetector(
      onTap: () => _onFilter(RoutineFilter.all, ref.read(routineProvider)),
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.transparent, // Floating popup, no dimming
        child: Center(
          child: GestureDetector(
            onTap: _absorbSetupPopupTap,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withValues(alpha: 0.1), // Softer glass shadow
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              // Stack to separate BackdropFilter from content
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 1. The Blur Layer
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(30), // Match reference
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                            sigmaX: 28, sigmaY: 28), // Smooth creamy glass blur
                        child: Container(
                          color:
                              glassColor, // Deep tinted ultra-transparent base
                        ),
                      ),
                    ),
                  ),
                  // 2. The Content Layer
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 36),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white
                            .withValues(alpha: 0.25), // Soft white rim
                        width: 1.0,
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(
                              alpha:
                                  0.15), // Faint frost reflection at the edge
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(emoji,
                            style: const TextStyle(fontSize: 48, height: 1.0)),
                        const SizedBox(height: 16),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white, // White text on dark glass
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(
                                alpha: 0.7), // Slightly dimmed white text
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        GestureDetector(
                          onTap: () => _doSetup(filter),
                          child: Container(
                            width: double.infinity,
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(26),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      shadowColor, // Glowing specific color shadow
                                  blurRadius: 15,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.95),
                                  Colors.white.withValues(alpha: 0.2),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(1.5),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24.5),
                                  gradient: LinearGradient(
                                    colors: buttonColors,
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    Positioned(
                                      top: 0,
                                      left: 16,
                                      right: 16,
                                      child: Container(
                                        height: 12,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                  bottom: Radius.circular(12)),
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.white
                                                  .withValues(alpha: 0.9),
                                              Colors.white
                                                  .withValues(alpha: 0.0),
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Center(
                                      child: Text(
                                        buttonText,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                          letterSpacing: 0.1,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// _TimelineRow, _EmptyState → now TimelineRow, TimelineEmptyState in timeline_section.dart

class _HeaderActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _HeaderActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 17),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.9),
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}

class _DateStrip extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelected;

  const _DateStrip({
    required this.selectedDate,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = List.generate(14, (index) => today.add(Duration(days: index)));

    return SizedBox(
      height: 54,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = days[index];
          final selected = DateUtils.isSameDay(day, selectedDate);
          return InkWell(
            onTap: () => onSelected(day),
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 62,
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF0F111A)
                    : Colors.white.withValues(alpha: 0.52),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? Colors.transparent
                      : Colors.white.withValues(alpha: 0.72),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    index == 0
                        ? 'TOD'
                        : index == 1
                            ? 'TMR'
                            : [
                                'MON',
                                'TUE',
                                'WED',
                                'THU',
                                'FRI',
                                'SAT',
                                'SUN'
                              ][day.weekday - 1],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: selected ? Colors.white70 : kSub,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: selected ? Colors.white : kInk,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SETTINGS PILL  — transparent liquid-drop glass bubble
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsPill extends StatelessWidget {
  final VoidCallback onTap;
  const _SettingsPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // Almost fully transparent — just a whisper of fill
          color: Colors.white.withValues(alpha: 0.08),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.55),
            width: 1.5,
          ),
          boxShadow: [
            // Soft ambient glow underneath (liquid drop shadow)
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.60),
              blurRadius: 8,
              spreadRadius: 0,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 10,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Top-left specular gloss arc (the "liquid drop" shine)
            Align(
              alignment: const Alignment(-0.3, -0.5),
              child: Container(
                width: 16,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.90),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            // Settings icon
            const Center(
              child: Icon(
                Icons.settings_rounded,
                size: 17,
                color: Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// All timeline helper functions (hexColor, fmtMin, parseMin, mealLabel, normalizeTime)
// are now exported from timeline_section.dart as tl-prefixed functions.
