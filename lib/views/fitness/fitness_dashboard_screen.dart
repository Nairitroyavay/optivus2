// lib/views/fitness/fitness_dashboard_screen.dart
//
// Fitness dashboard — recent activities, quick stats, and Start Activity CTA.
// Uses the Liquid Glass design system.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/models/fitness_activity_model.dart';

class FitnessDashboardScreen extends ConsumerWidget {
  const FitnessDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(activityHistoryProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidBg(
        colors: const [Color(0xFF78FDFF), Color(0xFFE8FEFE)],
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Header ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          LiquidIconBtn(
                            icon: Icons.arrow_back_rounded,
                            onTap: () => context.pop(),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Text(
                              'Fitness',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: kInk,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Track your workouts and stay active',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: kSub.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Start Activity CTA ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: LiquidButton(
                    label: 'Start Activity',
                    leading: const Icon(Icons.play_arrow_rounded,
                        color: kWhite, size: 22),
                    onTap: () => context.push('/fitness/select'),
                  ),
                ),
              ),

              // ── Quick Start Row ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: _QuickStartRow(
                    onSelect: (type) => context.push(
                      '/fitness/pre-start?type=${type.toJson()}',
                    ),
                  ),
                ),
              ),

              // ── Navigation Row (Stats · Goals · Settings) ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Row(
                    children: [
                      _NavPill(
                        icon: Icons.bar_chart_rounded,
                        label: 'Stats',
                        onTap: () => context.push('/fitness/stats'),
                      ),
                      const SizedBox(width: 8),
                      _NavPill(
                        icon: Icons.flag_rounded,
                        label: 'Goals',
                        onTap: () => context.push('/fitness/goals'),
                      ),
                      const SizedBox(width: 8),
                      _NavPill(
                        icon: Icons.settings_rounded,
                        label: 'Settings',
                        onTap: () => context.push('/fitness/settings'),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Today's Stats Summary ──
              SliverToBoxAdapter(
                child: _TodayStatsSummary(),
              ),

              // ── Activity History ──
              SliverToBoxAdapter(
                child: LiquidSectionHeader(
                  title: 'Recent Activities',
                  actionLabel: 'History',
                  onAction: () => context.push('/fitness/history'),
                ),
              ),
              historyAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 4, 20, 14),
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      color: kAmber,
                    ),
                  ),
                ),
                error: (err, _) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                    child: Text(
                      'Failed to load activities: $err',
                      style: const TextStyle(
                        color: kCoral,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                data: (activities) {
                  if (activities.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: _EmptyHistoryCard(),
                    );
                  }
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: GestureDetector(
                          onTap: () => context.push(
                            '/fitness/activity/${activities[index].activityId}',
                          ),
                          child: _ActivityHistoryCard(
                            activity: activities[index],
                          ),
                        ),
                      ),
                      childCount: activities.length,
                    ),
                  );
                },
              ),

              // ── Bottom padding ──
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick Start Row — horizontal pills for common activity types
// ─────────────────────────────────────────────────────────────────────────────

class _QuickStartRow extends StatelessWidget {
  final ValueChanged<FitnessActivityType> onSelect;

  const _QuickStartRow({required this.onSelect});

