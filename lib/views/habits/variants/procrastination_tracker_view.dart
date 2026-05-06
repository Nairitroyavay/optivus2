import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/models/habit_log_model.dart';
import 'package:optivus2/models/habit_model.dart';
import 'package:optivus2/models/task_model.dart';

class ProcrastinationTrackerView extends ConsumerStatefulWidget {
  final HabitModel habit;

  const ProcrastinationTrackerView({super.key, required this.habit});

  @override
  ConsumerState<ProcrastinationTrackerView> createState() =>
      _ProcrastinationTrackerViewState();
}

class _ProcrastinationTrackerViewState
    extends ConsumerState<ProcrastinationTrackerView> {
  HabitModel get habit => widget.habit;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(
          child: Text('Not signed in', style: TextStyle(color: kInk)));
    }

    final start = _dayStart(DateTime.now().subtract(const Duration(days: 6)));
    final logsStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('habit_logs')
        .where('habitId', isEqualTo: habit.id)
        .where('occurredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .snapshots();

    final tasksStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .where('plannedStart',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: logsStream,
      builder: (context, logsSnap) {
        if (logsSnap.connectionState == ConnectionState.waiting &&
            !logsSnap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator(color: kAmber)),
          );
        }

        final logs = logsSnap.data?.docs
                .map(HabitLog.fromFirestore)
                .where((l) => !l.isDismissed)
                .toList() ??
            const [];

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: tasksStream,
          builder: (context, tasksSnap) {
            final tasks =
                tasksSnap.data?.docs.map(TaskModel.fromFirestore).toList() ??
                    const [];

            final today = DateTime.now();
            final todayStr = _dateStr(today);
            final todayLogs = logs
                .where((l) => _dateStr(l.occurredAt) == todayStr)
                .toList()
              ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
            final todayMinutes =
                todayLogs.fold<num>(0, (s, l) => s + (l.quantity ?? 0));

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 14),
                _buildHero(todayMinutes),
                const SizedBox(height: 14),
                _buildLogButton(),
                const SizedBox(height: 14),
                _buildMixedLog(todayLogs),
                const SizedBox(height: 14),
                _buildTimeHeatmap(logs),
                const SizedBox(height: 14),
                _buildTaskTypeHeatmap(logs, tasks),
                const SizedBox(height: 14),
                _buildIdentityDamage(logs, tasks),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Procrastination',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: kInk,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Procrastination is information, not failure.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: kSub.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(num todayMinutes) {
    return LiquidCard(
      radius: 22,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: kPurple.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.hourglass_bottom_rounded,
                color: kPurple, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Today lost',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: kInk,
                  ),
                ),
                Text(
                  '${todayMinutes.round()} minutes',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: kPurple,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogButton() {
    return LiquidButton(
      label: 'Log a Delay',
      color: kPurple,
      leading: const Icon(Icons.add_rounded, color: Colors.white),
      onTap: () => _showLogModal(context),
    );
  }

  Widget _buildMixedLog(List<HabitLog> todayLogs) {
    if (todayLogs.isEmpty) {
      return LiquidCard(
        radius: 22,
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'Clear day so far!',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: kSub.withValues(alpha: 0.6),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            'TODAY\'S LOG',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              color: kSub.withValues(alpha: 0.6),
            ),
          ),
        ),
        ...todayLogs.map((log) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _LogItemCard(log: log, habit: habit),
            )),
      ],
    );
  }

  Widget _buildTimeHeatmap(List<HabitLog> logs) {
    final now = DateTime.now();
    final grid = List.generate(7, (_) => List.filled(24, 0));
    for (final log in logs) {
      final diff = now.difference(log.occurredAt).inDays;
      if (diff < 0 || diff > 6) continue;
      final row = 6 - diff;
      grid[row][log.occurredAt.hour] += (log.quantity ?? 1).toInt();
    }
    final maxCell = grid.expand((r) => r).fold<int>(1, math.max);

    return LiquidCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Time-of-Day Heatmap',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w900, color: kInk)),
          const SizedBox(height: 4),
          Text('Activity over the last 7 days',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: kSub.withValues(alpha: 0.6))),
          const SizedBox(height: 14),
          SizedBox(
            height: 7 * 14.0,
            child: Row(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < 7; i++)
                      Text(
                        _dayLabels[
                            (now.subtract(Duration(days: 6 - i)).weekday - 1) %
                                7],
                        style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            color: kSub.withValues(alpha: 0.5)),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (var r = 0; r < 7; r++)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            for (var c = 0; c < 24; c++)
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: grid[r][c] == 0
                                      ? kSub.withValues(alpha: 0.05)
                                      : kPurple.withValues(
                                          alpha: (grid[r][c] / maxCell)
                                              .clamp(0.2, 1.0)),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 24),
              Text('12am',
                  style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: kSub.withValues(alpha: 0.4))),
              Text('6am',
                  style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: kSub.withValues(alpha: 0.4))),
              Text('12pm',
                  style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: kSub.withValues(alpha: 0.4))),
              Text('6pm',
                  style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: kSub.withValues(alpha: 0.4))),
              Text('11pm',
                  style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: kSub.withValues(alpha: 0.4))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaskTypeHeatmap(List<HabitLog> logs, List<TaskModel> tasks) {
    final taskMap = {for (final task in tasks) task.id: task};
    final totals = <String, num>{};
    for (final log in logs) {
      final task = taskMap[log.relatedTaskId];
      final label =
          task == null ? _triggerLabel(log.trigger) : _taskTypeLabel(task.type);
      totals[label] = (totals[label] ?? 0) + (log.quantity ?? 0);
    }

    if (totals.isEmpty) return const SizedBox.shrink();

    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxVal = sorted.first.value;

    return LiquidCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Task-Type Heatmap',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w900, color: kInk)),
          const SizedBox(height: 14),
          for (final entry in sorted.take(4))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: kInk)),
                      Text('${entry.value.round()} min',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: kPurple.withValues(alpha: 0.8))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 8,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: kSub.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (entry.value / maxVal).clamp(0.02, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: kPurple,
                          borderRadius: BorderRadius.circular(4),
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

  String _taskTypeLabel(TaskType type) {
    switch (type) {
      case TaskType.skinCare:
        return 'Skin care';
      case TaskType.eating:
        return 'Eating';
      case TaskType.classBlock:
        return 'Class';
      case TaskType.fixed:
        return 'Fixed block';
      case TaskType.custom:
        return 'Custom task';
      case TaskType.habitBlock:
        return 'Habit block';
    }
  }

  String _triggerLabel(String? trigger) {
    switch (trigger) {
      case 'late_start':
        return 'Late Start (Auto)';
      case 'no_show':
        return 'No Show (Auto)';
      case null:
      case '':
        return 'Other';
      default:
        return trigger;
    }
  }

  Widget _buildIdentityDamage(List<HabitLog> logs, List<TaskModel> tasks) {
    final taskMap = {for (var t in tasks) t.id: t};
    final damage = <String, int>{};

    for (final log in logs) {
      final task = taskMap[log.relatedTaskId];
      if (task != null) {
        for (final tag in task.identityTags) {
          damage[tag] = (damage[tag] ?? 0) + (log.quantity?.round() ?? 0);
        }
      }
    }

    if (damage.isEmpty) {
      return LiquidCard(
        radius: 22,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.shield_outlined, color: kCoral, size: 18),
                SizedBox(width: 8),
                Text('Identity Damage',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: kInk)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'No identity damage detected yet. Keep up the momentum!',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: kSub.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    final sortedDamage = damage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return LiquidCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_outlined, color: kCoral, size: 18),
              SizedBox(width: 8),
              Text('Identity Damage',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w900, color: kInk)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Procrastination delays the person you want to become. These identities were put on hold this week:',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: kSub.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sortedDamage.map((entry) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: kCoral.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kCoral.withValues(alpha: 0.1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: kCoral,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${entry.value}m',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: kCoral.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _showLogModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ProcrastinationLogModal(habit: habit),
    );
  }

  static DateTime _dayStart(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static String _dateStr(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
}

class _LogItemCard extends ConsumerWidget {
  final HabitLog log;
  final HabitModel habit;

  const _LogItemCard({required this.log, required this.habit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuto = log.source == 'auto';

    return LiquidCard(
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (isAuto ? kAmber : kPurple).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isAuto ? Icons.auto_awesome_rounded : Icons.person_rounded,
                  color: isAuto ? kAmber : kPurple,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.trigger ?? 'Delay',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: kInk,
                      ),
                    ),
                    Text(
                      '${log.occurredAt.hour}:${log.occurredAt.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: kSub.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${log.quantity?.round() ?? 0}m',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: kInk,
                    ),
                  ),
                  if (isAuto)
                    GestureDetector(
                      onTap: () => ref
                          .read(habitServiceProvider)
                          .dismissSlip(habit.id, log.logId),
                      child: const Text(
                        'Dismiss',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: kCoral,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (log.avoidedWith != null || log.note != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kSub.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                log.avoidedWith ?? log.note ?? '',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: kInk.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProcrastinationLogModal extends ConsumerStatefulWidget {
  final HabitModel habit;

  const _ProcrastinationLogModal({required this.habit});

  @override
  ConsumerState<_ProcrastinationLogModal> createState() =>
      _ProcrastinationLogModalState();
}

class _ProcrastinationLogModalState
    extends ConsumerState<_ProcrastinationLogModal> {
  TaskModel? _selectedTask;
  String _avoidedWith = '';
  int _minutes = 15;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(todayTasksProvider);

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 30,
        top: 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Log Procrastination',
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w900, color: kInk),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          const Text(
            'WHAT DID YOU AVOID?',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w900, color: kSub),
          ),
          const SizedBox(height: 10),
          tasksAsync.when(
            data: (tasks) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: kSub.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<TaskModel>(
                  value: _selectedTask,
                  hint: const Text('Select a task (optional)'),
                  isExpanded: true,
                  items: tasks
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.title),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedTask = v),
                ),
              ),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text('Failed to load tasks'),
          ),
          const SizedBox(height: 20),
          const Text(
            'WHAT DID YOU DO INSTEAD?',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w900, color: kSub),
          ),
          const SizedBox(height: 10),
          TextField(
            onChanged: (v) => setState(() => _avoidedWith = v),
            decoration: InputDecoration(
              hintText: 'e.g., scrolled TikTok, cleaned kitchen',
              filled: true,
              fillColor: kSub.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'FOR HOW LONG? ($_minutes min)',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w900, color: kSub),
          ),
          Slider(
            value: _minutes.toDouble(),
            min: 5,
            max: 120,
            divisions: 23,
            activeColor: kPurple,
            inactiveColor: kPurple.withValues(alpha: 0.1),
            onChanged: (v) => setState(() => _minutes = v.round()),
          ),
          const SizedBox(height: 24),
          LiquidButton(
            label: _submitting ? 'Logging...' : 'Log Instance',
            color: kPurple,
            onTap: _submitting ? null : _submit,
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await ref.read(habitServiceProvider).logProcrastinationSlip(
            habitId: widget.habit.id,
            trigger: _selectedTask?.title ?? 'custom',
            minutesLost: _minutes,
            relatedTaskId: _selectedTask?.id,
            avoidedWith: _avoidedWith,
            source: 'manual',
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
