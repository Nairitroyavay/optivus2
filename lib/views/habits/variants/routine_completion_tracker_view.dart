import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/models/day_summary_model.dart';
import 'package:optivus2/models/habit_model.dart';
import 'package:optivus2/models/task_model.dart';

class RoutineCompletionTrackerView extends ConsumerWidget {
  final HabitModel habit;

  const RoutineCompletionTrackerView({super.key, required this.habit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const _InlineState(message: 'No authenticated user.');
    }

    final now = DateTime.now();
    final todayStart = _dayStart(now);
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    final taskWindowStart = todayStart.subtract(const Duration(days: 27));

    final summariesStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('dailySummaries')
        .orderBy('date', descending: true)
        .limit(28)
        .snapshots();
    final tasksStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .where(
          'plannedStart',
          isGreaterThanOrEqualTo: Timestamp.fromDate(taskWindowStart),
        )
        .where('plannedStart', isLessThan: Timestamp.fromDate(tomorrowStart))
        .orderBy('plannedStart')
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: summariesStream,
      builder: (context, summariesSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: tasksStream,
          builder: (context, tasksSnap) {
            if (_isLoading(summariesSnap) || _isLoading(tasksSnap)) {
              return const _LoadingState();
            }

            final error = summariesSnap.error ?? tasksSnap.error;
            if (error != null) {
              return _InlineState(message: 'Could not load routines: $error');
            }

            final summaries = summariesSnap.data?.docs
                    .map(DaySummary.fromFirestore)
                    .toList() ??
                const <DaySummary>[];
            final tasks =
                tasksSnap.data?.docs.map(TaskModel.fromFirestore).toList() ??
                    const <TaskModel>[];
            final model = _RoutineCompletionModel(
              now: now,
              summaries: summaries,
              tasks: tasks,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(habitName: habit.name),
                const SizedBox(height: 14),
                _HeroCard(model: model),
                const SizedBox(height: 14),
                _DataCoverageCard(model: model),
                const SizedBox(height: 14),
                _TodayBlocksCard(tasks: model.todayTasks),
                const SizedBox(height: 14),
                _RoutineTableCard(rows: model.routineRows),
                const SizedBox(height: 14),
                _DriftHeatmapCard(points: model.heatmapPoints),
                const SizedBox(height: 14),
                _WeeklyRingsCard(days: model.weekDays),
                const SizedBox(height: 14),
                _WeekdayPatternsCard(patterns: model.weekdayPatterns),
              ],
            );
          },
        );
      },
    );
  }

  bool _isLoading(AsyncSnapshot<Object?> snap) =>
      snap.connectionState == ConnectionState.waiting && !snap.hasData;
}

class _RoutineCompletionModel {
  final DateTime now;
  final List<DaySummary> summaries;
  final List<TaskModel> tasks;

  late final String todayKey = _dateKey(now);
  late final DaySummary? todaySummary = _summaryByDate[todayKey];
  late final Map<String, List<TaskModel>> tasksByDate = _tasksGroupedByDate();
  late final List<TaskModel> todayTasks = tasks
      .where((task) => _dateKey(task.plannedStart) == todayKey)
      .toList()
    ..sort((a, b) => a.plannedStart.compareTo(b.plannedStart));
  late final Map<String, double> liveRoutinePct =
      _routinePctFromTasks(todayTasks);
  late final int todayPct =
      (_completionPctForDate(now) * 100).round().clamp(0, 100);
  late final List<_RoutineRowData> routineRows = _routineSpecs
      .map((spec) => _RoutineRowData(
            spec: spec,
            pct: _pctForSpec(spec),
            completed: _completedCountForSpec(spec),
            scheduled: _scheduledCountForSpec(spec),
          ))
      .toList();
  late final List<_WeekRingData> weekDays = _buildWeekDays();
  late final List<_WeekdayPattern> weekdayPatterns = _buildWeekdayPatterns();
  late final List<_HeatmapPoint> heatmapPoints = _buildHeatmapPoints();
  late final int completedBlocks =
      todayTasks.where((task) => task.state == TaskState.completed).length;
  late final Map<String, double> taskCompletionPctByDate = {
    for (final entry in tasksByDate.entries)
      entry.key: _overallPctFromRoutineMap(_routinePctFromTasks(entry.value)),
  };
  late final int summarySignalDays =
      summaries.where(_summaryHasRoutineSignal).length;
  late final int taskSignalDays = taskCompletionPctByDate.length;
  late final int driftSampleCount =
      heatmapPoints.fold(0, (total, point) => total + point.sampleCount);
  late final int driftUnavailableBlocks = tasks
      .where(
          (task) => !_excludedRoutineSkip(task) && _taskDriftPct(task) == null)
      .length;
  late final bool hasTodayCompletionSignal =
      (todaySummary != null && _summaryHasRoutineSignal(todaySummary!)) ||
          todayTasks.isNotEmpty;

