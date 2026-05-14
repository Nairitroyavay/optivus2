import 'dart:io';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:optivus2/core/constants/event_names.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/models/day_summary_model.dart';
import 'package:optivus2/models/habit_log_model.dart';
import 'package:optivus2/models/habit_model.dart';
import 'package:optivus2/models/screen_time_log_model.dart';
import 'package:optivus2/models/streak_model.dart';
import 'package:optivus2/providers/onboarding_provider.dart';
import 'package:optivus2/views/habits/log_habit_sheet.dart';
import 'package:optivus2/views/habits/variants/mindful_eating_tracker_view.dart';
import 'package:optivus2/models/fitness_activity_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Range & Filter enums for the tracker header
// ─────────────────────────────────────────────────────────────────────────────
enum _TrackerRange { today, week, month }

enum _TrackerFilter { all, good, bad, phone }

// ─────────────────────────────────────────────────────────────────────────────
// Accent colour pool for habit cards — cycles through vibrant LiquidGlass tones
// ─────────────────────────────────────────────────────────────────────────────
const _kGoodAccents = [kMint, kBlue, kPurple, kAmber, kCoral];
const _kBadAccents = [kCoral, kRose, Color(0xFFFF5C93), kPurple];

final _rangeHabitLogsProvider =
    StreamProvider.family<List<HabitLog>, _TrackerRange>((ref, range) {
  if (range == _TrackerRange.today) {
    return ref
        .watch(habitServiceProvider)
        .watchHabitLogsForDate(DateTime.now());
  }
  final days = range == _TrackerRange.week ? 7 : 30;
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(const <HabitLog>[]);

  final now = DateTime.now();
  final start =
      DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));

  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('habit_logs')
      .where('occurredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
      .snapshots()
      .map((snap) => snap.docs.map(HabitLog.fromFirestore).toList());
});

class TrackerTab extends ConsumerStatefulWidget {
  const TrackerTab({super.key});

  @override
  ConsumerState<TrackerTab> createState() => _TrackerTabState();
}

class _TrackerTabState extends ConsumerState<TrackerTab> {
  _TrackerRange _range = _TrackerRange.today;
  _TrackerFilter _filter = _TrackerFilter.all;

