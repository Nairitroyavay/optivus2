import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/models/activity_split_model.dart';
import 'package:optivus2/models/fitness_activity_model.dart';
import 'package:optivus2/views/fitness/activity_formatters.dart';

class ActivityDetailScreen extends ConsumerWidget {
  final String activityId;

  const ActivityDetailScreen({super.key, required this.activityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(activityDetailProvider(activityId));
    final splitsAsync = ref.watch(activitySplitsProvider(activityId));
    final routeAsync = ref.watch(activityRoutePointsProvider(activityId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidBg(
        colors: const [Color(0xFF78FDFF), Color(0xFFE8FEFE)],
        child: SafeArea(
          child: activityAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => _Message(
              title: 'Activity unavailable',
              message: '$err',
              onBack: () => context.pop(),
            ),
            data: (activity) {
              if (activity == null) {
                return _Message(
                  title: 'Activity not found',
                  message: 'This activity may have been discarded.',
                  onBack: () => context.go('/fitness/history'),
                );
              }
              final splits =
                  splitsAsync.valueOrNull ?? const <ActivitySplitModel>[];
              final routePoints = routeAsync.valueOrNull ?? const [];

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                    child: Row(
                      children: [
                        LiquidIconBtn(
                          icon: Icons.arrow_back_rounded,
                          onTap: () => context.pop(),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            activityDisplayTitle(activity),
                            style: const TextStyle(
                              color: kInk,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _DetailHero(activity: activity),
                          const SizedBox(height: 16),
                          _Stats(activity: activity),
                          const SizedBox(height: 16),
                          if (_hasRoute(activity, routePoints))
                            LiquidButton(
                              label: 'Open Route Review',
                              leading:
                                  const Icon(Icons.map_rounded, color: kWhite),
                              color: kBlue,
                              onTap: () => context.push(
                                '/fitness/activity/${activity.activityId}/route',
                              ),
                            ),
                          if (_hasRoute(activity, routePoints))
                            const SizedBox(height: 16),
                          _NotesAndMetadata(activity: activity),
                          if (splits.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _SplitsList(splits: splits),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  bool _hasRoute(FitnessActivityModel activity, List routePoints) {
    return routePoints.length >= 2 ||
        activity.hasRoute ||
        activity.routePointCount > 0 ||
        activity.startLat != null;
  }
}

class _DetailHero extends StatelessWidget {
  final FitnessActivityModel activity;

  const _DetailHero({required this.activity});

  @override
  Widget build(BuildContext context) {
    return LiquidCard(
      frosted: true,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Text(activity.activityType.emoji,
              style: const TextStyle(fontSize: 42)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.activityType.displayName,
                  style: const TextStyle(
                    color: kInk,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _subtitle(activity),
                  style: TextStyle(
                    color: kSub.withValues(alpha: 0.72),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          _StatusChip(status: activity.status),
        ],
      ),
    );
  }

  String _subtitle(FitnessActivityModel activity) {
    if (activity.activityType == FitnessActivityType.swimming) {
      return activity.isPoolSwimming ? 'Pool swim' : 'Open-water swim';
    }
    if (activity.activityType == FitnessActivityType.gymWorkout) {
      return activity.workoutCategory.isEmpty
          ? 'Gym workout'
          : activity.workoutCategory;
    }
    return activity.hasRoute ? 'Route saved' : 'No route saved';
  }
}

class _Stats extends StatelessWidget {
  final FitnessActivityModel activity;

  const _Stats({required this.activity});

  @override
  Widget build(BuildContext context) {
    final durationSeconds = activity.durationSeconds > 0
        ? activity.durationSeconds
        : activity.activeDuration.inSeconds;
    final stats = [
      ('Time', formatStopwatchSeconds(durationSeconds)),
      ('Moving', formatStopwatchSeconds(activity.movingTimeSeconds)),
      ('Distance', formatDistance(activity.distanceMeters)),
      ('Pace', formatPrimaryPaceOrSpeed(activity)),
      ('Calories', '${activity.calories ?? 0}'),
      if (activity.averageHeartRate != null)
        ('Avg HR', '${activity.averageHeartRate} bpm'),
      if (activity.maxHeartRate != null)
        ('Max HR', '${activity.maxHeartRate} bpm'),
      if (activity.isPoolSwimming && activity.lapCount != null)
        ('Laps', '${activity.lapCount}'),
    ];

    return LiquidCard(
      frosted: true,
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final stat in stats)
            SizedBox(
              width: (MediaQuery.of(context).size.width - 72) / 2,
              child: _StatCell(label: stat.$1, value: stat.$2),
            ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;

  const _StatCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kWhite.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: kSub.withValues(alpha: 0.68),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: kInk,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesAndMetadata extends StatelessWidget {
  final FitnessActivityModel activity;

  const _NotesAndMetadata({required this.activity});

  @override
  Widget build(BuildContext context) {
    return LiquidCard(
      frosted: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Notes',
            style: TextStyle(
              color: kInk,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            activity.notes.isEmpty ? 'No notes saved.' : activity.notes,
            style: TextStyle(
              color: kSub.withValues(alpha: 0.76),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.38,
            ),
          ),
          if (activity.activityType == FitnessActivityType.gymWorkout) ...[
            const SizedBox(height: 14),
            const Text(
              'AI Feedback',
              style: TextStyle(
                color: kInk,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              activity.aiFeedback.isEmpty
                  ? 'No feedback saved yet.'
                  : activity.aiFeedback,
              style: TextStyle(
                color: kSub.withValues(alpha: 0.76),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SplitsList extends StatelessWidget {
  final List<ActivitySplitModel> splits;

  const _SplitsList({required this.splits});

  @override
  Widget build(BuildContext context) {
    return LiquidCard(
      frosted: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Splits',
            style: TextStyle(
              color: kInk,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          for (final split in splits) ...[
            Row(
              children: [
                SizedBox(
                  width: 34,
                  child: Text(
                    '${split.splitNumber}',
                    style: const TextStyle(
                      color: kInk,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Expanded(child: Text(formatDistance(split.distanceMeters))),
                Text(formatPace(split.paceSecondsPerKm)),
              ],
            ),
            if (split != splits.last)
              Divider(color: kSub.withValues(alpha: 0.14), height: 18),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final FitnessActivityStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status == FitnessActivityStatus.completed ? kMint : kAmber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status == FitnessActivityStatus.completed ? 'Done' : status.name,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onBack;

  const _Message({
    required this.title,
    required this.message,
    required this.onBack,
  });

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
              const Icon(Icons.info_outline_rounded, color: kBlue, size: 42),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: kInk,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: kSub.withValues(alpha: 0.72),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              LiquidButton(label: 'Back', onTap: onBack),
            ],
          ),
        ),
      ),
    );
  }
}
