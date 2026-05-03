import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/models/habit_log_model.dart';
import 'package:optivus2/models/habit_model.dart';
import 'package:optivus2/models/screen_time_log_model.dart';
import 'package:optivus2/views/habits/log_habit_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Accent colour pool for habit cards — cycles through vibrant LiquidGlass tones
// ─────────────────────────────────────────────────────────────────────────────
const _kGoodAccents = [kMint, kBlue, kPurple, kAmber, kCoral];
const _kBadAccents = [kCoral, kRose, Color(0xFFFF5C93), kPurple];

class TrackerTab extends ConsumerStatefulWidget {
  const TrackerTab({super.key});

  @override
  ConsumerState<TrackerTab> createState() => _TrackerTabState();
}

class _TrackerTabState extends ConsumerState<TrackerTab> {
  @override
  Widget build(BuildContext context) {
    final habitsAsync = ref.watch(habitsProvider);
    final logsAsync = ref.watch(todayHabitLogsProvider);
    final logs = logsAsync.valueOrNull ?? const <HabitLog>[];
    final totals = _totalsByHabit(logs);
    final slipCounts = _slipCountsByHabit(logs);
    final latestLogs = _latestLogsByHabit(logs);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: habitsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: kAmber),
          ),
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
            final goodHabits =
                habits.where((h) => h.kind == HabitKind.good).toList();
            final badHabits =
                habits.where((h) => h.kind == HabitKind.bad).toList();

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── Header ──
                SliverToBoxAdapter(
                  child: _TrackerHeader(
                    onAddHabit: () => context.push('/habits/new'),
                  ),
                ),

                // ── Screen Time Card (Android only) ──
                if (Platform.isAndroid)
                  SliverToBoxAdapter(
                    child: _ScreenTimeSection(),
                  ),

                // ── Good Habits Section ──
                if (goodHabits.isNotEmpty) ...[
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
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final habit = goodHabits[index];
                          final accent =
                              _kGoodAccents[index % _kGoodAccents.length];
                          final total = totals[habit.id] ?? 0;
                          final goal = habit.dailyGoal ?? 1;
                          final progress =
                              (total / goal).clamp(0.0, 1.0).toDouble();
                          final latestLog = latestLogs[habit.id];

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _GoodHabitCard(
                              habit: habit,
                              accent: accent,
                              progress: progress,
                              currentValue: total,
                              goalValue: goal,
                              onLog: () => _openLogSheet(habit),
                              onUndoLatest: latestLog == null
                                  ? null
                                  : () => _undoLatest(habit, latestLog),
                              onStreakDetails: () => _showStreakDetails(habit),
                              onDetails: () => _showDetails(
                                habit,
                              ),
                            ),
                          );
                        },
                        childCount: goodHabits.length,
                      ),
                    ),
                  ),
                ],

                // ── Bad Habits Section ──
                if (badHabits.isNotEmpty) ...[
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

                          return Padding(
                            padding: const EdgeInsets.only(right: 14),
                            child: _BadHabitCard(
                              habit: habit,
                              accent: accent,
                              slipCount: slips,
                              onLog: () => _openLogSheet(habit),
                              onUndoLatest: latestLog == null
                                  ? null
                                  : () => _undoLatest(habit, latestLog),
                              onStreakDetails: () => _showStreakDetails(habit),
                              onDetails: () => _showDetails(
                                habit,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],

                // ── Empty State ──
                if (habits.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(),
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

  Future<void> _openLogSheet(HabitModel habit) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LogHabitSheet(habit: habit),
    );
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
}

// ═════════════════════════════════════════════════════════════════════════════
// HEADER
// ═════════════════════════════════════════════════════════════════════════════

class _TrackerHeader extends StatelessWidget {
  final VoidCallback onAddHabit;

  const _TrackerHeader({required this.onAddHabit});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final monthNames = [
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${dayNames[now.weekday - 1]}, ${monthNames[now.month - 1]} ${now.day}',
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
        ],
      ),
    );
  }
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
                      '$currentValue / $goalValue ${habit.unit}',
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
  final VoidCallback onLog;
  final VoidCallback? onUndoLatest;
  final VoidCallback onStreakDetails;
  final VoidCallback onDetails;

  const _BadHabitCard({
    required this.habit,
    required this.accent,
    required this.slipCount,
    required this.onLog,
    required this.onUndoLatest,
    required this.onStreakDetails,
    required this.onDetails,
  });

  String _goalLabel(BadHabitGoalType? type) {
    switch (type) {
      case BadHabitGoalType.eliminate:
        return 'Goal: Zero today';
      case BadHabitGoalType.reduceToTarget:
        return 'Goal: Under ${habit.target ?? "?"}/day';
      default:
        return 'Tracking awareness';
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

            // Slip counter
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

            Row(
              children: [
                Expanded(
                  child: _HabitActionButton(
                    icon: Icons.add_alert_rounded,
                    label: 'Log',
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
// EMPTY STATE
// ═════════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
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
          ],
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
