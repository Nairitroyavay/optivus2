import 'package:flutter/material.dart';

import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/models/day_summary_model.dart';
import 'package:optivus2/models/habit_log_model.dart';
import 'package:optivus2/models/habit_model.dart';

/// 12-week (84-day) heatmap of habit hits.
///
/// Each cell encodes one calendar day. Cell intensity is a function of how
/// the day's logged value compares to the habit's daily goal:
///   • Good habits: ratio of summed `quantity` to `dailyGoal`.
///   • Bad habits: inverse — zero slips is full intensity, slips fade towards
///     a "miss" tint.
class StreakHeatmap extends StatelessWidget {
  final HabitModel habit;
  final List<HabitLog> logs;
  final int days;

  const StreakHeatmap({
    super.key,
    required this.habit,
    required this.logs,
    this.days = 84,
  });

  @override
  Widget build(BuildContext context) {
    final today = _truncate(DateTime.now());
    final start = today.subtract(Duration(days: days - 1));
    final byDay = _groupByDay(logs);

    // Build columns of 7 (weeks). The newest week is on the right.
    final columns = (days / 7).ceil();

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 4.0;
        final available = constraints.maxWidth;
        final cell = ((available - spacing * (columns - 1)) / columns)
            .clamp(8.0, 18.0)
            .toDouble();
        final gridWidth = cell * columns + spacing * (columns - 1);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: gridWidth,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int col = 0; col < columns; col++) ...[
                    if (col > 0) const SizedBox(width: spacing),
                    Column(
                      children: [
                        for (int row = 0; row < 7; row++) ...[
                          if (row > 0) const SizedBox(height: spacing),
                          _cell(start, today, byDay, col, row, cell),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            _legend(),
          ],
        );
      },
    );
  }

  Widget _cell(
    DateTime start,
    DateTime today,
    Map<DateTime, num> byDay,
    int col,
    int row,
    double size,
  ) {
    final dayIndex = col * 7 + row;
    final date = start.add(Duration(days: dayIndex));
    final beyondToday = date.isAfter(today);
    final beforeStart = date.isBefore(start);

    if (beyondToday || beforeStart) {
      return SizedBox(width: size, height: size);
    }

    final logged = byDay[date] ?? 0;
    final intensity = _intensityFor(logged);
    final color = _colorFor(intensity, logged > 0);

    return Tooltip(
      message: _tooltipFor(date, logged),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }

  Widget _legend() {
    final base = habit.kind == HabitKind.good ? kMint : kCoral;
    return Row(
      children: [
        Text(
          'Less',
          style: TextStyle(fontSize: 10, color: kSub.withValues(alpha: 0.7)),
        ),
        const SizedBox(width: 6),
        for (final stop in const [0.0, 0.3, 0.55, 0.8, 1.0]) ...[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _colorFor(stop, stop > 0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 3),
        ],
        const SizedBox(width: 4),
        Text(
          'More',
          style: TextStyle(fontSize: 10, color: kSub.withValues(alpha: 0.7)),
        ),
        const Spacer(),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: base, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          habit.kind == HabitKind.good ? 'Hit goal' : 'Stayed clean',
          style: TextStyle(fontSize: 10, color: kSub.withValues(alpha: 0.85)),
        ),
      ],
    );
  }

  Map<DateTime, num> _groupByDay(List<HabitLog> logs) {
    final out = <DateTime, num>{};
    for (final log in logs) {
      if (habit.kind == HabitKind.good && log.logType != 'good') continue;
      if (habit.kind == HabitKind.bad && log.logType != 'slip') continue;
      final day = _truncate(log.occurredAt);
      out[day] = (out[day] ?? 0) + (log.quantity ?? 1);
    }
    return out;
  }

  /// Returns 0.0 — 1.0 representing how "complete" the day was for the habit.
  /// For bad habits, no slips → 1.0; any slip → 0.0 (eliminate) or fades
  /// inversely with target.
  double _intensityFor(num logged) {
    if (habit.kind == HabitKind.good) {
      final goal = habit.dailyGoal ?? 1;
      if (goal <= 0) return logged > 0 ? 1.0 : 0.0;
      return (logged / goal).clamp(0.0, 1.0).toDouble();
    }
    final goalType = habit.goalType ?? BadHabitGoalType.awarenessOnly;
    switch (goalType) {
      case BadHabitGoalType.eliminate:
        return logged == 0 ? 1.0 : 0.0;
      case BadHabitGoalType.reduceToTarget:
        final target = habit.target ?? 0;
        if (target <= 0) return logged == 0 ? 1.0 : 0.0;
        return (1 - (logged / target)).clamp(0.0, 1.0).toDouble();
      case BadHabitGoalType.awarenessOnly:
        return logged == 0 ? 0.4 : 0.7;
    }
  }

  Color _colorFor(double intensity, bool anyActivity) {
    final base = habit.kind == HabitKind.good ? kMint : kCoral;
    final empty = kSub.withValues(alpha: 0.10);
    if (!anyActivity && intensity == 0) return empty;
    final alpha = (0.18 + 0.65 * intensity).clamp(0.0, 1.0);
    return base.withValues(alpha: alpha);
  }

  String _tooltipFor(DateTime date, num logged) {
    final dateLabel = '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    if (habit.kind == HabitKind.good) {
      final goal = habit.dailyGoal ?? 1;
      return '$dateLabel\n${logged.toStringAsFixed(0)} / ${goal.toStringAsFixed(0)} ${habit.unit}';
    }
    final slips = logged.toInt();
    return '$dateLabel\n$slips slip${slips == 1 ? '' : 's'}';
  }

  static DateTime _truncate(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}

