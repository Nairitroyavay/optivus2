import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/models/activity_split_model.dart';
import 'package:optivus2/models/fitness_activity_model.dart';
import 'package:optivus2/views/fitness/activity_formatters.dart';

class ActivitySummaryScreen extends ConsumerStatefulWidget {
  final String activityId;

  const ActivitySummaryScreen({super.key, required this.activityId});

  @override
  ConsumerState<ActivitySummaryScreen> createState() =>
      _ActivitySummaryScreenState();
}

class _ActivitySummaryScreenState extends ConsumerState<ActivitySummaryScreen> {
  final _notesController = TextEditingController();
  final _distanceKmController = TextEditingController();
  final _lapsController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _avgHrController = TextEditingController();
  final _maxHrController = TextEditingController();

  String _workoutCategory = 'General workout';
  String? _hydratedActivityId;
  bool _saving = false;

  @override
  void dispose() {
    _notesController.dispose();
    _distanceKmController.dispose();
    _lapsController.dispose();
    _caloriesController.dispose();
    _avgHrController.dispose();
    _maxHrController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activityAsync = ref.watch(activityDetailProvider(widget.activityId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidBg(
        colors: const [Color(0xFF78FDFF), Color(0xFFE8FEFE)],
        child: SafeArea(
          child: activityAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => _MessageState(
              icon: Icons.error_outline_rounded,
              title: 'Activity unavailable',
              message: '$err',
              actionLabel: 'Back',
              onAction: () => context.go('/fitness'),
            ),
            data: (activity) {
              if (activity == null) {
                return _MessageState(
                  icon: Icons.history_toggle_off_rounded,
                  title: 'Activity not found',
                  message: 'This activity may have been discarded.',
                  actionLabel: 'Back to fitness',
                  onAction: () => context.go('/fitness'),
                );
              }
              _hydrate(activity);

              return Column(
                children: [
                  _Header(
                    title: 'Activity Saved',
                    onBack: () => context.go('/fitness'),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SavedHero(activity: activity),
                          const SizedBox(height: 16),
                          _StatsGrid(activity: activity),
                          const SizedBox(height: 16),
                          _ManualFields(
                            activity: activity,
                            notesController: _notesController,
                            distanceKmController: _distanceKmController,
                            lapsController: _lapsController,
                            caloriesController: _caloriesController,
                            avgHrController: _avgHrController,
                            maxHrController: _maxHrController,
                            workoutCategory: _workoutCategory,
                            onWorkoutCategoryChanged: (v) =>
                                setState(() => _workoutCategory = v),
                          ),
                          const SizedBox(height: 16),
                          if (activity.hasRoute ||
                              activity.routePointCount > 0 ||
                              activity.startLat != null)
                            LiquidButton(
                              label: 'Review Route',
                              leading: const Icon(
                                Icons.map_rounded,
                                color: kWhite,
                              ),
                              color: kBlue,
                              onTap: () => context.push(
                                '/fitness/activity/${activity.activityId}/route',
                              ),
                            ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: LiquidButton(
                                  label: _saving ? 'Saving...' : 'Save Notes',
                                  leading: _saving
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: kWhite,
                                          ),
                                        )
                                      : const Icon(Icons.check_rounded,
                                          color: kWhite),
                                  color: kMint,
                                  onTap: _saving
                                      ? null
                                      : () => _saveManualFields(activity),
                                ),
                              ),
                              const SizedBox(width: 10),
                              IconButton.filled(
                                style: IconButton.styleFrom(
                                  backgroundColor: kInk,
                                  fixedSize: const Size(52, 52),
                                ),
                                onPressed: () => context.go('/fitness/history'),
                                icon: const Icon(
                                  Icons.history_rounded,
                                  color: kWhite,
                                ),
                              ),
                            ],
                          ),
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

  void _hydrate(FitnessActivityModel activity) {
    if (_hydratedActivityId == activity.activityId) return;
    _hydratedActivityId = activity.activityId;
    _notesController.text = activity.notes;
    _distanceKmController.text = activity.distanceMeters > 0
        ? (activity.distanceMeters / 1000).toStringAsFixed(2)
        : '';
    _lapsController.text = activity.lapCount?.toString() ?? '';
    _caloriesController.text = activity.calories?.toString() ?? '';
    _avgHrController.text = activity.averageHeartRate?.toString() ?? '';
    _maxHrController.text = activity.maxHeartRate?.toString() ?? '';
    _workoutCategory = activity.workoutCategory.isNotEmpty
        ? activity.workoutCategory
        : 'General workout';
  }

  Future<void> _saveManualFields(FitnessActivityModel activity) async {
    setState(() => _saving = true);
    try {
      final calculator = ref.read(fitnessMetricsCalculatorProvider);
      final distanceMeters = _parseDouble(_distanceKmController.text) == null
          ? activity.distanceMeters
          : _parseDouble(_distanceKmController.text)! * 1000;
      final movingSeconds = activity.movingTimeSeconds > 0
          ? activity.movingTimeSeconds
          : activity.durationSeconds;
      final pace = calculator.paceSecondsPerKm(
        movingSeconds: movingSeconds,
        distanceMeters: distanceMeters,
      );
      final speed = calculator.speedKmh(
        movingSeconds: movingSeconds,
        distanceMeters: distanceMeters,
      );
      final calories = _parseInt(_caloriesController.text) ??
          calculator.caloriesEstimate(
            type: activity.activityType,
            movingSeconds: movingSeconds,
            distanceMeters: distanceMeters,
          );
      final laps = _parseInt(_lapsController.text);
      final updated = activity.copyWith(
        notes: _notesController.text.trim(),
        distanceMeters: distanceMeters,
        averagePaceSecondsPerKm: pace,
        averageSpeedKmh: speed,
        calories: calories,
        averageHeartRate: _parseInt(_avgHrController.text),
        maxHeartRate: _parseInt(_maxHrController.text),
        lapCount: laps,
        workoutCategory: activity.activityType == FitnessActivityType.gymWorkout
            ? _workoutCategory
            : activity.workoutCategory,
        updatedAt: DateTime.now(),
      );

      await ref.read(fitnessActivityRepositoryProvider).updateActivity(updated);
      if (updated.isPoolSwimming && (laps ?? 0) > 0) {
        await ref
            .read(fitnessActivityRepositoryProvider)
            .saveSplits(updated.activityId, _poolSplits(updated));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Activity notes saved')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<ActivitySplitModel> _poolSplits(FitnessActivityModel activity) {
    final laps = activity.lapCount ?? 0;
    final poolLength = activity.poolLengthMeters ?? 0;
    final movingMs = activity.movingTimeSeconds * 1000;
    if (laps <= 0 || poolLength <= 0 || movingMs <= 0) return const [];

    return List<ActivitySplitModel>.generate(laps, (index) {
      final startMs = (movingMs * index / laps).round();
      final endMs = (movingMs * (index + 1) / laps).round();
      final durationMs = endMs - startMs;
      return ActivitySplitModel(
        splitId: '${activity.activityId}_lap_${index + 1}',
        splitNumber: index + 1,
        distanceMeters: poolLength.toDouble(),
        durationMs: durationMs,
        paceSecondsPerKm:
            durationMs <= 0 ? null : durationMs / 1000 / (poolLength / 1000),
        startedAt: activity.startedAt?.add(Duration(milliseconds: startMs)),
        endedAt: activity.startedAt?.add(Duration(milliseconds: endMs)),
      );
    });
  }

  double? _parseDouble(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed);
  }

  int? _parseInt(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
  }
}

class _Header extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _Header({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 6),
      child: Row(
        children: [
          LiquidIconBtn(icon: Icons.arrow_back_rounded, onTap: onBack),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: kInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedHero extends StatelessWidget {
  final FitnessActivityModel activity;

  const _SavedHero({required this.activity});

  @override
  Widget build(BuildContext context) {
    return LiquidCard(
      frosted: true,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Text(activity.activityType.emoji,
              style: const TextStyle(fontSize: 40)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activityDisplayTitle(activity),
                  style: const TextStyle(
                    color: kInk,
                    fontSize: 21,
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
          const Icon(Icons.check_circle_rounded, color: kMint, size: 30),
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
    return activity.hasRoute ? 'Route saved' : 'Manual activity';
  }
}

class _StatsGrid extends StatelessWidget {
  final FitnessActivityModel activity;

  const _StatsGrid({required this.activity});

  @override
  Widget build(BuildContext context) {
    final durationSeconds = activity.durationSeconds > 0
        ? activity.durationSeconds
        : activity.activeDuration.inSeconds;
    final items = [
      ('Time', formatStopwatchSeconds(durationSeconds), Icons.timer_rounded),
      (
        'Distance',
        formatDistance(activity.distanceMeters),
        Icons.straighten_rounded
      ),
      (
        activity.activityType == FitnessActivityType.cycling ? 'Speed' : 'Pace',
        formatPrimaryPaceOrSpeed(activity),
        Icons.speed_rounded
      ),
      (
        'Calories',
        '${activity.calories ?? 0}',
        Icons.local_fire_department_rounded
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.7,
      ),
      itemCount: items.length,
      itemBuilder: (_, index) {
        final item = items[index];
        return LiquidCard(
          frosted: true,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(item.$3, color: kBlue, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.$1,
                      style: TextStyle(
                        color: kSub.withValues(alpha: 0.66),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        item.$2,
                        style: const TextStyle(
                          color: kInk,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ManualFields extends StatelessWidget {
  final FitnessActivityModel activity;
  final TextEditingController notesController;
  final TextEditingController distanceKmController;
  final TextEditingController lapsController;
  final TextEditingController caloriesController;
  final TextEditingController avgHrController;
  final TextEditingController maxHrController;
  final String workoutCategory;
  final ValueChanged<String> onWorkoutCategoryChanged;

  const _ManualFields({
    required this.activity,
    required this.notesController,
    required this.distanceKmController,
    required this.lapsController,
    required this.caloriesController,
    required this.avgHrController,
    required this.maxHrController,
    required this.workoutCategory,
    required this.onWorkoutCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final showDistance =
        activity.activityType == FitnessActivityType.swimming ||
            !activity.hasRoute;
    return LiquidCard(
      frosted: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Activity Details',
            style: TextStyle(
              color: kInk,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          if (showDistance) ...[
            LiquidTextField(
              hint: 'Manual distance (km)',
              prefixIcon: Icons.straighten_rounded,
              controller: distanceKmController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
            ),
            const SizedBox(height: 10),
          ],
          if (activity.isPoolSwimming) ...[
            LiquidTextField(
              hint: 'Laps',
              prefixIcon: Icons.pool_rounded,
              controller: lapsController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 10),
          ],
          if (activity.activityType == FitnessActivityType.gymWorkout) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in const [
                  'General workout',
                  'Strength',
                  'Cardio',
                  'Mobility',
                ])
                  ChoiceChip(
                    label: Text(category),
                    selected: workoutCategory == category,
                    selectedColor: kPurple.withValues(alpha: 0.2),
                    onSelected: (_) => onWorkoutCategoryChanged(category),
                  ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          LiquidTextField(
            hint: 'Calories',
            prefixIcon: Icons.local_fire_department_rounded,
            controller: caloriesController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: LiquidTextField(
                  hint: 'Avg HR',
                  prefixIcon: Icons.favorite_rounded,
                  controller: avgHrController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LiquidTextField(
                  hint: 'Max HR',
                  prefixIcon: Icons.monitor_heart_rounded,
                  controller: maxHrController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LiquidTextField(
            hint: 'Notes',
            prefixIcon: Icons.edit_note_rounded,
            controller: notesController,
          ),
          if (activity.activityType == FitnessActivityType.gymWorkout) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kWhite.withValues(alpha: 0.58),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kWhite.withValues(alpha: 0.82)),
              ),
              child: Text(
                activity.aiFeedback.isEmpty
                    ? 'AI feedback will appear here after workout analysis is enabled.'
                    : activity.aiFeedback,
                style: TextStyle(
                  color: kSub.withValues(alpha: 0.74),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
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
              Icon(icon, color: kCoral, size: 42),
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
              LiquidButton(label: actionLabel, onTap: onAction),
            ],
          ),
        ),
      ),
    );
  }
}
