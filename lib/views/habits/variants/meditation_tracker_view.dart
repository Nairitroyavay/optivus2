// lib/views/habits/variants/meditation_tracker_view.dart
//
// Meditation tracker dashboard per UF §8.4.
// Features: hero card (today minutes + streak), start-session CTA,
// lifetime stats + milestone badges, type breakdown chart,
// last-session meditation lift, 7-day history.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/models/habit_log_model.dart';
import 'package:optivus2/models/habit_model.dart';
import 'package:optivus2/views/habits/variants/meditation_timer_screen.dart';

/// Milestone thresholds in hours.
const _kMilestones = [10, 50, 100, 365];
const _kMilestoneEmoji = ['🌱', '🌿', '🌳', '🏔️'];
const _kMilestoneLabel = ['10h', '50h', '100h', '365h'];

class MeditationTrackerView extends ConsumerStatefulWidget {
  final HabitModel habit;

  const MeditationTrackerView({super.key, required this.habit});

  @override
  ConsumerState<MeditationTrackerView> createState() =>
      _MeditationTrackerViewState();
}

class _MeditationTrackerViewState
    extends ConsumerState<MeditationTrackerView> {
  Map<String, dynamic>? _lastSessionResult;

  Future<void> _openTimer() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      slideRoute(MeditationTimerScreen(
        habitId: widget.habit.id,
        habitName: widget.habit.name,
      )),
    );
    if (result != null && mounted) {
      setState(() => _lastSessionResult = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Not authenticated.'));
    }

    final todayLogsAsync = ref.watch(todayHabitLogsProvider);
    final streakAsync = ref.watch(streakByIdProvider(widget.habit.id));
    final weekLogsAsync = ref.watch(habitLogsForRangeProvider((
      habitId: widget.habit.id,
      days: 7,
    )));

    // For lifetime stats, we'll use a local stream provider or just watch a larger range
    // but the existing habitLogsForRangeProvider works well for the history chart.
    // For breakdown and lifetime, we might want more. Let's use 30 days for now or 
    // keep it simple with the available providers.
    final allLogsAsync = ref.watch(habitLogsForRangeProvider((
      habitId: widget.habit.id,
      days: 90, // reasonable window for breakdown
    )));

    return todayLogsAsync.when(
      loading: () => const _Loading(),
      error: (e, __) => _Error(message: e.toString()),
      data: (todayLogs) => streakAsync.when(
        loading: () => const _Loading(),
        error: (e, __) => _Error(message: e.toString()),
        data: (streak) => weekLogsAsync.when(
          loading: () => const _Loading(),
          error: (e, __) => _Error(message: e.toString()),
          data: (weekLogs) => allLogsAsync.when(
            loading: () => const _Loading(),
            error: (e, __) => _Error(message: e.toString()),
            data: (allLogs) {
              // Today's minutes
              final todayMin = todayLogs
                  .where((l) => l.habitId == widget.habit.id)
                  .fold<num>(0, (s, l) => s + (l.quantity ?? 0));

              // Lifetime stats (approximated from the watched range in this view)
              final totalMin =
                  allLogs.fold<num>(0, (s, l) => s + (l.quantity ?? 0));
              final totalHours = totalMin / 60;
              final sessionCount = allLogs.length;

              // Type breakdown
              final typeMap = _buildTypeBreakdown(allLogs);

              // Last session lift
              final lastLift = _extractLastLift(allLogs);

              // 7-day points
              final points = _buildWeeklyPoints(weekLogs);

              return SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeroCard(
                      todayMin: todayMin,
                      streakDays: streak?.currentCount ?? 0,
                    ),
                    const SizedBox(height: 16),
                    _StartButton(onTap: _openTimer),
                    const SizedBox(height: 20),
                    _LifetimeCard(
                      totalHours: totalHours,
                      sessions: sessionCount,
                    ),
                    const SizedBox(height: 16),
                    _MilestoneRow(totalHours: totalHours),
                    const SizedBox(height: 20),
                    if (typeMap.isNotEmpty) ...[
                      _TypeBreakdownCard(typeMap: typeMap),
                      const SizedBox(height: 20),
                    ],
                    if (lastLift != null || _lastSessionResult != null) ...[
                      _LiftCard(
                        lift: _lastSessionResult != null
                            ? (_lastSessionResult!['moodAfter'] as int) -
                                (_lastSessionResult!['moodBefore'] as int)
                            : lastLift!,
                      ),
                      const SizedBox(height: 20),
                    ],
                    _HistoryCard(points: points),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Map<String, int> _buildTypeBreakdown(List<HabitLog> logs) {
    final map = <String, int>{};
    for (final log in logs) {
      final type = log.type ?? 'Unguided';
      map[type] = (map[type] ?? 0) + (log.quantity ?? 1).round();
    }
    return map;
  }

  int? _extractLastLift(List<HabitLog> logs) {
    final sorted = List<HabitLog>.from(logs)
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    for (final log in sorted) {
      final before = log.moodBefore;
      final after = log.moodAfter;
      if (before != null && after != null) return after - before;
    }
    return null;
  }

  Map<String, num> _buildWeeklyPoints(List<HabitLog> logs) {
    final now = DateTime.now();
    final points = <String, num>{
      for (var i = 6; i >= 0; i--)
        _dateStr(now.subtract(Duration(days: i))): 0,
    };
    for (final log in logs) {
      final key = _dateStr(log.occurredAt);
      if (points.containsKey(key)) {
        points[key] = (points[key] ?? 0) + (log.quantity ?? 1);
      }
    }
    return points;
  }

  static String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

// ═══════════════════════════════════════════════════════════════════════════════
// HERO CARD — today's minutes + streak
// ═══════════════════════════════════════════════════════════════════════════════

class _HeroCard extends StatelessWidget {
  final num todayMin;
  final int streakDays;

  const _HeroCard({required this.todayMin, required this.streakDays});

  @override
  Widget build(BuildContext context) {
    return LiquidCard(
      radius: 28,
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: kPurple.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.self_improvement_rounded,
                color: kPurple, size: 30),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Meditation',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: kInk,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Today\'s minutes',
                  style: TextStyle(
                    color: kSub.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${todayMin.round()} min',
                style: const TextStyle(
                  color: kPurple,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '$streakDays day streak',
                style: TextStyle(
                  color: kSub.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// START BUTTON
// ═══════════════════════════════════════════════════════════════════════════════

class _StartButton extends StatelessWidget {
  final VoidCallback onTap;

  const _StartButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return LiquidButton(
      label: 'Start Meditation',
      color: kPurple,
      leading: const Icon(Icons.play_arrow_rounded, color: kWhite),
      onTap: onTap,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// LIFETIME STATS
// ═══════════════════════════════════════════════════════════════════════════════

class _LifetimeCard extends StatelessWidget {
  final double totalHours;
  final int sessions;

  const _LifetimeCard({required this.totalHours, required this.sessions});

  @override
  Widget build(BuildContext context) {
    return LiquidCard(
      child: Row(
        children: [
          Expanded(
            child: _StatColumn(
              label: 'Total Hours',
              value: totalHours.toStringAsFixed(1),
              icon: Icons.hourglass_top_rounded,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: kSub.withValues(alpha: 0.12),
          ),
          Expanded(
            child: _StatColumn(
              label: 'Sessions',
              value: sessions.toString(),
              icon: Icons.self_improvement_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatColumn({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: kPurple, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: kInk,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: kSub.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MILESTONE BADGES
// ═══════════════════════════════════════════════════════════════════════════════

class _MilestoneRow extends StatelessWidget {
  final double totalHours;

  const _MilestoneRow({required this.totalHours});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(_kMilestones.length, (i) {
        final earned = totalHours >= _kMilestones[i];
        return Column(
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: earned ? 1 : 0.3,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: earned
                      ? kPurple.withValues(alpha: 0.14)
                      : kSub.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: earned
                        ? kPurple.withValues(alpha: 0.3)
                        : kSub.withValues(alpha: 0.1),
                  ),
                ),
                child: Center(
                  child: Text(
                    _kMilestoneEmoji[i],
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _kMilestoneLabel[i],
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: earned ? kPurple : kSub.withValues(alpha: 0.5),
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TYPE BREAKDOWN CHART
// ═══════════════════════════════════════════════════════════════════════════════

class _TypeBreakdownCard extends StatelessWidget {
  final Map<String, int> typeMap;

  const _TypeBreakdownCard({required this.typeMap});

  @override
  Widget build(BuildContext context) {
    final sorted = typeMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxVal = sorted.first.value;
    final colors = [kPurple, kBlue, kMint, kAmber, kCoral, kRose];

    return LiquidCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Type Breakdown',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: kInk,
            ),
          ),
          const SizedBox(height: 14),
          ...sorted.asMap().entries.map((entry) {
            final i = entry.key;
            final e = entry.value;
            final pct = maxVal > 0 ? (e.value / maxVal) : 0.0;
            final color = colors[i % colors.length];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: Text(
                      e.key,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: kInk,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Stack(
                        children: [
                          Container(
                            height: 14,
                            color: color.withValues(alpha: 0.1),
                          ),
                          FractionallySizedBox(
                            widthFactor: pct.clamp(0.05, 1.0),
                            child: Container(
                              height: 14,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 42,
                    child: Text(
                      '${e.value}m',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: kSub.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MEDITATION LIFT CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _LiftCard extends StatelessWidget {
  final int lift;

  const _LiftCard({required this.lift});

  @override
  Widget build(BuildContext context) {
    final color = lift > 0 ? kMint : lift < 0 ? kCoral : kAmber;
    final emoji = lift > 0 ? '🌟' : lift < 0 ? '🌧' : '☀️';
    final label = lift > 0 ? '+$lift' : '$lift';

    return LiquidCard(
      tint: color.withValues(alpha: 0.06),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Last Session Lift',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: kInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your mood shifted $label points',
                  style: TextStyle(
                    fontSize: 13,
                    color: kSub.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 7-DAY HISTORY
// ═══════════════════════════════════════════════════════════════════════════════

class _HistoryCard extends StatelessWidget {
  final Map<String, num> points;

  const _HistoryCard({required this.points});

  @override
  Widget build(BuildContext context) {
    final maxVal = points.values.fold<num>(0, (m, v) => v > m ? v : m);
    final hasData = maxVal > 0;
    final entries = points.entries.toList();

    return LiquidCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '7-day history',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: kInk,
            ),
          ),
          const SizedBox(height: 14),
          if (!hasData)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  'No meditation sessions logged this week.',
                  style: TextStyle(
                    color: kSub.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 86,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: entries.map((e) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor:
                                    (e.value / maxVal).clamp(0.08, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: kPurple.withValues(alpha: 0.72),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            e.key.substring(8),
                            style: TextStyle(
                              color: kSub.withValues(alpha: 0.72),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// LOADING / ERROR
// ═══════════════════════════════════════════════════════════════════════════════

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 200,
      child: Center(child: CircularProgressIndicator(color: kPurple)),
    );
  }
}

class _Error extends StatelessWidget {
  final String message;
  const _Error({required this.message});
  @override
  Widget build(BuildContext context) {
    return LiquidCard(
      child: Text('Error: $message', style: const TextStyle(color: kCoral)),
    );
  }
}