  late final Map<String, DaySummary> _summaryByDate = {
    for (final summary in summaries) summary.date: summary,
  };

  _RoutineCompletionModel({
    required this.now,
    required this.summaries,
    required this.tasks,
  });

  double _pctForSpec(_RoutineSpec spec) {
    final summary = todaySummary;
    if (summary != null && _summaryHasRoutineSignal(summary)) {
      final summaryPct = _summaryPctForSpec(summary, spec);
      if (summaryPct != null) return summaryPct;
    }
    return liveRoutinePct[spec.key] ?? 0;
  }

  int _completedCountForSpec(_RoutineSpec spec) {
    return todayTasks
        .where((task) =>
            _canonicalRoutineKey(task) == spec.key &&
            task.state == TaskState.completed)
        .length;
  }

  int _scheduledCountForSpec(_RoutineSpec spec) {
    return todayTasks
        .where((task) => _canonicalRoutineKey(task) == spec.key)
        .length;
  }

  List<_WeekRingData> _buildWeekDays() {
    return [
      for (var i = 6; i >= 0; i--)
        _weekRingForDate(_dayStart(now).subtract(Duration(days: i))),
    ];
  }

  _WeekRingData _weekRingForDate(DateTime date) {
    final pct = _completionPctForDate(date);
    return _WeekRingData(date: date, pct: pct.clamp(0, 1).toDouble());
  }

  List<_WeekdayPattern> _buildWeekdayPatterns() {
    final buckets = <int, List<double>>{
      for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++)
        weekday: <double>[],
    };

    for (final summary in summaries) {
      final parsed = DateTime.tryParse(summary.date);
      if (parsed == null) continue;
      if (!_summaryHasRoutineSignal(summary)) continue;
      buckets[parsed.weekday]?.add(summary.overallPct.clamp(0, 1).toDouble());
    }

    for (final entry in taskCompletionPctByDate.entries) {
      final summary = _summaryByDate[entry.key];
      if (summary != null && _summaryHasRoutineSignal(summary)) continue;
      final parsed = DateTime.tryParse(entry.key);
      if (parsed == null) continue;
      buckets[parsed.weekday]?.add(entry.value.clamp(0, 1).toDouble());
    }