  @override
  Widget build(BuildContext context) {
    final habitsAsync = ref.watch(habitsProvider);
    final logsAsync = ref.watch(_rangeHabitLogsProvider(_range));
    final logs = logsAsync.valueOrNull ?? const <HabitLog>[];
    final totals = _totalsByHabit(logs);
    final slipCounts = _slipCountsByHabit(logs);
    final latestLogs = _latestLogsByHabit(logs);
    final streaksAsync = ref.watch(allStreaksProvider);
    final streaksByHabit = _streaksByHabit(
      streaksAsync.valueOrNull ?? const <Streak>[],
    );
    final summaryAsync = ref.watch(todaySummaryProvider);
    final weekSummariesAsync = ref.watch(recentDailySummariesProvider(7));
    // Eating disorder flag: routes junk_food/nutrition onLog to mindful eating sheet.
    final eatFlag = ref.watch(eatingDisorderFlagProvider).valueOrNull ?? false;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: habitsAsync.when(
          loading: () => const _TrackerShimmer(),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 48, color: kCoral),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load habits',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: kInk.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    err.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: kSub),
                  ),
                ],
              ),
            ),
          ),
          data: (habits) {
            final showGood =
                _filter == _TrackerFilter.all || _filter == _TrackerFilter.good;
            final showBad =
                _filter == _TrackerFilter.all || _filter == _TrackerFilter.bad;
            final showPhone = _filter == _TrackerFilter.all ||
                _filter == _TrackerFilter.phone;

            final goodHabits =
                habits.where((h) => h.kind == HabitKind.good).toList();
            final badHabits =
                habits.where((h) => h.kind == HabitKind.bad).toList();

            // Compute mission ring value
            final summary = summaryAsync.valueOrNull;
            final missionPct = _computeMissionPct(
              summary: summary,
              weekSummaries: weekSummariesAsync.valueOrNull ?? [],
              goodHabits: goodHabits,
              totals: totals,
            );
            final habitsCompletedToday = _countCompleted(goodHabits, totals);
            final syncedAt = _latestSyncAt(
              logs: logs,
              summary: summary,
              streaks: streaksByHabit.values,
            );

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── Header with range toggle + filter ──
                SliverToBoxAdapter(
                  child: _TrackerHeaderV2(
                    range: _range,
                    filter: _filter,
                    onRangeChanged: (r) => setState(() => _range = r),
                    onFilterChanged: (f) => setState(() => _filter = f),
                    onAddHabit: () => context.push('/habits/new'),
                  ),
                ),

                // ── Compact mission ring ──
                SliverToBoxAdapter(
                  child: _MissionRingSection(
                    range: _range,
                    missionPct: missionPct,
                    habitsCompleted: habitsCompletedToday,
                    totalHabits: goodHabits.length,
                  ),
                ),

                // ── Good Habits Section ──
                if (showGood && goodHabits.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: LiquidSectionHeader(title: 'Good Habits'),
                  ),
                  if (logsAsync.isLoading && logs.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(20, 4, 20, 14),
                        child: LinearProgressIndicator(
                          minHeight: 2,
                          color: kAmber,
                        ),
                      ),
                    ),
                  if (logsAsync.hasError)
                    SliverToBoxAdapter(
                      child: _InlineError(
                        message:
                            'Unable to load today\'s habit logs: ${logsAsync.error}',
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 268,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: goodHabits.length,
                        itemBuilder: (context, index) {
                          final habit = goodHabits[index];
                          final accent =
                              _kGoodAccents[index % _kGoodAccents.length];
                          final total = totals[habit.id] ?? 0;
                          final daysMultiplier = _range == _TrackerRange.week
                              ? 7
                              : (_range == _TrackerRange.month ? 30 : 1);
                          final goal = (habit.dailyGoal ?? 1) * daysMultiplier;
                          final progress =
                              (total / goal).clamp(0.0, 1.0).toDouble();
                          final latestLog = latestLogs[habit.id];

                          return Padding(
                            padding: const EdgeInsets.only(right: 14),
                            child: SizedBox(
                              width: 280,
                              child: _GoodHabitCard(
                                habit: habit,
                                accent: accent,
                                progress: progress,
                                currentValue: total,
                                goalValue: goal,
                                streakCount:
                                    streaksByHabit[habit.id]?.currentCount ?? 0,
                                onLog: () => _openLogSheet(habit),
                                onUndoLatest: latestLog == null
                                    ? null
                                    : () => _undoLatest(habit, latestLog),
                                onStreakDetails: () =>
                                    _showStreakDetails(habit),
                                onDetails: () => _showDetails(habit),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],

                // ── Bad Habits Section ──
                if (showBad && badHabits.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: LiquidSectionHeader(title: 'Habits to Break'),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 268,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: badHabits.length,
                        itemBuilder: (context, index) {
                          final habit = badHabits[index];
                          final accent =
                              _kBadAccents[index % _kBadAccents.length];
                          final slips = slipCounts[habit.id] ?? 0;
                          final latestLog = latestLogs[habit.id];
                          // Determine whether this specific habit uses
                          // Mindful Eating mode.
                          final isMindfulEatingHabit = eatFlag &&
                              (habit.trackerType == 'junk_food' ||
                                  habit.trackerType == 'nutrition');

                          return Padding(
                            padding: const EdgeInsets.only(right: 14),
                            child: _BadHabitCard(
                              habit: habit,
                              accent: accent,
                              slipCount: slips,
                              streakCount:
                                  streaksByHabit[habit.id]?.currentCount ?? 0,
                              isMindfulEating: isMindfulEatingHabit,
                              onLog: () => _openLogSheet(
                                habit,
                                isMindfulEating: isMindfulEatingHabit,
                              ),
                              onUndoLatest: latestLog == null
                                  ? null
                                  : () => _undoLatest(habit, latestLog),
                              onStreakDetails: () => _showStreakDetails(habit),
                              onDetails: () => _showDetails(habit),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],

                // ── Screen Time Card (Android only) ──
                if (Platform.isAndroid && showPhone)
                  const SliverToBoxAdapter(child: _ScreenTimeSection()),

                // ── Fitness Section ──
                const SliverToBoxAdapter(child: _FitnessSection()),

                // ── Weekly Trend Strip ──
                SliverToBoxAdapter(
                  child: _WeeklyTrendStrip(
                    summaries: weekSummariesAsync.valueOrNull ?? const [],
                    isLoading: weekSummariesAsync.isLoading,
                  ),
                ),

                // ── AI Insight Card ──
                SliverToBoxAdapter(
                  child: _AiInsightCard(
                    onDismiss: _dismissSuggestion,
                  ),
                ),

                // ── Empty State ──
                if (habits.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyStateGlass(
                      onAdd: () => context.push('/habits/new'),
                    ),
                  ),

                // ── Sync footer ──
                SliverToBoxAdapter(
                  child: _SyncFooter(syncedAt: syncedAt),
                ),

                // Bottom padding
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Data helpers (preserved) ──────────────────────────────────────────────

  Map<String, num> _totalsByHabit(List<HabitLog> logs) {
    final totals = <String, num>{};
    for (final log in logs.where((log) => log.logType == 'good')) {
      totals[log.habitId] = (totals[log.habitId] ?? 0) + (log.quantity ?? 1);
    }
    return totals;
  }

  Map<String, num> _slipCountsByHabit(List<HabitLog> logs) {
    final totals = <String, num>{};
    for (final log in logs.where((log) => log.logType == 'slip')) {
      totals[log.habitId] = (totals[log.habitId] ?? 0) + (log.quantity ?? 1);
    }
    return totals;
  }

  Map<String, HabitLog> _latestLogsByHabit(List<HabitLog> logs) {
    final latest = <String, HabitLog>{};
    for (final log in logs) {
      final current = latest[log.habitId];
      if (current == null || log.occurredAt.isAfter(current.occurredAt)) {
        latest[log.habitId] = log;
      }
    }
    return latest;
  }

  Map<String, Streak> _streaksByHabit(List<Streak> streaks) {
    return {
      for (final streak in streaks.where((s) => s.scope == StreakScope.habit))
        streak.habitId: streak,
    };
  }

  DateTime? _latestSyncAt({
    required List<HabitLog> logs,
    required DaySummary? summary,
    required Iterable<Streak> streaks,
  }) {
    DateTime? latest = summary?.computedAt;
    for (final log in logs) {
      if (latest == null || log.loggedAt.isAfter(latest)) latest = log.loggedAt;
    }
    for (final streak in streaks) {
      if (latest == null || streak.updatedAt.isAfter(latest)) {
        latest = streak.updatedAt;
      }
    }
    return latest;
  }

  double _computeMissionPct({
    required DaySummary? summary,
    required List<DaySummary> weekSummaries,
    required List<HabitModel> goodHabits,
    required Map<String, num> totals,
  }) {
    switch (_range) {
      case _TrackerRange.today:
        if (summary != null) return summary.missionPct;
        // Live fallback: compute from habit progress
        if (goodHabits.isEmpty) return 0;
        double sum = 0;
        for (final h in goodHabits) {
          final goal = h.dailyGoal ?? 1;
          final total = totals[h.id] ?? 0;
          sum += (total / goal).clamp(0.0, 1.0);
        }
        return sum / goodHabits.length;
      case _TrackerRange.week:
        if (weekSummaries.isEmpty) return 0;
        final avg = weekSummaries.fold<double>(0, (s, d) => s + d.missionPct) /
            weekSummaries.length;
        return avg.clamp(0.0, 1.0);
      case _TrackerRange.month:
        // For month we use the week summaries provider with 30 days
        // but we only have 7 from the current watch. Fall back to same data.
        if (weekSummaries.isEmpty) return 0;
        final avg = weekSummaries.fold<double>(0, (s, d) => s + d.missionPct) /
            weekSummaries.length;
        return avg.clamp(0.0, 1.0);
    }
  }

  int _countCompleted(List<HabitModel> goodHabits, Map<String, num> totals) {
    int count = 0;
    final daysMultiplier = _range == _TrackerRange.week
        ? 7
        : (_range == _TrackerRange.month ? 30 : 1);
    for (final h in goodHabits) {
      final goal = (h.dailyGoal ?? 1) * daysMultiplier;
      if ((totals[h.id] ?? 0) >= goal) count++;
    }
    return count;
  }

  // ── Actions (preserved) ──────────────────────────────────────────────────

  Future<void> _openLogSheet(
    HabitModel habit, {
    bool isMindfulEating = false,
  }) async {
    if (isMindfulEating) {
      // Route to Mindful Eating sheet: slider + note only, no count/goal/streak.
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => MindfulEatingLogSheet(habit: habit),
      );
    } else if (habit.trackerType == 'junk_food' ||
        habit.trackerType == 'nutrition') {
      // Standard Junk Food sheet: emojis, triggers, cost.
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => JunkFoodLogSheet(habit: habit),
      );
    } else {
      await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => LogHabitSheet(habit: habit),
      );
    }
  }

  Future<void> _undoLatest(HabitModel habit, HabitLog log) async {
    try {
      await ref.read(habitServiceProvider).deleteLog(
            habit.id,
            log.logId,
            confirmDestructive: true,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Latest habit log removed.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to undo latest log: $e'),
            backgroundColor: kCoral,
          ),
        );
      }
    }
  }

  void _showDetails(HabitModel habit) {
    context.push('/habits/${habit.id}');
  }

  void _showStreakDetails(HabitModel habit) {
    context.push('/streaks/${habit.id}');
  }

  Future<void> _dismissSuggestion(String suggestionId) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || suggestionId.isEmpty) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('suggestions')
          .doc(suggestionId)
          .update({
        'status': 'dismissed',
        'dismissedAt': FieldValue.serverTimestamp(),
      });

      await ref.read(eventServiceProvider).emit(
        eventName: EventNames.suggestionDismissed,
        source: 'app',
        payload: {'suggestionId': suggestionId},
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to dismiss insight: $e'),
            backgroundColor: kCoral,
          ),
        );
      }
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// HEADER V2 — date, Today/Week/Month toggle, filter chips
// ═════════════════════════════════════════════════════════════════════════════

