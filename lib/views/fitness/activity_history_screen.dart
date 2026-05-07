import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/models/fitness_activity_model.dart';
import 'package:optivus2/views/fitness/activity_formatters.dart';

class ActivityHistoryScreen extends ConsumerWidget {
  const ActivityHistoryScreen({super.key});

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
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                  child: Row(
                    children: [
                      LiquidIconBtn(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => context.pop(),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          'Activity History',
                          style: TextStyle(
                            color: kInk,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              historyAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: LinearProgressIndicator(color: kAmber),
                  ),
                ),
                error: (err, _) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Failed to load activity history: $err',
                      style: const TextStyle(
                        color: kCoral,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                data: (activities) {
                  if (activities.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: _EmptyHistory(),
                    );
                  }
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final activity = activities[index];
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                          child: _HistoryTile(
                            activity: activity,
                            onTap: () => context.push(
                              '/fitness/activity/${activity.activityId}',
                            ),
                          ),
                        );
                      },
                      childCount: activities.length,
                    ),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 90)),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final FitnessActivityModel activity;
  final VoidCallback onTap;

  const _HistoryTile({required this.activity, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final durationSeconds = activity.durationSeconds > 0
        ? activity.durationSeconds
        : activity.activeDuration.inSeconds;
    return LiquidCard(
      frosted: true,
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(activity.activityType.emoji,
                  style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activityDisplayTitle(activity),
                      style: const TextStyle(
                        color: kInk,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        formatStopwatchSeconds(durationSeconds),
                        if (activity.distanceMeters > 0)
                          formatDistance(activity.distanceMeters),
                        if (activity.calories != null)
                          '${activity.calories} cal',
                      ].join(' · '),
                      style: TextStyle(
                        color: kSub.withValues(alpha: 0.72),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (activity.hasRoute || activity.routePointCount > 0)
                const Icon(Icons.route_rounded, color: kBlue),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: kSub),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: LiquidCard(
        frosted: true,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.history_rounded, color: kAmber, size: 42),
            const SizedBox(height: 12),
            const Text(
              'No activities yet',
              style: TextStyle(
                color: kInk,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            LiquidButton(
              label: 'Start Activity',
              onTap: () => context.push('/fitness/select'),
            ),
          ],
        ),
      ),
    );
  }
}
