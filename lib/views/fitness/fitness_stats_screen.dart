// lib/views/fitness/fitness_stats_screen.dart
//
// Full stats dashboard — daily/weekly/monthly tab switcher with
// distance, duration, calories cards and activity breakdown.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/models/fitness_stats_model.dart';

class FitnessStatsScreen extends ConsumerStatefulWidget {
  const FitnessStatsScreen({super.key});

  @override
  ConsumerState<FitnessStatsScreen> createState() => _FitnessStatsScreenState();
}

class _FitnessStatsScreenState extends ConsumerState<FitnessStatsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidBg(
        colors: const [Color(0xFF78FDFF), Color(0xFFE8FEFE)],
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
                child: Row(
                  children: [
                    LiquidIconBtn(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => context.pop(),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'Fitness Stats',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: kInk,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Period tabs ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: LiquidCard(
                  frosted: true,
                  padding: const EdgeInsets.all(4),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: kInk,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    labelColor: kWhite,
                    unselectedLabelColor: kSub,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'Day'),
                      Tab(text: 'Week'),
                      Tab(text: 'Month'),
                    ],
                  ),
                ),
              ),

              // ── Stats body ──
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _StatsPeriodView(provider: todayFitnessStatsProvider),
                    _StatsPeriodView(provider: weeklyFitnessStatsProvider),
                    _StatsPeriodView(provider: monthlyFitnessStatsProvider),
                  ],
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
// Stats Period View
// ─────────────────────────────────────────────────────────────────────────────

class _StatsPeriodView extends ConsumerWidget {
  final StreamProvider<FitnessStatsModel?> provider;

  const _StatsPeriodView({required this.provider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(provider);

    return statsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: kAmber),
        ),
      ),
      error: (err, _) => _ErrorCard(message: '$err'),
      data: (stats) {
        if (stats == null || stats.totalActivities == 0) {
          return const _EmptyStatsCard();
        }
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
          child: Column(
            children: [
              _MetricRow(stats: stats),
              const SizedBox(height: 14),
              _ActivityBreakdownCard(breakdown: stats.activityBreakdown),
              const SizedBox(height: 14),
              _ExtraMetricsCard(stats: stats),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Metric Cards Row
// ─────────────────────────────────────────────────────────────────────────────

class _MetricRow extends StatelessWidget {
  final FitnessStatsModel stats;

  const _MetricRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    final distKm = (stats.totalDistanceMeters / 1000).toStringAsFixed(1);
    final durMin = stats.totalDurationMs ~/ 60000;
    final durH = durMin ~/ 60;
    final durM = durMin % 60;
    final durStr = durH > 0 ? '${durH}h ${durM}m' : '${durM}m';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.directions_run_rounded,
                iconColor: kCoral,
                label: 'Activities',
                value: '${stats.totalActivities}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                icon: Icons.straighten_rounded,
                iconColor: kBlue,
                label: 'Distance',
                value: '$distKm km',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.timer_rounded,
                iconColor: kPurple,
                label: 'Duration',
                value: durStr,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                icon: Icons.local_fire_department_rounded,
                iconColor: kAmber,
                label: 'Calories',
                value: '${stats.totalCalories}',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidCard(
      frosted: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: kSub.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: kInk,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Activity Breakdown Card
// ─────────────────────────────────────────────────────────────────────────────

class _ActivityBreakdownCard extends StatelessWidget {
  final Map<String, int> breakdown;

  const _ActivityBreakdownCard({required this.breakdown});

  static const _typeColors = <String, Color>{
    'running': kCoral,
    'walking': kMint,
    'cycling': kBlue,
    'hiking': kRose,
    'swimming': Color(0xFF4ECDC4),
    'gym_workout': kPurple,
    'custom': kAmber,
  };

  static const _typeEmoji = <String, String>{
    'running': '🏃',
    'walking': '🚶',
    'cycling': '🚴',
    'hiking': '🥾',
    'swimming': '🏊',
    'gym_workout': '🏋️',
    'custom': '⚡',
  };

  @override
  Widget build(BuildContext context) {
    if (breakdown.isEmpty) return const SizedBox.shrink();

    final total = breakdown.values.fold<int>(0, (a, b) => a + b);
    final sorted = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return LiquidCard(
      frosted: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Activity Breakdown',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: kInk,
            ),
          ),
          const SizedBox(height: 14),
          // Bar chart
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 10,
              child: Row(
                children: sorted.map((e) {
                  final pct = e.value / total;
                  return Expanded(
                    flex: (pct * 100).round().clamp(1, 100),
                    child: Container(
                      color: _typeColors[e.key] ?? kSub,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Legend
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: sorted.map((e) {
              final pct = ((e.value / total) * 100).round();
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _typeEmoji[e.key] ?? '⚡',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${e.value} ($pct%)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: kSub.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Extra Metrics
// ─────────────────────────────────────────────────────────────────────────────

class _ExtraMetricsCard extends StatelessWidget {
  final FitnessStatsModel stats;

  const _ExtraMetricsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final longestMin = stats.longestActivityMs ~/ 60000;
    final longestStr = longestMin >= 60
        ? '${longestMin ~/ 60}h ${longestMin % 60}m'
        : '${longestMin}m';

    String? paceStr;
    if (stats.averagePaceSecondsPerKm != null) {
      final p = stats.averagePaceSecondsPerKm!;
      paceStr = "${p ~/ 60}'${(p % 60).round().toString().padLeft(2, '0')}\" /km";
    }

    return LiquidCard(
      frosted: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: kInk,
            ),
          ),
          const SizedBox(height: 12),
          _ExtraRow(label: 'Longest Activity', value: longestStr),
          if (paceStr != null) ...[
            const SizedBox(height: 8),
            _ExtraRow(label: 'Avg Pace', value: paceStr),
          ],
        ],
      ),
    );
  }
}

class _ExtraRow extends StatelessWidget {
  final String label;
  final String value;

  const _ExtraRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: kSub.withValues(alpha: 0.7),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: kInk,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty & Error States
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyStatsCard extends StatelessWidget {
  const _EmptyStatsCard();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: LiquidCard(
          frosted: true,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: kBlue.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.bar_chart_rounded,
                  size: 32,
                  color: kBlue.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No stats yet',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: kInk,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Complete your first activity to see your stats here.',
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
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: LiquidCard(
          frosted: true,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: kCoral, size: 42),
              const SizedBox(height: 12),
              const Text(
                'Failed to load stats',
                style: TextStyle(
                  color: kInk,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: kSub.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