  static const _types = [
    FitnessActivityType.running,
    FitnessActivityType.walking,
    FitnessActivityType.cycling,
    FitnessActivityType.hiking,
    FitnessActivityType.gymWorkout,
    FitnessActivityType.swimming,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _types.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final type = _types[index];
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onSelect(type);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: kWhite.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: kWhite.withValues(alpha: 0.9),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: kInk.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(type.emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(
                    type.displayName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kInk,
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
// Activity History Card
// ─────────────────────────────────────────────────────────────────────────────

class _ActivityHistoryCard extends StatelessWidget {
  final FitnessActivityModel activity;

  const _ActivityHistoryCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    final duration = activity.activeDuration;
    final h = duration.inHours;
    final m = duration.inMinutes % 60;
    final s = duration.inSeconds % 60;
    final durationStr =
        h > 0 ? '${h}h ${m}m' : (m > 0 ? '${m}m ${s}s' : '${s}s');
    final distKm = (activity.distanceMeters / 1000).toStringAsFixed(2);
    final showDistance = activity.isGpsActivity && activity.distanceMeters > 0;

    return LiquidCard(
      frosted: true,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Type badge
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color:
                  _accentForType(activity.activityType).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                activity.activityType.emoji,
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title.isNotEmpty
                      ? activity.title
                      : activity.activityType.displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: kInk,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    durationStr,
                    if (showDistance) '$distKm km',
                    if (activity.calories != null) '${activity.calories} cal',
                  ].join(' · '),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kSub.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          // Status chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _statusColor(activity.status).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _statusLabel(activity.status),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: _statusColor(activity.status),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _accentForType(FitnessActivityType type) {
    switch (type) {
      case FitnessActivityType.running:
        return kCoral;
      case FitnessActivityType.walking:
        return kMint;
      case FitnessActivityType.cycling:
        return kBlue;
      case FitnessActivityType.hiking:
        return kRose;
      case FitnessActivityType.swimming:
        return kBlue;
      case FitnessActivityType.gymWorkout:
        return kPurple;
      case FitnessActivityType.custom:
        return kAmber;
    }
  }

  Color _statusColor(FitnessActivityStatus status) {
    switch (status) {
      case FitnessActivityStatus.completed:
        return kMint;
      case FitnessActivityStatus.active:
        return kAmber;
      case FitnessActivityStatus.paused:
        return kRose;
      case FitnessActivityStatus.cancelled:
      case FitnessActivityStatus.discarded:
        return kCoral;
      case FitnessActivityStatus.pending:
        return kSub;
    }
  }

  String _statusLabel(FitnessActivityStatus status) {
    switch (status) {
      case FitnessActivityStatus.completed:
        return 'Done';
      case FitnessActivityStatus.active:
        return 'Active';
      case FitnessActivityStatus.paused:
        return 'Paused';
      case FitnessActivityStatus.cancelled:
        return 'Cancelled';
      case FitnessActivityStatus.discarded:
        return 'Discarded';
      case FitnessActivityStatus.pending:
        return 'Pending';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty History Card
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyHistoryCard extends StatelessWidget {
  const _EmptyHistoryCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
      child: LiquidCard(
        frosted: true,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: kAmber.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.directions_run_rounded,
                size: 32,
                color: kAmber.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No activities yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: kInk,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Start your first activity to begin tracking your fitness journey.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
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

// ─────────────────────────────────────────────────────────────────────────────
// Navigation Pill
// ─────────────────────────────────────────────────────────────────────────────

class _NavPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: kWhite.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: kWhite.withValues(alpha: 0.9),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: kInk.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: kInk, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: kInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Today's Stats Summary Card
// ─────────────────────────────────────────────────────────────────────────────

class _TodayStatsSummary extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(todayFitnessStatsProvider);

    return statsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (stats) {
        if (stats == null || stats.totalActivities == 0) {
          return const SizedBox.shrink();
        }

        final distKm =
            (stats.totalDistanceMeters / 1000).toStringAsFixed(1);
        final durMin = stats.totalDurationMs ~/ 60000;
        final durStr = durMin >= 60
            ? '${durMin ~/ 60}h ${durMin % 60}m'
            : '${durMin}m';

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: LiquidCard(
            frosted: true,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Today's Summary",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: kSub.withValues(alpha: 0.6),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _MiniStat(
                      icon: Icons.directions_run_rounded,
                      value: '${stats.totalActivities}',
                      label: 'Activities',
                    ),
                    _MiniStat(
                      icon: Icons.straighten_rounded,
                      value: '$distKm km',
                      label: 'Distance',
                    ),
                    _MiniStat(
                      icon: Icons.timer_rounded,
                      value: durStr,
                      label: 'Duration',
                    ),
                    _MiniStat(
                      icon: Icons.local_fire_department_rounded,
                      value: '${stats.totalCalories}',
                      label: 'Cal',
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: kBlue, size: 16),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: kInk,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: kSub.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
