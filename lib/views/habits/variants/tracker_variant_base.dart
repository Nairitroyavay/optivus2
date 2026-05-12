import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/models/day_summary_model.dart';
import 'package:optivus2/models/habit_log_model.dart';
import 'package:optivus2/models/habit_model.dart';
import 'package:optivus2/models/streak_model.dart';

enum VariantDataMode { habitLogs, dailySummaries }

class TrackerVariantView extends ConsumerWidget {
  final HabitModel habit;
  final String title;
  final String statusLabel;
  final String emptyLabel;
  final String insightCopy;
  final IconData icon;
  final Color accent;
  final VariantDataMode dataMode;
  final num defaultLogAmount;

  const TrackerVariantView({
    super.key,
    required this.habit,
    required this.title,
    required this.statusLabel,
    required this.emptyLabel,
    required this.insightCopy,
    required this.icon,
    required this.accent,
    this.dataMode = VariantDataMode.habitLogs,
    this.defaultLogAmount = 1,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const _VariantError(message: 'No authenticated user.');
    }

    final start = _dayStart(DateTime.now().subtract(const Duration(days: 6)));
    final logsStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('habit_logs')
        .where('habitId', isEqualTo: habit.id)
        .where('occurredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .snapshots();
    final streakStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('streaks')
        .doc(habit.id)
        .snapshots();
    final summariesStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('dailySummaries')
        .orderBy('date', descending: true)
        .limit(7)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: logsStream,
      builder: (context, logsSnap) {
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: streakStream,
          builder: (context, streakSnap) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: summariesStream,
              builder: (context, summariesSnap) {
                if (_loading(logsSnap) ||
                    _loading(streakSnap) ||
                    _loading(summariesSnap)) {
                  return const _VariantLoading();
                }
                final error =
                    logsSnap.error ?? streakSnap.error ?? summariesSnap.error;
                if (error != null) {
                  return _VariantError(message: error.toString());
                }

                final logs =
                    logsSnap.data?.docs.map(HabitLog.fromFirestore).toList() ??
                        const <HabitLog>[];
                final streakDoc = streakSnap.data;
                final streak = streakDoc != null && streakDoc.exists
                    ? Streak.fromFirestore(streakDoc)
                    : null;
                final summaries = summariesSnap.data?.docs
                        .map(DaySummary.fromFirestore)
                        .toList() ??
                    const <DaySummary>[];

                final points = dataMode == VariantDataMode.dailySummaries
                    ? _summaryPoints(summaries)
                    : _logPoints(logs);
                final todayValue = points[_dateString(DateTime.now())] ?? 0;

                HabitLog? latestLog;
                for (final log in logs) {
                  if (latestLog == null || log.occurredAt.isAfter(latestLog.occurredAt)) {
                    latestLog = log;
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _StatusCard(
                      title: title,
                      label: statusLabel,
                      value: _valueLabel(todayValue),
                      icon: icon,
                      accent: accent,
                      streak: streak,
                    ),
                    const SizedBox(height: 14),
                    _HistoryCard(
                      points: points,
                      accent: accent,
                      emptyLabel: emptyLabel,
                    ),
                    const SizedBox(height: 14),
                    _InsightCard(copy: insightCopy, accent: accent),
                    const SizedBox(height: 14),
                    LiquidButton(
                      label: habit.kind == HabitKind.good ? 'Log' : 'Log Slip',
                      color: accent,
                      leading: Icon(
                        habit.kind == HabitKind.good
                            ? Icons.add_rounded
                            : Icons.add_alert_rounded,
                        color: Colors.white,
                      ),
                      onTap: habit.state == HabitState.active
                          ? () => _log(context, ref)
                          : null,
                    ),
                    if (latestLog != null) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: () => _undoLatest(context, ref, latestLog!),
                          child: const Text('Undo latest log'),
                        ),
                      ),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  bool _loading(AsyncSnapshot<Object?> snap) =>
      snap.connectionState == ConnectionState.waiting && !snap.hasData;

  Future<void> _log(BuildContext context, WidgetRef ref) async {
    try {
      final service = ref.read(habitServiceProvider);
      if (habit.kind == HabitKind.good) {
        await service.logGood(
          habit.id,
          amount: defaultLogAmount,
          unit: habit.unit,
          source: 'ui',
        );
      } else {
        await service.logSlip(
          habit.id,
          count: defaultLogAmount,
          source: 'ui',
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Log failed: $e'),
            backgroundColor: kCoral,
          ),
        );
      }
    }
  }

  Future<void> _undoLatest(BuildContext context, WidgetRef ref, HabitLog log) async {
    try {
      await ref.read(habitServiceProvider).deleteLog(
            habit.id,
            log.logId,
            confirmDestructive: true,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Latest habit log removed.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to undo latest log: $e'),
            backgroundColor: kCoral,
          ),
        );
      }
    }
  }

  Map<String, num> _logPoints(List<HabitLog> logs) {
    final points = _emptySevenDayMap();
    for (final log in logs) {
      final key = _dateString(log.occurredAt);
      if (!points.containsKey(key)) continue;
      points[key] = (points[key] ?? 0) + (log.quantity ?? 1);
    }
    return points;
  }

  Map<String, num> _summaryPoints(List<DaySummary> summaries) {
    final points = _emptySevenDayMap();
    for (final summary in summaries) {
      if (!points.containsKey(summary.date)) continue;
      points[summary.date] = (summary.overallPct * 100).round();
    }
    return points;
  }

  Map<String, num> _emptySevenDayMap() {
    final now = DateTime.now();
    return {
      for (var i = 6; i >= 0; i--)
        _dateString(now.subtract(Duration(days: i))): 0,
    };
  }

  String _valueLabel(num value) {
    if (dataMode == VariantDataMode.dailySummaries) {
      return '${value.round()}%';
    }
    if (habit.kind == HabitKind.bad) {
      return '${value.round()} ${value == 1 ? 'slip' : 'slips'}';
    }
    return '$value ${habit.unit}';
  }

  static DateTime _dayStart(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static String _dateString(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

class _StatusCard extends StatelessWidget {
  final String title;
  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final Streak? streak;

  const _StatusCard({
    required this.title,
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: kInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
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
                value,
                style: TextStyle(
                  color: accent,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${streak?.currentCount ?? 0} day streak',
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

class _HistoryCard extends StatelessWidget {
  final Map<String, num> points;
  final Color accent;
  final String emptyLabel;

  const _HistoryCard({
    required this.points,
    required this.accent,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    final maxValue = points.values.fold<num>(0, (max, v) => v > max ? v : max);
    final hasData = maxValue > 0;
    final entries = points.entries.toList();

    return LiquidCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '7-day history',
            style: TextStyle(
              color: kInk,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          if (!hasData)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  emptyLabel,
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
                children: [
                  for (final entry in entries)
                    Expanded(
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
                                      (entry.value / maxValue).clamp(0.08, 1),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: accent.withValues(alpha: 0.72),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              entry.key.substring(8),
                              style: TextStyle(
                                color: kSub.withValues(alpha: 0.72),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
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

class _InsightCard extends StatelessWidget {
  final String copy;
  final Color accent;

  const _InsightCard({required this.copy, required this.accent});

  @override
  Widget build(BuildContext context) {
    return LiquidCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_rounded, color: accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              copy,
              style: const TextStyle(
                color: kInk,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VariantLoading extends StatelessWidget {
  const _VariantLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(child: CircularProgressIndicator(color: kAmber)),
    );
  }
}

class _VariantError extends StatelessWidget {
  final String message;

  const _VariantError({required this.message});

  @override
  Widget build(BuildContext context) {
    return LiquidCard(
      radius: 22,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: kCoral),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: kInk,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
