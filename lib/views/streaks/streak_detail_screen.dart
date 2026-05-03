import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/models/day_summary_model.dart';
import 'package:optivus2/models/habit_log_model.dart';
import 'package:optivus2/models/habit_model.dart';
import 'package:optivus2/models/streak_model.dart';
import 'package:optivus2/services/streak_service.dart';
import 'package:optivus2/views/streaks/streak_heatmap.dart';

const _kRoutinePrefix = 'routine_';

/// Detail view for a single streak. Routes:
///   /streaks/:streakId            → habitId for habit streaks
///   `/streaks/routine_<key>`      → routine-scope streaks
class StreakDetailScreen extends ConsumerWidget {
  final String streakId;

  const StreakDetailScreen({super.key, required this.streakId});

  bool get _isRoutineScope => streakId.startsWith(_kRoutinePrefix);
  String get _routineKey =>
      _isRoutineScope ? streakId.substring(_kRoutinePrefix.length) : streakId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(streakByIdProvider(streakId));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: kInk,
        title: const Text('Streak Details'),
      ),
      body: streakAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: kAmber),
        ),
        error: (err, _) => _Error(message: err.toString()),
        data: (streak) {
          if (streak == null) {
            return _EmptyState(streakId: streakId);
          }
          if (_isRoutineScope) {
            return _RoutineStreakBody(streak: streak, routineKey: _routineKey);
          }
          return _HabitStreakBody(streak: streak);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HABIT-SCOPED BODY
// ─────────────────────────────────────────────────────────────────────────────

class _HabitStreakBody extends ConsumerWidget {
  final Streak streak;

  const _HabitStreakBody({required this.streak});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(habitsProvider);
    final habit = habitsAsync.valueOrNull
        ?.where((h) => h.id == streak.habitId)
        .cast<HabitModel?>()
        .firstWhere((h) => true, orElse: () => null);

    final logsAsync = ref.watch(habitLogsForRangeProvider(
      (habitId: streak.habitId, days: 90),
    ));

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        _HeaderCard(
          title: habit?.name ?? streak.habitId,
          subtitle: habit == null
              ? 'Habit'
              : '${habit.kind.name} • ${habit.trackerType.replaceAll('_', ' ')}',
          accent: _accentForHabit(habit),
          streak: streak,
        ),
        const SizedBox(height: 14),
        if (streak.state == StreakState.paused) ...[
          _PauseBanner(streak: streak),
          const SizedBox(height: 14),
        ],
        _MilestonesStrip(currentCount: streak.currentCount),
        const SizedBox(height: 14),
        _AccountabilityCard(mode: streak.mode),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Activity (last 12 weeks)',
          child: habit == null
              ? const _InlineHint(text: 'Habit data not available.')
              : logsAsync.when(
                  loading: () => const SizedBox(
                    height: 120,
                    child: Center(
                      child: CircularProgressIndicator(color: kAmber),
                    ),
                  ),
                  error: (e, _) => _InlineHint(text: 'Could not load logs: $e'),
                  data: (logs) => StreakHeatmap(habit: habit, logs: logs),
                ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Recent days',
          child: habit == null
              ? const _InlineHint(text: 'Habit data not available.')
              : logsAsync.when(
                  loading: () => const SizedBox(
                    height: 60,
                    child: Center(
                      child: CircularProgressIndicator(color: kAmber),
                    ),
                  ),
                  error: (e, _) => _InlineHint(text: 'Could not load logs: $e'),
                  data: (logs) =>
                      _RecentDaysList(habit: habit, logs: logs, days: 14),
                ),
        ),
      ],
    );
  }

  Color _accentForHabit(HabitModel? habit) {
    if (habit == null) return kAmber;
    return habit.kind == HabitKind.good ? kMint : kCoral;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ROUTINE-SCOPED BODY
// ─────────────────────────────────────────────────────────────────────────────

class _RoutineStreakBody extends ConsumerWidget {
  final Streak streak;
  final String routineKey;

  const _RoutineStreakBody({required this.streak, required this.routineKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summariesAsync = ref.watch(recentDailySummariesProvider(60));

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        _HeaderCard(
          title: routineKey.replaceAll('_', ' '),
          subtitle: 'Routine streak',
          accent: kBlue,
          streak: streak,
        ),
        const SizedBox(height: 14),
        if (streak.state == StreakState.paused) ...[
          _PauseBanner(streak: streak),
          const SizedBox(height: 14),
        ],
        _MilestonesStrip(currentCount: streak.currentCount),
        const SizedBox(height: 14),
        _AccountabilityCard(mode: streak.mode),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Activity (last 12 weeks)',
          child: summariesAsync.when(
            loading: () => const SizedBox(
              height: 120,
              child: Center(
                child: CircularProgressIndicator(color: kAmber),
              ),
            ),
            error: (e, _) =>
                _InlineHint(text: 'Could not load daily summaries: $e'),
            data: (summaries) => RoutineStreakHeatmap(
              routineKey: routineKey,
              summaries: summaries,
            ),
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Recent days',
          child: summariesAsync.when(
            loading: () => const SizedBox(
              height: 60,
              child: Center(
                child: CircularProgressIndicator(color: kAmber),
              ),
            ),
            error: (e, _) =>
                _InlineHint(text: 'Could not load daily summaries: $e'),
            data: (summaries) => _RoutineHistoryList(
                summaries: summaries, routineKey: routineKey),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;
  final Streak streak;

  const _HeaderCard({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidCard(
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Text('🔥',
                      style: TextStyle(
                        fontSize: 26,
                        color: accent,
                      )),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: kInk,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: kSub.withValues(alpha: 0.76),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _StateChip(state: streak.state),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Current',
                  value: streak.currentCount.toString(),
                  unit: 'days',
                  color: accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  label: 'Longest',
                  value: streak.longestCount.toString(),
                  unit: 'days',
                  color: kPurple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _StatTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidCard.solid(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      tint: color.withValues(alpha: 0.10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: kSub.withValues(alpha: 0.75),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1,
                ),
              ),
              const SizedBox(width: 5),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  unit,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kSub.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MILESTONES
// ─────────────────────────────────────────────────────────────────────────────

class _MilestonesStrip extends StatelessWidget {
  final int currentCount;

  const _MilestonesStrip({required this.currentCount});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Milestones',
      child: SizedBox(
        height: 72,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: kStreakMilestones.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            final m = kStreakMilestones[i];
            final reached = currentCount >= m;
            return Container(
              width: 64,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: reached
                    ? kAmber.withValues(alpha: 0.18)
                    : kSub.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: reached
                      ? kAmber.withValues(alpha: 0.45)
                      : kSub.withValues(alpha: 0.20),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    reached
                        ? Icons.emoji_events_rounded
                        : Icons.emoji_events_outlined,
                    color: reached ? kAmber : kSub.withValues(alpha: 0.55),
                    size: 22,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$m d',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: reached ? kInk : kSub.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACCOUNTABILITY MODE
// ─────────────────────────────────────────────────────────────────────────────

class _AccountabilityCard extends StatelessWidget {
  final AccountabilityMode mode;

  const _AccountabilityCard({required this.mode});

  @override
  Widget build(BuildContext context) {
    final (label, blurb, color, icon) = switch (mode) {
      AccountabilityMode.forgiving => (
          'Forgiving',
          'One miss per ISO week is forgiven before the streak breaks.',
          kMint,
          Icons.spa_rounded,
        ),
      AccountabilityMode.strict => (
          'Strict',
          'Any missed goal breaks the streak immediately.',
          kAmber,
          Icons.shield_rounded,
        ),
      AccountabilityMode.ruthless => (
          'Ruthless',
          'Any slip on a bad habit breaks the streak — overrides goal type.',
          kCoral,
          Icons.local_fire_department_rounded,
        ),
    };

    return _SectionCard(
      title: 'Accountability',
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: kInk,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  blurb,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kSub.withValues(alpha: 0.78),
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

// ─────────────────────────────────────────────────────────────────────────────
// PAUSE BANNER
// ─────────────────────────────────────────────────────────────────────────────

class _PauseBanner extends StatelessWidget {
  final Streak streak;

  const _PauseBanner({required this.streak});

  @override
  Widget build(BuildContext context) {
    final pausedAt = streak.pausedAt;
    final reason = streak.pauseReason ?? 'paused';
    return LiquidCard(
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: kAmber.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.pause_rounded, color: kAmber, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Streak paused (${reason.toLowerCase()})',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: kInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  pausedAt == null
                      ? 'Pre-pause count: ${streak.prePauseCount ?? streak.currentCount} days'
                      : 'Paused on ${_formatDate(pausedAt)} • '
                          '${streak.prePauseCount ?? streak.currentCount} days held',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kSub.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────────────────────────────────────
// HISTORY — habit
// ─────────────────────────────────────────────────────────────────────────────

class _RecentDaysList extends StatelessWidget {
  final HabitModel habit;
  final List<HabitLog> logs;
  final int days;

  const _RecentDaysList({
    required this.habit,
    required this.logs,
    required this.days,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final byDay = <DateTime, num>{};
    for (final log in logs) {
      if (habit.kind == HabitKind.good && log.logType != 'good') continue;
      if (habit.kind == HabitKind.bad && log.logType != 'slip') continue;
      final day = DateTime(
        log.occurredAt.year,
        log.occurredAt.month,
        log.occurredAt.day,
      );
      byDay[day] = (byDay[day] ?? 0) + (log.quantity ?? 1);
    }

    return Column(
      children: List.generate(days, (i) {
        final date = today.subtract(Duration(days: i));
        final logged = byDay[date] ?? 0;
        final hit = _hit(logged);
        return _DayRow(date: date, logged: logged, hit: hit, habit: habit);
      }),
    );
  }

  bool _hit(num logged) {
    if (habit.kind == HabitKind.good) {
      final goal = habit.dailyGoal;
      if (goal == null) return logged > 0;
      return logged >= goal;
    }
    final goalType = habit.goalType ?? BadHabitGoalType.awarenessOnly;
    switch (goalType) {
      case BadHabitGoalType.eliminate:
        return logged == 0;
      case BadHabitGoalType.reduceToTarget:
        final t = habit.target;
        if (t == null) return true;
        return logged <= t;
      case BadHabitGoalType.awarenessOnly:
        return true;
    }
  }
}

class _DayRow extends StatelessWidget {
  final DateTime date;
  final num logged;
  final bool hit;
  final HabitModel habit;

  const _DayRow({
    required this.date,
    required this.logged,
    required this.hit,
    required this.habit,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = hit ? kMint : kCoral;
    final label = habit.kind == HabitKind.good
        ? '${logged.toStringAsFixed(0)} / ${habit.dailyGoal ?? 1} ${habit.unit}'
        : '${logged.toInt()} slip${logged.toInt() == 1 ? '' : 's'}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _formatDate(date),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: kInk,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: kSub.withValues(alpha: 0.85),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[dt.weekday - 1]} ${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HISTORY — routine
// ─────────────────────────────────────────────────────────────────────────────

class _RoutineHistoryList extends StatelessWidget {
  final List<DaySummary> summaries;
  final String routineKey;

  const _RoutineHistoryList({
    required this.summaries,
    required this.routineKey,
  });

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) {
      return const _InlineHint(text: 'No daily summaries yet.');
    }
    return Column(
      children: [
        for (final s in summaries.take(14))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: ((s.perRoutinePct[routineKey] ?? 0) >= 0.999)
                        ? kMint
                        : ((s.perRoutinePct[routineKey] ?? 0) > 0
                            ? kAmber
                            : kCoral),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.date,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: kInk,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  '${(((s.perRoutinePct[routineKey] ?? 0) * 100).round())}%',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: kSub.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMMON CHROME
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return LiquidCard(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: kInk,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  final StreakState state;

  const _StateChip({required this.state});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      StreakState.active => ('Active', kMint),
      StreakState.paused => ('Paused', kAmber),
      StreakState.broken => ('Broken', kCoral),
      StreakState.fresh => ('New', kBlue),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _InlineHint extends StatelessWidget {
  final String text;

  const _InlineHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: kSub.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  final String message;

  const _Error({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: kCoral, size: 44),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: kInk, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String streakId;

  const _EmptyState({required this.streakId});

  @override
  Widget build(BuildContext context) {
    final isGenericEmpty = streakId == '_empty';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: kAmber.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.local_fire_department_outlined,
                size: 40,
                color: kAmber.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No streak yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: kInk,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isGenericEmpty
                  ? 'Streaks will appear here after your first day-close rollup.'
                  : 'Hit your goal at the next day-close to start a streak for "$streakId".',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: kSub.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            LiquidButton.outline(
              label: 'Back',
              color: kInk,
              height: 44,
              onTap: () => context.pop(),
            ),
          ],
        ),
      ),
    );
  }
}