    return [
      for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++)
        _WeekdayPattern(
          weekday: weekday,
          averagePct: _average(buckets[weekday] ?? const <double>[]),
        ),
    ];
  }

  List<_HeatmapPoint> _buildHeatmapPoints() {
    final buckets = <String, List<double>>{};
    for (final task in tasks) {
      if (_excludedRoutineSkip(task)) continue;
      final drift = _taskDriftPct(task);
      if (drift == null) continue;
      final key = '${task.plannedStart.weekday}:${task.plannedStart.hour}';
      buckets.putIfAbsent(key, () => <double>[]).add(drift);
    }

    final points = <_HeatmapPoint>[];
    for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++) {
      for (var hour = 0; hour < 24; hour++) {
        final values = buckets['$weekday:$hour'] ?? const <double>[];
        points.add(
          _HeatmapPoint(
            weekday: weekday,
            hour: hour,
            sampleCount: values.length,
            averageAbsDriftPct: values.isEmpty
                ? 0
                : values.map((v) => v.abs()).reduce((a, b) => a + b) /
                    values.length,
          ),
        );
      }
    }
    return points;
  }

  Map<String, List<TaskModel>> _tasksGroupedByDate() {
    final grouped = <String, List<TaskModel>>{};
    for (final task in tasks) {
      grouped
          .putIfAbsent(_dateKey(task.plannedStart), () => <TaskModel>[])
          .add(task);
    }
    return grouped;
  }

  double _completionPctForDate(DateTime date) {
    final key = _dateKey(date);
    final summary = _summaryByDate[key];
    if (summary != null && _summaryHasRoutineSignal(summary)) {
      return summary.overallPct;
    }
    return taskCompletionPctByDate[key] ?? 0;
  }
}

class _Header extends StatelessWidget {
  final String habitName;

  const _Header({required this.habitName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Routine Completion',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: kInk,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            habitName,
            style: TextStyle(
              color: kSub.withValues(alpha: 0.72),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final _RoutineCompletionModel model;

  const _HeroCard({required this.model});

  @override
  Widget build(BuildContext context) {
    final hasSummary = model.todaySummary != null &&
        _summaryHasRoutineSignal(model.todaySummary!);
    return LiquidCard(
      radius: 22,
      padding: const EdgeInsets.all(18),
      tint: kBlue.withValues(alpha: 0.08),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            height: 92,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: model.todayPct / 100,
                  strokeWidth: 10,
                  backgroundColor: kSub.withValues(alpha: 0.10),
                  valueColor: const AlwaysStoppedAnimation<Color>(kBlue),
                  strokeCap: StrokeCap.round,
                ),
                Center(
                  child: Text(
                    '${model.todayPct}%',
                    style: const TextStyle(
                      color: kInk,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Today completion',
                  style: TextStyle(
                    color: kInk,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${model.completedBlocks}/${model.todayTasks.length} blocks completed',
                  style: TextStyle(
                    color: kSub.withValues(alpha: 0.76),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  !model.hasTodayCompletionSignal
                      ? 'No routine data recorded for today.'
                      : hasSummary
                          ? 'Using today\'s day-close summary.'
                          : 'Live from today\'s routine blocks.',
                  style: TextStyle(
                    color: kSub.withValues(alpha: 0.62),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          _PillBadge(
            label: !model.hasTodayCompletionSignal
                ? 'No data'
                : (hasSummary ? 'Summary' : 'Live'),
            color: !model.hasTodayCompletionSignal
                ? kSub
                : (hasSummary ? kMint : kAmber),
          ),
        ],
      ),
    );
  }
}

class _DataCoverageCard extends StatelessWidget {
  final _RoutineCompletionModel model;

  const _DataCoverageCard({required this.model});

  @override
  Widget build(BuildContext context) {
    final completionLabel =
        model.summarySignalDays > 0 && model.taskSignalDays > 0
            ? 'summary + tasks'
            : model.summarySignalDays > 0
                ? 'summary only'
                : model.taskSignalDays > 0
                    ? 'tasks only'
                    : 'waiting';
    final driftLabel = model.driftSampleCount > 0
        ? '${model.driftSampleCount} samples'
        : 'waiting';

    return _SectionCard(
      title: 'Data coverage',
      child: Column(
        children: [
          _CoverageRow(
            label: 'Completion',
            value: completionLabel,
            color: model.summarySignalDays + model.taskSignalDays > 0
                ? kMint
                : kAmber,
          ),
          const SizedBox(height: 10),
          _CoverageRow(
            label: 'Drift timing',
            value: driftLabel,
            color: model.driftSampleCount > 0 ? kBlue : kAmber,
          ),
          const SizedBox(height: 10),
          _CoverageRow(
            label: 'Unavailable blocks',
            value: '${model.driftUnavailableBlocks}',
            color: model.driftUnavailableBlocks == 0 ? kMint : kRose,
          ),
        ],
      ),
    );
  }
}

class _CoverageRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _CoverageRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: kInk,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        _PillBadge(label: value, color: color),
      ],
    );
  }
}

class _TodayBlocksCard extends StatelessWidget {
  final List<TaskModel> tasks;

  const _TodayBlocksCard({required this.tasks});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Today blocks',
      trailing: Text(
        '${tasks.length}',
        style: TextStyle(
          color: kSub.withValues(alpha: 0.7),
          fontWeight: FontWeight.w900,
        ),
      ),
      child: tasks.isEmpty
          ? const _EmptyCopy(message: 'No routine blocks scheduled today.')
          : ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final task in tasks) _TaskBlockRow(task: task),
                  ],
                ),
              ),
            ),
    );
  }
}