class _TrackerHeaderV2 extends StatelessWidget {
  final _TrackerRange range;
  final _TrackerFilter filter;
  final ValueChanged<_TrackerRange> onRangeChanged;
  final ValueChanged<_TrackerFilter> onFilterChanged;
  final VoidCallback onAddHabit;

  const _TrackerHeaderV2({
    required this.range,
    required this.filter,
    required this.onRangeChanged,
    required this.onFilterChanged,
    required this.onAddHabit,
  });

  static const _dayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _monthNames = [
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
    'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Date + Add button ──
          Text(
            '${_dayNames[now.weekday - 1]}, ${_monthNames[now.month - 1]} ${now.day}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: kSub.withValues(alpha: 0.7),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Your Progress',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: kInk,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              Tooltip(
                message: 'Add Habit',
                child: GestureDetector(
                  onTap: onAddHabit,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: kAmber.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: kAmber.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(Icons.add_rounded, color: kInk),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Today / Week / Month toggle ──
          Row(
            children: [
              for (final r in _TrackerRange.values) ...[
                if (r.index > 0) const SizedBox(width: 8),
                _RangeChip(
                  label: r.name[0].toUpperCase() + r.name.substring(1),
                  selected: range == r,
                  onTap: () => onRangeChanged(r),
                ),
              ],
            ],
          ),

          const SizedBox(height: 12),

          // ── Filter chips ──
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                for (final f in _TrackerFilter.values) ...[
                  if (f.index > 0) const SizedBox(width: 8),
                  LiquidChip(
                    label: f.name[0].toUpperCase() + f.name.substring(1),
                    selected: filter == f,
                    accentColor: _filterColor(f),
                    onTap: () => onFilterChanged(f),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _filterColor(_TrackerFilter f) {
    switch (f) {
      case _TrackerFilter.all:
        return kAmber;
      case _TrackerFilter.good:
        return kMint;
      case _TrackerFilter.bad:
        return kCoral;
      case _TrackerFilter.phone:
        return kBlue;
    }
  }
}

class _RangeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? kAmber : kWhite.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? kAmber.withValues(alpha: 0.6)
                : kWhite.withValues(alpha: 0.9),
            width: 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: kAmber.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? kWhite : kInk,
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// MISSION RING SECTION — compact arc ring with score
// ═════════════════════════════════════════════════════════════════════════════

class _MissionRingSection extends StatelessWidget {
  final _TrackerRange range;
  final double missionPct;
  final int habitsCompleted;
  final int totalHabits;

  const _MissionRingSection({
    required this.range,
    required this.missionPct,
    required this.habitsCompleted,
    required this.totalHabits,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (missionPct * 100).round();
    final rangeLabel = range.name[0].toUpperCase() + range.name.substring(1);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: LiquidCard(
        frosted: true,
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: CustomPaint(
                painter: _MissionRingPainter(progress: missionPct),
                child: Center(
                  child: Text(
                    '$pct%',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: kInk,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$rangeLabel Mission',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: kInk,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$habitsCompleted of $totalHabits habits completed',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kSub.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissionRingPainter extends CustomPainter {
  final double progress;
  const _MissionRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;
    const strokeWidth = 6.0;
    const startAngle = -math.pi / 2;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = kAmber.withValues(alpha: 0.12)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        math.pi * 2 * progress.clamp(0.0, 1.0),
        false,
        Paint()
          ..shader = const LinearGradient(
            colors: [kAmber, kMint],
          ).createShader(Rect.fromCircle(center: center, radius: radius))
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_MissionRingPainter old) => old.progress != progress;
}

// ═════════════════════════════════════════════════════════════════════════════
// GOOD HABIT CARD — frosted glass with animated progress bar
// ═════════════════════════════════════════════════════════════════════════════

class _GoodHabitCard extends StatelessWidget {
  final HabitModel habit;
  final Color accent;
  final double progress;
  final num currentValue;
  final num goalValue;
  final int streakCount;
  final VoidCallback onLog;
  final VoidCallback? onUndoLatest;
  final VoidCallback onStreakDetails;
  final VoidCallback onDetails;

  const _GoodHabitCard({
    required this.habit,
    required this.accent,
    required this.progress,
    required this.currentValue,
    required this.goalValue,
    required this.streakCount,
    required this.onLog,
    required this.onUndoLatest,
    required this.onStreakDetails,
    required this.onDetails,
  });

  IconData _iconForTracker(String trackerType) {
    switch (trackerType) {
      case 'water':
        return Icons.water_drop_rounded;
      case 'meditation':
        return Icons.self_improvement_rounded;
      case 'reading':
        return Icons.auto_stories_rounded;
      case 'exercise':
        return Icons.fitness_center_rounded;
      case 'sleep':
        return Icons.bedtime_rounded;
      case 'steps':
        return Icons.directions_walk_rounded;
      case 'nutrition':
        return Icons.restaurant_rounded;
      default:
        return Icons.check_circle_outline_rounded;
    }
  }

  String _streakLabel() {
    if (streakCount <= 0) return 'No streak yet';
    return '$streakCount day streak';
  }

  @override
  Widget build(BuildContext context) {
    final icon = _iconForTracker(habit.trackerType);
    final emoji = habit.emoji;
    final pct = (progress * 100).toInt();
    final isComplete = progress >= 1.0;

    return LiquidCard(
      frosted: true,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Emoji or icon badge
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: emoji != null
                      ? Text(emoji, style: const TextStyle(fontSize: 22))
                      : Icon(icon, color: accent, size: 22),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: kInk,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$currentValue / $goalValue ${habit.unit} · ${_streakLabel()}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: kSub.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              // Percentage badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isComplete
                      ? kMint.withValues(alpha: 0.18)
                      : accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isComplete ? '✓ Done' : '$pct%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isComplete ? kMint : accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Animated progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                // Track
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                // Fill with gradient
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      gradient: LinearGradient(
                        colors: [
                          accent,
                          accent.withValues(alpha: 0.7),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _HabitActionButton(
                  icon: Icons.add_rounded,
                  label: 'Log',
                  color: accent,
                  onTap: onLog,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HabitActionButton(
                  icon: Icons.undo_rounded,
                  label: 'Undo',
                  color: kSub,
                  onTap: onUndoLatest,
                ),
              ),
              const SizedBox(width: 8),
              _IconActionButton(
                icon: Icons.local_fire_department_rounded,
                color: kAmber,
                tooltip: 'Streak details',
                onTap: onStreakDetails,
              ),
              const SizedBox(width: 8),
              _IconActionButton(
                icon: Icons.info_outline_rounded,
                color: accent,
                tooltip: 'Habit details',
                onTap: onDetails,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// BAD HABIT CARD — carousel card with slip counter and Log Slip CTA
// ═════════════════════════════════════════════════════════════════════════════

class _BadHabitCard extends StatelessWidget {
  final HabitModel habit;
  final Color accent;
  final num slipCount;
  final int streakCount;
  final bool isMindfulEating;
  final VoidCallback onLog;
  final VoidCallback? onUndoLatest;
  final VoidCallback onStreakDetails;
  final VoidCallback onDetails;

  const _BadHabitCard({
    required this.habit,
    required this.accent,
    required this.slipCount,
    required this.streakCount,
    this.isMindfulEating = false,
    required this.onLog,
    required this.onUndoLatest,
    required this.onStreakDetails,
    required this.onDetails,
  });

  String _goalLabel(BadHabitGoalType? type) {
    if (isMindfulEating) return 'Mindful eating mode';
    final streak =
        streakCount <= 0 ? 'No streak yet' : '$streakCount day streak';
    switch (type) {
      case BadHabitGoalType.eliminate:
        return 'Goal: Zero today · $streak';
      case BadHabitGoalType.reduceToTarget:
        return 'Goal: Under ${habit.target ?? "?"}/day · $streak';
      default:
        return 'Tracking awareness · $streak';
    }
  }

  @override
  Widget build(BuildContext context) {
    final emoji = habit.emoji;
    final isOver =
        habit.goalType == BadHabitGoalType.eliminate && slipCount > 0;
    final isOverTarget = habit.goalType == BadHabitGoalType.reduceToTarget &&
        habit.target != null &&
        slipCount >= (habit.target ?? 0);

    return SizedBox(
      width: 218,
      child: LiquidCard(
        frosted: true,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon / Emoji
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: emoji != null
                    ? Text(emoji, style: const TextStyle(fontSize: 24))
                    : Icon(Icons.block_rounded, color: accent, size: 24),
              ),
            ),
            const SizedBox(height: 12),

            // Name
            Text(
              habit.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: kInk,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),

            // Goal label
            Text(
              _goalLabel(habit.goalType),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: kSub.withValues(alpha: 0.7),
              ),
            ),

            const Spacer(),

            // Slip counter (Hidden if mindful eating)
            if (!isMindfulEating) ...[
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isOver || isOverTarget)
                          ? kCoral.withValues(alpha: 0.18)
                          : kMint.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          (isOver || isOverTarget)
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle_outline_rounded,
                          size: 14,
                          color: (isOver || isOverTarget) ? kCoral : kMint,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${slipCount.round()} slip${slipCount == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: (isOver || isOverTarget) ? kCoral : kMint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],

            Row(
              children: [
                Expanded(
                  child: _HabitActionButton(
                    icon: isMindfulEating
                        ? Icons.restaurant_menu_rounded
                        : Icons.add_alert_rounded,
                    label: isMindfulEating ? 'Check-in' : 'Log',
                    color: accent,
                    onTap: onLog,
                  ),
                ),
                const SizedBox(width: 8),
                _IconActionButton(
                  icon: Icons.undo_rounded,
                  color: kSub,
                  tooltip: 'Undo latest',
                  onTap: onUndoLatest,
                ),
                if (!isMindfulEating) ...[
                  const SizedBox(width: 8),
                  _IconActionButton(
                    icon: Icons.local_fire_department_rounded,
                    color: kAmber,
                    tooltip: 'Streak details',
                    onTap: onStreakDetails,
                  ),
                ],
                const SizedBox(width: 8),
                _IconActionButton(
                  icon: Icons.info_outline_rounded,
                  color: accent,
                  tooltip: 'Habit details',
                  onTap: onDetails,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _HabitActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled ? 1 : 0.42,
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;

  const _IconActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: enabled ? 1 : 0.42,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;

  const _InlineError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Text(
        message,
        style: const TextStyle(
          color: kCoral,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// EMPTY STATE — glass card with CTA
// ═════════════════════════════════════════════════════════════════════════════

class _EmptyStateGlass extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyStateGlass({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: LiquidCard(
          frosted: true,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
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
                  Icons.track_changes_rounded,
                  size: 40,
                  color: kAmber.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'No habits yet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: kInk,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add your first habit to start tracking your progress and building better routines.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: kSub.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              LiquidButton(
                label: 'Add Habit',
                leading: const Icon(Icons.add_rounded, color: kWhite, size: 20),
                onTap: onAdd,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SCREEN TIME SECTION
// Renders as:
//   • Permission-prompt card  — when usage access is not yet granted
//   • Shimmer placeholder     — while Riverpod loads the Firestore stream
//   • Full data card          — totalMinutes ring + unlocks + top-apps list
// ═════════════════════════════════════════════════════════════════════════════

class _ScreenTimeSection extends ConsumerStatefulWidget {
  const _ScreenTimeSection();

  @override
  ConsumerState<_ScreenTimeSection> createState() => _ScreenTimeSectionState();
}

class _ScreenTimeSectionState extends ConsumerState<_ScreenTimeSection>
    with WidgetsBindingObserver {
  bool _hasPerm = false;
  bool _permChecked = false;
  bool _syncing = false;
  bool _openedUsageSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _openedUsageSettings) {
      _openedUsageSettings = false;
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    final importer = ref.read(screenTimeImporterProvider);
    final granted = await importer.hasPermission();
    if (mounted) {
      setState(() {
        _hasPerm = granted;
        _permChecked = true;
      });
      // Auto-sync on first foreground if already permitted
      if (granted) _runSync();
    }
  }

  Future<void> _runSync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      await ref.read(screenTimeImporterProvider).sync();
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _requestPermission() async {
    _openedUsageSettings = true;
    await ref.read(screenTimeImporterProvider).requestPermission();
  }

  @override
  Widget build(BuildContext context) {
    if (!_permChecked) return const _ScreenTimeShimmer();

    if (!_hasPerm) {
      return _ScreenTimePermissionCard(onGrant: _requestPermission);
    }

    final logAsync = ref.watch(screenTimeLogProvider);
    return logAsync.when(
      loading: () => const _ScreenTimeShimmer(),
      error: (_, __) => const SizedBox.shrink(),
      data: (log) => _ScreenTimeDataCard(
        log: log,
        syncing: _syncing,
        onSync: _runSync,
      ),
    );
  }
}

// ── Permission prompt card ────────────────────────────────────────────────────

class _ScreenTimePermissionCard extends StatelessWidget {
  final VoidCallback onGrant;
  const _ScreenTimePermissionCard({required this.onGrant});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: LiquidCard(
        frosted: true,
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: kAmber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.phone_android_rounded,
                color: kAmber,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enable Screen Time',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: kInk,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Grant usage access to see your daily screen habits.',
                    style: TextStyle(
                      fontSize: 12,
                      color: kSub.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onGrant();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: kAmber.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Grant',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: kAmber,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shimmer placeholder card ──────────────────────────────────────────────────

class _ScreenTimeShimmer extends StatelessWidget {
  const _ScreenTimeShimmer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: LiquidCard(
        frosted: true,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _shimmerBox(120, 16),
            const SizedBox(height: 14),
            _shimmerBox(80, 40),
            const SizedBox(height: 16),
            _shimmerBox(double.infinity, 10),
            const SizedBox(height: 8),
            _shimmerBox(double.infinity, 10),
          ],
        ),
      ),
    );
  }

  Widget _shimmerBox(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: kSub.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

// ── Full data card ────────────────────────────────────────────────────────────

class _ScreenTimeDataCard extends StatelessWidget {
  final ScreenTimeLogModel? log;
  final bool syncing;
  final VoidCallback onSync;

  const _ScreenTimeDataCard({
    required this.log,
    required this.syncing,
    required this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: LiquidCard(
        frosted: true,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section label + sync button ──
            Row(
              children: [
                const Text(
                  'Screen Time',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kSub,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: syncing
                      ? null
                      : () {
                          HapticFeedback.lightImpact();
                          onSync();
                        },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: kBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (syncing)
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: kBlue,
                            ),
                          )
                        else
                          const Icon(Icons.sync_rounded,
                              size: 13, color: kBlue),
                        const SizedBox(width: 5),
                        Text(
                          syncing ? 'Syncing…' : 'Sync Now',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: kBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            if (log == null)
              // No sync yet
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Tap Sync Now to load today\'s data',
                    style: TextStyle(
                      fontSize: 13,
                      color: kSub.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              )
            else ...[
              // ── Total + Unlocks row ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Arc ring
                  _ScreenTimeRing(minutes: log!.totalMinutes),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          log!.formattedTotal,
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: kInk,
                            letterSpacing: -1,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'total screen time',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: kSub.withValues(alpha: 0.65),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.lock_open_rounded,
                                size: 14, color: kPurple),
                            const SizedBox(width: 5),
                            Text(
                              '${log!.unlockCount} unlocks',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: kPurple,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // ── Top Apps ──
              if (log!.topApps.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Divider(height: 1, color: Color(0x14000000)),
                const SizedBox(height: 14),
                const Text(
                  'Top Apps',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kSub,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 10),
                ...log!.topApps
                    .take(3)
                    .toList()
                    .asMap()
                    .entries
                    .map((entry) => _AppUsageRow(
                          app: entry.value,
                          maxMinutes: log!.topApps.first.minutes,
                          index: entry.key,
                        )),
              ],

              // ── Captured-at footnote ──
              const SizedBox(height: 12),
              Text(
                'Last synced ${_formatCapturedAt(log!.capturedAt)}',
                style: TextStyle(
                  fontSize: 11,
                  color: kSub.withValues(alpha: 0.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatCapturedAt(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ── Arc ring widget ───────────────────────────────────────────────────────────

class _ScreenTimeRing extends StatelessWidget {
  final int minutes;
  const _ScreenTimeRing({required this.minutes});

  @override
  Widget build(BuildContext context) {
    // Ring fills based on 480 min (8 h) as the "full" reference
    final progress = (minutes / 480).clamp(0.0, 1.0);
    return SizedBox(
      width: 72,
      height: 72,
      child: CustomPaint(
        painter: _RingPainter(progress: progress),
        child: Center(
          child: Icon(
            Icons.phone_android_rounded,
            size: 24,
            color: kBlue.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  const _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    const strokeWidth = 7.0;
    const startAngle = -1.5708; // -π/2 (12 o'clock)

    // Track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      6.2832,
      false,
      Paint()
        ..color = kBlue.withValues(alpha: 0.12)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Fill
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        6.2832 * progress,
        false,
        Paint()
          ..shader = const LinearGradient(
            colors: [kBlue, kPurple],
          ).createShader(Rect.fromCircle(center: center, radius: radius))
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

// ── App usage row ─────────────────────────────────────────────────────────────

class _AppUsageRow extends StatelessWidget {
  final AppUsage app;
  final int maxMinutes;
  final int index;

  const _AppUsageRow({
    required this.app,
    required this.maxMinutes,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final colors = [kBlue, kPurple, kMint];
    final color = colors[index % colors.length];
    final barWidth =
        maxMinutes > 0 ? (app.minutes / maxMinutes).clamp(0.0, 1.0) : 0.0;
    final h = app.minutes ~/ 60;
    final m = app.minutes % 60;
    final label = h > 0 ? '${h}h ${m}m' : '${m}m';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  app.appName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: kInk,
                  ),
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: kSub.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(
                  height: 6,
                  color: color.withValues(alpha: 0.12),
                ),
                FractionallySizedBox(
                  widthFactor: barWidth,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: LinearGradient(
                        colors: [color, color.withValues(alpha: 0.6)],
                      ),
                    ),
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

// ═════════════════════════════════════════════════════════════════════════════
// FITNESS SECTION — entry point for the Fitness Engine inside Tracker tab
// ═════════════════════════════════════════════════════════════════════════════

class _FitnessSection extends ConsumerWidget {
  const _FitnessSection();

  static const _quickTypes = [
    FitnessActivityType.running,
    FitnessActivityType.walking,
    FitnessActivityType.cycling,
    FitnessActivityType.hiking,
    FitnessActivityType.gymWorkout,
    FitnessActivityType.swimming,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(activityHistoryProvider);
    final lastActivity = historyAsync.valueOrNull?.isNotEmpty == true
        ? historyAsync.valueOrNull!.first
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: LiquidCard(
        frosted: true,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title row ──
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: kMint.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.directions_run_rounded,
                    color: kMint,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Fitness Tracking',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: kInk,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    context.push('/fitness');
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: kMint.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Dashboard',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: kMint,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Last activity summary or empty state ──
            if (lastActivity != null) ...[
              _FitnessLastActivityRow(activity: lastActivity),
              const SizedBox(height: 14),
            ] else
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(
                  'No activities yet. Start your first workout!',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: kSub.withValues(alpha: 0.6),
                  ),
                ),
              ),

            // ── Quick start grid ──
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in _quickTypes)
                  _FitnessQuickStartChip(type: type),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FitnessQuickStartChip extends StatelessWidget {
  final FitnessActivityType type;

  const _FitnessQuickStartChip({required this.type});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push('/fitness/pre-start?type=${type.toJson()}');
      },
      child: Container(
        width: 94,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: kMint.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kMint.withValues(alpha: 0.18)),
        ),
        child: Center(
          child: Text(
            '${type.emoji} ${type.displayName}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: kInk,
            ),
          ),
        ),
      ),
    );
  }
}

class _FitnessLastActivityRow extends StatelessWidget {
  final FitnessActivityModel activity;
  const _FitnessLastActivityRow({required this.activity});

  @override
  Widget build(BuildContext context) {
    final duration = activity.activeDuration;
    final m = duration.inMinutes;
    final s = duration.inSeconds % 60;
    final durationStr = m > 0 ? '${m}m' : '${s}s';

    return Row(
      children: [
        Text(
          activity.activityType.emoji,
          style: const TextStyle(fontSize: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Last: ${activity.title.isNotEmpty ? activity.title : activity.activityType.displayName}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kInk,
                ),
              ),
              Text(
                durationStr,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: kSub.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// WEEKLY TREND STRIP — 7-day bars from dailySummaries
// ═════════════════════════════════════════════════════════════════════════════

class _WeeklyTrendStrip extends StatelessWidget {
  final List<DaySummary> summaries;
  final bool isLoading;

  const _WeeklyTrendStrip({
    required this.summaries,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && summaries.isEmpty) return const SizedBox.shrink();

    // Build 7-day data keyed by weekday (1=Mon … 7=Sun)
    final today = DateTime.now();
    final dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final values = List<double>.filled(7, 0);

    for (final s in summaries) {
      final dt = DateTime.tryParse(s.date);
      if (dt == null) continue;
      final diff = today.difference(dt).inDays;
      if (diff >= 0 && diff < 7) {
        // Map into 7-slot array: index 0 = 6 days ago, index 6 = today
        values[6 - diff] = s.missionPct.clamp(0, 1);
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: LiquidCard(
        frosted: true,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Weekly Trend',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: kInk,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 60,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (i) {
                  final isToday = i == 6;
                  final h = (values[i] * 48).clamp(4.0, 48.0);
                  // Compute the day label index from the actual calendar
                  final dayDate = today.subtract(Duration(days: 6 - i));
                  final labelIdx = (dayDate.weekday - 1) % 7;

                  return Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: h,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: isToday
                                  ? [kAmber, kMint]
                                  : [
                                      kAmber.withValues(alpha: 0.3),
                                      kMint.withValues(alpha: 0.3),
                                    ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          dayLabels[labelIdx],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                isToday ? FontWeight.w800 : FontWeight.w600,
                            color: isToday ? kInk : kSub.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// AI INSIGHT CARD — reads pending tracker suggestions
// ═════════════════════════════════════════════════════════════════════════════

class _AiInsightCard extends ConsumerWidget {
  final Future<void> Function(String suggestionId) onDismiss;

  const _AiInsightCard({required this.onDismiss});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestionsAsync = ref.watch(trackerSuggestionsProvider);

    return suggestionsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (suggestions) {
        if (suggestions.isEmpty) return const SizedBox.shrink();

        final suggestion = suggestions.first;
        final id = suggestion.suggestionId;
        final title =
            suggestion.title.isEmpty ? 'AI Insight' : suggestion.title;
        final body = suggestion.body;
        final reason = suggestion.reason.isEmpty ? null : suggestion.reason;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: LiquidCard(
            frosted: true,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: kPurple.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        size: 18,
                        color: kPurple.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: kInk,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => onDismiss(id),
                      child: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: kSub.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    body,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: kInk.withValues(alpha: 0.7),
                      height: 1.5,
                    ),
                  ),
                ],
                if (reason != null && reason.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    reason,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kPurple.withValues(alpha: 0.65),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SHIMMER LOADING SKELETON
// ═════════════════════════════════════════════════════════════════════════════

class _TrackerShimmer extends StatelessWidget {
  const _TrackerShimmer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fake date line
          _shimmerBox(120, 14),
          const SizedBox(height: 10),
          // Fake title
          _shimmerBox(200, 28),
          const SizedBox(height: 20),
          // Fake range chips
          Row(
            children: [
              _shimmerBox(60, 32),
              const SizedBox(width: 8),
              _shimmerBox(60, 32),
              const SizedBox(width: 8),
              _shimmerBox(60, 32),
            ],
          ),
          const SizedBox(height: 16),
          // Fake mission ring card
          _shimmerBox(double.infinity, 100),
          const SizedBox(height: 16),
          // Fake habit cards
          _shimmerBox(double.infinity, 80),
          const SizedBox(height: 12),
          _shimmerBox(double.infinity, 80),
          const SizedBox(height: 12),
          _shimmerBox(double.infinity, 80),
        ],
      ),
    );
  }

  Widget _shimmerBox(double width, double height) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: kWhite.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SYNC FOOTER — "Synced X min ago"
// ═════════════════════════════════════════════════════════════════════════════

class _SyncFooter extends StatelessWidget {
  final DateTime? syncedAt;
  const _SyncFooter({this.syncedAt});

  @override
  Widget build(BuildContext context) {
    String label;
    if (syncedAt != null) {
      final diff = DateTime.now().difference(syncedAt!);
      if (diff.inMinutes < 1) {
        label = 'Synced just now';
      } else if (diff.inMinutes < 60) {
        label = 'Synced ${diff.inMinutes}m ago';
      } else {
        label = 'Synced ${diff.inHours}h ago';
      }
    } else {
      label = 'Live';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: kSub.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}