/// 12-week heatmap for routine streaks using DaySummary.perRoutinePct.
class RoutineStreakHeatmap extends StatelessWidget {
  final String routineKey;
  final List<DaySummary> summaries;
  final int days;

  const RoutineStreakHeatmap({
    super.key,
    required this.routineKey,
    required this.summaries,
    this.days = 84,
  });

  @override
  Widget build(BuildContext context) {
    final today = _truncate(DateTime.now());
    final start = today.subtract(Duration(days: days - 1));
    final byDay = {
      for (final summary in summaries)
        if (DateTime.tryParse(summary.date) != null)
          _truncate(DateTime.parse(summary.date)):
              summary.perRoutinePct[routineKey] ?? 0,
    };
    final columns = (days / 7).ceil();

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 4.0;
        final cell =
            ((constraints.maxWidth - spacing * (columns - 1)) / columns)
                .clamp(8.0, 18.0)
                .toDouble();
        final gridWidth = cell * columns + spacing * (columns - 1);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: gridWidth,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int col = 0; col < columns; col++) ...[
                    if (col > 0) const SizedBox(width: spacing),
                    Column(
                      children: [
                        for (int row = 0; row < 7; row++) ...[
                          if (row > 0) const SizedBox(height: spacing),
                          _cell(start, today, byDay, col, row, cell),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            _legend(),
          ],
        );
      },
    );
  }

  Widget _cell(
    DateTime start,
    DateTime today,
    Map<DateTime, double> byDay,
    int col,
    int row,
    double size,
  ) {
    final dayIndex = col * 7 + row;
    final date = start.add(Duration(days: dayIndex));
    if (date.isAfter(today)) return SizedBox(width: size, height: size);

    final pct = (byDay[date] ?? 0).clamp(0.0, 1.0);
    final color = pct <= 0
        ? kSub.withValues(alpha: 0.10)
        : kBlue.withValues(alpha: (0.18 + 0.65 * pct).clamp(0.0, 1.0));

    return Tooltip(
      message: '${_dateLabel(date)}\n${(pct * 100).round()}% complete',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }

  Widget _legend() {
    return Row(
      children: [
        Text(
          'Less',
          style: TextStyle(fontSize: 10, color: kSub.withValues(alpha: 0.7)),
        ),
        const SizedBox(width: 6),
        for (final stop in const [0.0, 0.3, 0.55, 0.8, 1.0]) ...[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: stop == 0
                  ? kSub.withValues(alpha: 0.10)
                  : kBlue.withValues(
                      alpha: (0.18 + 0.65 * stop).clamp(0.0, 1.0),
                    ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 3),
        ],
        const SizedBox(width: 4),
        Text(
          'More',
          style: TextStyle(fontSize: 10, color: kSub.withValues(alpha: 0.7)),
        ),
        const Spacer(),
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(color: kBlue, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          'Routine complete',
          style: TextStyle(fontSize: 10, color: kSub.withValues(alpha: 0.85)),
        ),
      ],
    );
  }

  static DateTime _truncate(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  static String _dateLabel(DateTime date) => '${date.year}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