class _TaskBlockRow extends StatelessWidget {
  final TaskModel task;

  const _TaskBlockRow({required this.task});

  @override
  Widget build(BuildContext context) {
    final badge = _badgeForState(task.state);
    final drift = _taskDriftPct(task);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kWhite.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kWhite.withValues(alpha: 0.70)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _routineColor(_canonicalRoutineKey(task))
                  .withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _routineIcon(_canonicalRoutineKey(task)),
              color: _routineColor(_canonicalRoutineKey(task)),
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title.isEmpty ? _routineLabel(task) : task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: kInk,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_timeLabel(task.plannedStart)}-${_timeLabel(task.plannedEnd)}'
                  '${drift == null ? '' : ' | drift ${drift.round()}%'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: kSub.withValues(alpha: 0.72),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _PillBadge(label: badge.label, color: badge.color),
        ],
      ),
    );
  }
}

class _RoutineTableCard extends StatelessWidget {
  final List<_RoutineRowData> rows;

  const _RoutineTableCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Routine type table',
      child: Column(
        children: [
          for (final row in rows) _RoutineTableRow(row: row),
        ],
      ),
    );
  }
}

class _RoutineTableRow extends StatelessWidget {
  final _RoutineRowData row;

  const _RoutineTableRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final pct = (row.pct * 100).round().clamp(0, 100);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: row.spec.color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(row.spec.icon, color: row.spec.color, size: 19),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.spec.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: kInk,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      '$pct%',
                      style: TextStyle(
                        color: row.spec.color,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    minHeight: 8,
                    backgroundColor: kSub.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(row.spec.color),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${row.completed}/${row.scheduled} blocks completed',
                  style: TextStyle(
                    color: kSub.withValues(alpha: 0.65),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DriftHeatmapCard extends StatelessWidget {
  final List<_HeatmapPoint> points;

  const _DriftHeatmapCard({required this.points});

  @override
  Widget build(BuildContext context) {
    final byKey = {
      for (final point in points) '${point.weekday}:${point.hour}': point,
    };
    final maxDrift = points.fold<double>(
      0,
      (max, point) => math.max(max, point.averageAbsDriftPct),
    );

    return _SectionCard(
      title: 'Drift heatmap',
      trailing: Text(
        'hour x weekday',
        style: TextStyle(
          color: kSub.withValues(alpha: 0.62),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
      child: maxDrift <= 0
          ? const _EmptyCopy(message: 'No drift timing available yet.')
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 32, bottom: 8),
                  child: Row(
                    children: [
                      for (final weekday in _weekdayShortLabels)
                        Expanded(
                          child: Text(
                            weekday,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: kSub.withValues(alpha: 0.64),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                for (var hour = 0; hour < 24; hour++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 32,
                          child: Text(
                            hour % 6 == 0
                                ? hour.toString().padLeft(2, '0')
                                : '',
                            style: TextStyle(
                              color: kSub.withValues(alpha: 0.52),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        for (var weekday = DateTime.monday;
                            weekday <= DateTime.sunday;
                            weekday++)
                          Expanded(
                            child: _HeatCell(
                              point: byKey['$weekday:$hour'] ??
                                  _HeatmapPoint(
                                    weekday: weekday,
                                    hour: hour,
                                    sampleCount: 0,
                                    averageAbsDriftPct: 0,
                                  ),
                              maxDrift: maxDrift,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _HeatCell extends StatelessWidget {
  final _HeatmapPoint point;
  final double maxDrift;

  const _HeatCell({required this.point, required this.maxDrift});

  @override
  Widget build(BuildContext context) {
    final intensity = maxDrift <= 0 || point.sampleCount == 0
        ? 0.0
        : (point.averageAbsDriftPct / maxDrift).clamp(0.16, 1.0);
    final color = point.sampleCount == 0
        ? kSub.withValues(alpha: 0.06)
        : Color.lerp(kMint, kCoral, intensity)!
            .withValues(alpha: 0.28 + 0.5 * intensity);

    return Tooltip(
      message: point.sampleCount == 0
          ? 'No drift logs'
          : '${_weekdayName(point.weekday)} ${point.hour}:00 - '
              '${point.averageAbsDriftPct.round()}% avg drift',
      child: Container(
        height: 13,
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

class _WeeklyRingsCard extends StatelessWidget {
  final List<_WeekRingData> days;

  const _WeeklyRingsCard({required this.days});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Weekly view',
      child: Row(
        children: [
          for (final day in days)
            Expanded(
              child: _WeekRing(day: day),
            ),
        ],
      ),
    );
  }
}

class _WeekRing extends StatelessWidget {
  final _WeekRingData day;

  const _WeekRing({required this.day});

  @override
  Widget build(BuildContext context) {
    final pct = (day.pct * 100).round().clamp(0, 100);
    return Column(
      children: [
        SizedBox(
          width: 38,
          height: 38,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: pct / 100,
                strokeWidth: 5,
                backgroundColor: kSub.withValues(alpha: 0.10),
                valueColor: AlwaysStoppedAnimation<Color>(
                  pct >= 80 ? kMint : (pct >= 40 ? kAmber : kCoral),
                ),
                strokeCap: StrokeCap.round,
              ),
              Center(
                child: Text(
                  '$pct',
                  style: const TextStyle(
                    color: kInk,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _weekdayShortLabels[day.date.weekday - 1],
          style: TextStyle(
            color: kSub.withValues(alpha: 0.68),
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _WeekdayPatternsCard extends StatelessWidget {
  final List<_WeekdayPattern> patterns;

  const _WeekdayPatternsCard({required this.patterns});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Weekday patterns',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final pattern in patterns)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${_weekdayPlural(pattern.weekday)} you average '
                '${(pattern.averagePct * 100).round()}%.',
                style: TextStyle(
                  color: kInk.withValues(alpha: 0.82),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: kInk,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _PillBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _PillBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(child: CircularProgressIndicator(color: kBlue)),
    );
  }
}

class _InlineState extends StatelessWidget {
  final String message;

  const _InlineState({required this.message});

  @override
  Widget build(BuildContext context) {
    return LiquidCard(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Text(
        message,
        style: TextStyle(
          color: kSub.withValues(alpha: 0.76),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyCopy extends StatelessWidget {
  final String message;

  const _EmptyCopy({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            color: kSub.withValues(alpha: 0.72),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _RoutineSpec {
  final String key;
  final String label;
  final List<String> summaryKeys;
  final IconData icon;
  final Color color;

  const _RoutineSpec({
    required this.key,
    required this.label,
    required this.summaryKeys,
    required this.icon,
    required this.color,
  });
}

class _RoutineRowData {
  final _RoutineSpec spec;
  final double pct;
  final int completed;
  final int scheduled;

  const _RoutineRowData({
    required this.spec,
    required this.pct,
    required this.completed,
    required this.scheduled,
  });
}

class _WeekRingData {
  final DateTime date;
  final double pct;

  const _WeekRingData({required this.date, required this.pct});
}

class _WeekdayPattern {
  final int weekday;
  final double averagePct;

  const _WeekdayPattern({required this.weekday, required this.averagePct});
}

class _HeatmapPoint {
  final int weekday;
  final int hour;
  final int sampleCount;
  final double averageAbsDriftPct;

  const _HeatmapPoint({
    required this.weekday,
    required this.hour,
    required this.sampleCount,
    required this.averageAbsDriftPct,
  });
}

class _StateBadge {
  final String label;
  final Color color;

  const _StateBadge(this.label, this.color);
}

const _routineSpecs = [
  _RoutineSpec(
    key: 'skin_care',
    label: 'Skin care',
    summaryKeys: ['skin_care'],
    icon: Icons.spa_rounded,
    color: kMint,
  ),
  _RoutineSpec(
    key: 'classes',
    label: 'Classes',
    summaryKeys: ['classes', 'class'],
    icon: Icons.school_rounded,
    color: kBlue,
  ),
  _RoutineSpec(
    key: 'eating',
    label: 'Eating',
    summaryKeys: ['eating'],
    icon: Icons.restaurant_rounded,
    color: kRose,
  ),
  _RoutineSpec(
    key: 'fixed_schedule',
    label: 'Fixed schedule',
    summaryKeys: ['fixed_schedule', 'fixed'],
    icon: Icons.event_available_rounded,
    color: kAmber,
  ),
  _RoutineSpec(
    key: 'custom',
    label: 'Custom',
    summaryKeys: ['custom'],
    icon: Icons.tune_rounded,
    color: kPurple,
  ),
];

const _weekdayShortLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

Map<String, double> _routinePctFromTasks(List<TaskModel> tasks) {
  final buckets = <String, List<double>>{};
  for (final task in tasks) {
    if (_excludedRoutineSkip(task)) continue;
    final contribution = _routineContribution(task);
    buckets
        .putIfAbsent(_canonicalRoutineKey(task), () => <double>[])
        .add(contribution);
  }
  return {
    for (final entry in buckets.entries)
      entry.key: entry.value.isEmpty
          ? 0
          : entry.value.reduce((a, b) => a + b) / entry.value.length,
  };
}

double _routineContribution(TaskModel task) {
  switch (task.state) {
    case TaskState.completed:
      return 1;
    case TaskState.started:
    case TaskState.paused:
      final end = task.state == TaskState.paused && task.pausedAt != null
          ? task.pausedAt!
          : DateTime.now();
      final elapsed =
          end.difference(task.actualStart ?? task.plannedStart).inMinutes;
      if (task.plannedDurationMin <= 0) return 0;
      return (elapsed / task.plannedDurationMin).clamp(0, 0.95).toDouble();
    case TaskState.abandoned:
    case TaskState.skipped:
    case TaskState.scheduled:
      return 0;
  }
}

bool _excludedRoutineSkip(TaskModel task) {
  if (task.state != TaskState.skipped) return false;
  final tag = (task.reasonTag ?? '').toLowerCase();
  return tag == 'valid_reason' || tag == 'day_off' || tag == 'illness';
}

double _overallPctFromRoutineMap(Map<String, double> pcts) {
  if (pcts.isEmpty) return 0;
  return pcts.values.reduce((a, b) => a + b) / pcts.length;
}

double? _summaryPctForSpec(DaySummary summary, _RoutineSpec spec) {
  final values = <double>[];
  for (final entry in summary.perRoutinePct.entries) {
    final key = _canonicalSummaryKey(entry.key);
    if (key == spec.key || (spec.key == 'custom' && key == 'custom')) {
      values.add(entry.value.clamp(0, 1).toDouble());
    }
  }
  if (values.isEmpty) return null;
  return values.reduce((a, b) => a + b) / values.length;
}

bool _summaryHasRoutineSignal(DaySummary summary) {
  return summary.perRoutinePct.isNotEmpty ||
      summary.tasksScheduled > 0 ||
      summary.routinesCompleted > 0 ||
      summary.routinesMissed > 0;
}

String _canonicalSummaryKey(String key) {
  final normalized = key.trim().toLowerCase();
  for (final spec in _routineSpecs) {
    if (spec.summaryKeys.contains(normalized)) return spec.key;
  }
  return 'custom';
}

String _canonicalRoutineKey(TaskModel task) {
  switch (task.type) {
    case TaskType.skinCare:
      return 'skin_care';
    case TaskType.eating:
      return 'eating';
    case TaskType.classBlock:
      return 'classes';
    case TaskType.fixed:
      return 'fixed_schedule';
    case TaskType.custom:
      return 'custom';
    case TaskType.habitBlock:
      return 'custom';
  }
}

double? _taskDriftPct(TaskModel task) {
  if (task.driftPct != null) return task.driftPct;
  if (task.plannedDurationMin <= 0) return null;

  final duration = task.actualDurationMin;
  if (duration != null) {
    return ((duration - task.plannedDurationMin) / task.plannedDurationMin) *
        100;
  }

  if (task.state == TaskState.skipped) return -100;

  final actualEnd = task.actualEnd ?? task.abandonedAt ?? task.skippedAt;
  final actualStart = task.actualStart;
  if (actualStart != null && actualEnd != null) {
    final actualDuration = actualEnd.difference(actualStart).inMinutes;
    return ((actualDuration - task.plannedDurationMin) /
            task.plannedDurationMin) *
        100;
  }

  if (actualStart == null) return null;
  final startDrift =
      actualStart.difference(task.plannedStart).inMinutes.toDouble();
  return (startDrift / task.plannedDurationMin) * 100;
}

_StateBadge _badgeForState(TaskState state) {
  switch (state) {
    case TaskState.completed:
      return const _StateBadge('Done', kMint);
    case TaskState.started:
      return const _StateBadge('Active', kBlue);
    case TaskState.paused:
      return const _StateBadge('Paused', kAmber);
    case TaskState.abandoned:
      return const _StateBadge('Missed', kCoral);
    case TaskState.skipped:
      return const _StateBadge('Skipped', kRose);
    case TaskState.scheduled:
      return const _StateBadge('Scheduled', kSub);
  }
}

String _routineLabel(TaskModel task) {
  return _routineSpecs
      .firstWhere((spec) => spec.key == _canonicalRoutineKey(task))
      .label;
}

IconData _routineIcon(String key) {
  return _routineSpecs
      .firstWhere((spec) => spec.key == key, orElse: () => _routineSpecs.last)
      .icon;
}

Color _routineColor(String key) {
  return _routineSpecs
      .firstWhere((spec) => spec.key == key, orElse: () => _routineSpecs.last)
      .color;
}

DateTime _dayStart(DateTime date) => DateTime(date.year, date.month, date.day);

String _dateKey(DateTime date) => '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String _timeLabel(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final suffix = date.hour >= 12 ? 'pm' : 'am';
  return '$hour:$minute$suffix';
}

double _average(List<double> values) {
  if (values.isEmpty) return 0;
  return values.reduce((a, b) => a + b) / values.length;
}

String _weekdayName(int weekday) {
  switch (weekday) {
    case DateTime.monday:
      return 'Monday';
    case DateTime.tuesday:
      return 'Tuesday';
    case DateTime.wednesday:
      return 'Wednesday';
    case DateTime.thursday:
      return 'Thursday';
    case DateTime.friday:
      return 'Friday';
    case DateTime.saturday:
      return 'Saturday';
    default:
      return 'Sunday';
  }
}

String _weekdayPlural(int weekday) => '${_weekdayName(weekday)}s';
