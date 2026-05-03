import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/models/habit_model.dart';
import 'package:optivus2/views/habits/variants/exercise_tracker_view.dart';
import 'package:optivus2/views/habits/variants/hydration_tracker_view.dart';
import 'package:optivus2/views/habits/variants/meditation_tracker_view.dart';
import 'package:optivus2/views/habits/variants/mindful_eating_tracker_view.dart';
import 'package:optivus2/views/habits/variants/money_saving_tracker_view.dart';
import 'package:optivus2/views/habits/variants/procrastination_tracker_view.dart';
import 'package:optivus2/views/habits/variants/reading_tracker_view.dart';
import 'package:optivus2/views/habits/variants/routine_completion_tracker_view.dart';
import 'package:optivus2/views/habits/variants/screen_time_tracker_view.dart';
import 'package:optivus2/views/habits/variants/smoking_tracker_view.dart';

class HabitDetailScreen extends ConsumerWidget {
  final String habitId;

  const HabitDetailScreen({super.key, required this.habitId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: kInk,
        title: const Text('Habit Details'),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => context.push('/habits/$habitId/edit'),
          ),
        ],
      ),
      body: user == null
          ? const _DetailError(message: 'No authenticated user.')
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('habits')
                  .doc(habitId)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: kAmber),
                  );
                }
                if (snap.hasError) {
                  return _DetailError(message: snap.error.toString());
                }
                final doc = snap.data;
                if (doc == null || !doc.exists) {
                  return const _DetailError(message: 'Habit not found.');
                }

                final habit = HabitModel.fromFirestore(doc);
                return _DetailBody(habit: habit);
              },
            ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  final HabitModel habit;

  const _DetailBody({required this.habit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        LiquidCard(
          radius: 24,
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: habit.emoji != null && habit.emoji!.isNotEmpty
                      ? Text(habit.emoji!, style: const TextStyle(fontSize: 26))
                      : Icon(_icon, color: _accent, size: 26),
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
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: kInk,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${habit.kind.name} • ${habit.trackerType.replaceAll('_', ' ')}',
                      style: TextStyle(
                        color: kSub.withValues(alpha: 0.76),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _StateChip(state: habit.state),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _StreakShortcutCard(habit: habit),
        const SizedBox(height: 16),
        _variantFor(habit),
        const SizedBox(height: 16),
        _InfoCard(
          title: 'Target',
          rows: [
            _InfoRow('Unit', habit.unit),
            if (habit.kind == HabitKind.good)
              _InfoRow('Daily target', '${habit.dailyGoal ?? 1}')
            else ...[
              _InfoRow('Goal type', _badGoalLabel(habit.goalType)),
              _InfoRow('Target', habit.target?.toString() ?? 'None'),
            ],
            _InfoRow('Money value', habit.costPerUnit?.toString() ?? 'None'),
          ],
        ),
        _InfoCard(
          title: 'Schedule',
          rows: [
            _InfoRow(
              'Days',
              habit.scheduleDays.isEmpty
                  ? 'Every day'
                  : habit.scheduleDays.map(_weekdayLabel).join(', '),
            ),
            _InfoRow(
              'Reminders',
              habit.remindersEnabled
                  ? 'Enabled at ${habit.reminderTime ?? '--:--'}'
                  : 'Off',
            ),
            _InfoRow('Accountability', habit.accountability ?? 'None'),
          ],
        ),
        _InfoCard(
          title: 'Lifecycle',
          rows: [
            _InfoRow('Created', _dateLabel(habit.createdAt)),
            _InfoRow('Updated', _dateLabel(habit.updatedAt)),
            if (habit.pausedAt != null)
              _InfoRow('Paused', _dateLabel(habit.pausedAt!)),
            if (habit.archivedAt != null)
              _InfoRow('Archived', _dateLabel(habit.archivedAt!)),
          ],
        ),
        _LifecycleActions(habit: habit),
      ],
    );
  }

  Color get _accent => habit.kind == HabitKind.good ? kMint : kCoral;

  IconData get _icon =>
      habit.kind == HabitKind.good ? Icons.check_rounded : Icons.block_rounded;

  Widget _variantFor(HabitModel habit) {
    switch (habit.trackerType) {
      case 'smoking':
        return SmokingTrackerView(habit: habit);
      case 'screen_time':
        return ScreenTimeTrackerView(habit: habit);
      case 'junk_food':
      case 'mindful_eating':
        return MindfulEatingTrackerView(habit: habit);
      case 'procrastination':
        return ProcrastinationTrackerView(habit: habit);
      case 'water':
      case 'hydration':
        return HydrationTrackerView(habit: habit);
      case 'meditation':
        return MeditationTrackerView(habit: habit);
      case 'money_saving':
        return MoneySavingTrackerView(habit: habit);
      case 'reading':
        return ReadingTrackerView(habit: habit);
      case 'exercise':
      case 'steps':
        return ExerciseTrackerView(habit: habit);
      case 'routine_completion':
        return RoutineCompletionTrackerView(habit: habit);
      default:
        return habit.kind == HabitKind.bad
            ? ProcrastinationTrackerView(habit: habit)
            : ExerciseTrackerView(habit: habit);
    }
  }

  static String _badGoalLabel(BadHabitGoalType? type) {
    switch (type) {
      case BadHabitGoalType.eliminate:
        return 'Eliminate';
      case BadHabitGoalType.reduceToTarget:
        return 'Reduce to target';
      case BadHabitGoalType.awarenessOnly:
      case null:
        return 'Awareness only';
    }
  }

  static String _weekdayLabel(int day) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    if (day < 1 || day > 7) return day.toString();
    return labels[day - 1];
  }

  static String _dateLabel(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class _StreakShortcutCard extends StatelessWidget {
  final HabitModel habit;

  const _StreakShortcutCard({required this.habit});

  @override
  Widget build(BuildContext context) {
    final accent = habit.kind == HabitKind.good ? kMint : kCoral;
    return GestureDetector(
      onTap: () => context.push('/streaks/${habit.id}'),
      child: LiquidCard(
        radius: 20,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: kAmber.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.local_fire_department_rounded,
                color: kAmber,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Streak details',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: kInk,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Heatmap, milestones, history, and pause status',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: kSub.withValues(alpha: 0.78),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: accent),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<_InfoRow> rows;

  const _InfoCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: LiquidCard(
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
            ...rows,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: kSub.withValues(alpha: 0.78),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: kInk,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  final HabitState state;

  const _StateChip({required this.state});

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      HabitState.active => kMint,
      HabitState.paused => kAmber,
      HabitState.archived => kSub,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        state.name,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _LifecycleActions extends ConsumerWidget {
  final HabitModel habit;

  const _LifecycleActions({required this.habit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.read(habitServiceProvider);
    final archived = habit.state == HabitState.archived;
    final paused = habit.state == HabitState.paused;

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Expanded(
            child: LiquidButton.outline(
              label: paused ? 'Resume' : 'Pause',
              color: paused ? kMint : kAmber,
              height: 50,
              onTap: archived
                  ? null
                  : () async {
                      try {
                        if (paused) {
                          await service.resumeHabit(habit.id);
                        } else {
                          await service.pauseHabit(habit.id);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Habit update failed: $e'),
                              backgroundColor: kCoral,
                            ),
                          );
                        }
                      }
                    },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: LiquidButton(
              label: archived ? 'Archived' : 'Archive',
              color: kCoral,
              height: 50,
              onTap: archived
                  ? null
                  : () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Archive habit?'),
                          content: const Text(
                            'Archived habits stop appearing in active daily cards.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Archive'),
                            ),
                          ],
                        ),
                      );
                      if (confirm != true) return;
                      try {
                        await service.archiveHabit(habit.id);
                        if (context.mounted) context.pop();
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Archive failed: $e'),
                              backgroundColor: kCoral,
                            ),
                          );
                        }
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailError extends StatelessWidget {
  final String message;

  const _DetailError({required this.message});

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
