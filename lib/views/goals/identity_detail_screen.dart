import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../models/goal_model.dart';
import '../../models/habit_model.dart';
import '../../models/day_summary_model.dart';
import '../../providers/goal_provider.dart';

import '../../core/liquid_ui/liquid_ui.dart';
import 'why_this_score_card.dart';

class IdentityDetailScreen extends ConsumerWidget {
  final String goalId;

  const IdentityDetailScreen({
    super.key,
    required this.goalId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalProvider);

    return LiquidBg(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: kInk),
            onPressed: () => context.pop(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.more_horiz, color: kInk),
              onPressed: () => _showSettingsMenu(context, ref),
            ),
          ],
        ),
        body: goalsAsync.when(
          data: (goals) {
            final goal = goals.firstWhere(
              (g) => g.goalId == goalId,
              orElse: () => GoalModel(title: 'Not Found'),
            );

            if (goal.title == 'Not Found') {
              return const Center(
                child: Text(
                  'Identity not found or archived.',
                  style: TextStyle(color: kSub),
                ),
              );
            }

            final habitsAsync = ref.watch(habitsProvider);
            final recentSummariesAsync =
                ref.watch(recentDailySummariesProvider(7));

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _buildHeroArc(goal),
                const SizedBox(height: 24),
                Text(
                  goal.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: kInk,
                  ),
                ),
                if (goal.why.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    goal.why,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: kSub,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                habitsAsync.when(
                  data: (allHabits) {
                    final linkedHabits = allHabits
                        .where((h) => goal.connectedHabitIds.contains(h.id))
                        .toList();
                    return Column(
                      children: [
                        WhyThisScoreCard(goal: goal, habits: linkedHabits),
                        const SizedBox(height: 24),
                        _buildFeedsList(linkedHabits),
                      ],
                    );
                  },
                  loading: () => const Center(
                      child: CircularProgressIndicator(color: kBlue)),
                  error: (e, st) =>
                      Text('Error: $e', style: const TextStyle(color: kCoral)),
                ),
                const SizedBox(height: 24),
                _buildMilestones(context, ref, goal),
                const SizedBox(height: 24),
                recentSummariesAsync.when(
                  data: (summaries) => _buildTimeline(summaries),
                  loading: () => const Center(
                      child: CircularProgressIndicator(color: kBlue)),
                  error: (e, st) =>
                      Text('Error: $e', style: const TextStyle(color: kCoral)),
                ),
                const SizedBox(height: 32),
                LiquidButton.outline(
                  label: 'Talk to Coach',
                  color: kPurple,
                  leading:
                      const Icon(Icons.chat_bubble_outline, color: kPurple),
                  onTap: () {
                    // Talk-to-coach button
                  },
                ),
                const SizedBox(height: 32),
              ],
            );
          },
          loading: () =>
              const Center(child: CircularProgressIndicator(color: kBlue)),
          error: (e, st) => Center(
              child: Text('Error: $e', style: const TextStyle(color: kCoral))),
        ),
      ),
    );
  }

  Widget _buildHeroArc(GoalModel goal) {
    final colorString = goal.colorHex ?? '#14B8A6';
    final color = Color(int.parse(colorString.replaceFirst('#', '0xFF')));

    return Center(
      child: SizedBox(
        width: 240,
        height: 240,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 240,
              height: 240,
              child: CircularProgressIndicator(
                value: goal.progress / 100,
                strokeWidth: 16,
                backgroundColor: color.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${goal.progress}%',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: kInk,
                  ),
                ),
                const Text(
                  'Identity Score',
                  style: TextStyle(
                    fontSize: 16,
                    color: kSub,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedsList(List<HabitModel> habits) {
    if (habits.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What feeds this identity',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: kInk,
          ),
        ),
        const SizedBox(height: 12),
        ...habits.map((h) => LiquidCard.solid(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Text(
                    h.emoji ?? '✅',
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      h.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: kInk,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildMilestones(BuildContext context, WidgetRef ref, GoalModel goal) {
    if (goal.milestones.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Milestones',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: kInk,
          ),
        ),
        const SizedBox(height: 12),
        ...goal.milestones.asMap().entries.map((entry) {
          final index = entry.key;
          final milestone = entry.value;

          return LiquidCard.solid(
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                LiquidCheckbox(
                  value: milestone.completed,
                  activeColor: kMint,
                  onChanged: (val) {
                    final newMilestones =
                        List<GoalMilestone>.from(goal.milestones);
                    newMilestones[index] = GoalMilestone(
                      milestoneId: milestone.milestoneId,
                      title: milestone.title,
                      completed: val,
                      completedAt: val ? DateTime.now() : null,
                    );

                    ref.read(goalRepositoryProvider).updateGoal(
                          goal.copyWith(milestones: newMilestones),
                        );
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    milestone.title,
                    style: TextStyle(
                      color: kInk,
                      decoration: milestone.completed
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTimeline(List<DaySummary> summaries) {
    if (summaries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Wins & Slips (7 days)',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: kInk,
          ),
        ),
        const SizedBox(height: 12),
        LiquidCard.solid(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: summaries.take(7).toList().reversed.map((summary) {
              final date =
                  DateTime.tryParse(summary.date) ?? summary.computedAt;
              final weekday = _shortWeekday(date.weekday);
              final color = summary.habitsBadLogged > 0
                  ? kRose
                  : (summary.habitsCompleted > 0 ? kMint : kSub);

              return Column(
                children: [
                  Text(
                    weekday,
                    style: const TextStyle(
                      fontSize: 12,
                      color: kSub,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.2),
                      border: Border.all(color: color, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        summary.habitsCompleted.toString(),
                        style: TextStyle(
                          fontSize: 10,
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  void _showSettingsMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: kSub.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.link, color: kInk),
                title:
                    const Text('Connect Habits', style: TextStyle(color: kInk)),
                onTap: () {
                  context.pop();
                  // TODO: implement habit connection modal
                },
              ),
              ListTile(
                leading: const Icon(Icons.monitor_weight_outlined, color: kInk),
                title:
                    const Text('Adjust Weights', style: TextStyle(color: kInk)),
                onTap: () {
                  context.pop();
                  _showWeightDialog(context, ref);
                },
              ),
              ListTile(
                leading: const Icon(Icons.pause, color: kAmber),
                title: const Text('Pause Identity',
                    style: TextStyle(color: kAmber)),
                onTap: () {
                  Navigator.of(context).pop();
                  _showPauseDurationSheet(context, ref);
                },
              ),
              ListTile(
                leading: const Icon(Icons.archive_outlined, color: kCoral),
                title: const Text('Archive Identity',
                    style: TextStyle(color: kCoral)),
                onTap: () {
                  Navigator.of(context).pop();
                  _confirmArchiveIdentity(context, ref);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showPauseDurationSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: kWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: kSub.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Pause identity',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: kInk,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _PauseDurationTile(
                label: '7 days',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pauseIdentity(context, ref, durationDays: 7);
                },
              ),
              _PauseDurationTile(
                label: '30 days',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pauseIdentity(context, ref, durationDays: 30);
                },
              ),
              _PauseDurationTile(
                label: '90 days',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pauseIdentity(context, ref, durationDays: 90);
                },
              ),
              _PauseDurationTile(
                label: 'Until I unpause',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pauseIdentity(context, ref);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pauseIdentity(
    BuildContext context,
    WidgetRef ref, {
    int? durationDays,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final pausedUntil = durationDays == null
        ? null
        : DateTime.now().add(Duration(days: durationDays));

    try {
      await ref.read(goalRepositoryProvider).pauseGoal(
            goalId,
            pausedUntil: pausedUntil,
            pauseDurationDays: durationDays,
          );
      if (!context.mounted) return;
      if (context.canPop()) context.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            durationDays == null
                ? 'Identity paused until you reactivate it.'
                : 'Identity paused for $durationDays days.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not pause identity: $e')),
      );
    }
  }

  Future<void> _confirmArchiveIdentity(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kWhite,
        title: const Text('Archive identity', style: TextStyle(color: kInk)),
        content: const Text(
          'This removes the identity from your active list and saves a final summary card.',
          style: TextStyle(color: kSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: kSub)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Archive', style: TextStyle(color: kCoral)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    await _archiveIdentity(context, ref);
  }

  Future<void> _archiveIdentity(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: kBlue),
      ),
    );

    try {
      await ref.read(goalRepositoryProvider).archiveGoal(goalId);
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      if (context.canPop()) context.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Identity archived.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Could not archive identity: $e')),
      );
    }
  }

  void _showWeightDialog(BuildContext context, WidgetRef ref) async {
    final goalRepo = ref.read(goalRepositoryProvider);
    final goal = await goalRepo.getGoal(goalId);
    if (goal == null) return;

    if (!context.mounted) return;

    int currentWeight = goal.weight;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: kWhite,
              title: const Text('Adjust Weight', style: TextStyle(color: kInk)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'How heavily should this identity weigh in your overall score?',
                    style: TextStyle(color: kSub),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      LiquidIconBtn(
                        icon: Icons.remove,
                        onTap: currentWeight > 1
                            ? () => setState(() => currentWeight--)
                            : () {},
                      ),
                      const SizedBox(width: 16),
                      Text(
                        currentWeight.toString(),
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: kInk),
                      ),
                      const SizedBox(width: 16),
                      LiquidIconBtn(
                        icon: Icons.add,
                        onTap: () => setState(() => currentWeight++),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: kSub)),
                ),
                TextButton(
                  onPressed: () {
                    goalRepo.updateGoal(goal.copyWith(weight: currentWeight));
                    Navigator.pop(ctx);
                  },
                  child: const Text('Save', style: TextStyle(color: kBlue)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _shortWeekday(int weekday) {
    switch (weekday) {
      case 1:
        return 'MON';
      case 2:
        return 'TUE';
      case 3:
        return 'WED';
      case 4:
        return 'THU';
      case 5:
        return 'FRI';
      case 6:
        return 'SAT';
      case 7:
        return 'SUN';
      default:
        return '';
    }
  }
}

class _PauseDurationTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PauseDurationTile({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.pause_circle_outline, color: kAmber),
      title: Text(label, style: const TextStyle(color: kInk)),
      onTap: onTap,
    );
  }
}
