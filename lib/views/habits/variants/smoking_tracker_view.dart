import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus2/core/constants/event_names.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/models/habit_log_model.dart';
import 'package:optivus2/models/habit_model.dart';
import 'package:optivus2/models/scheduled_notification_model.dart';
import 'package:optivus2/models/streak_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Trigger tags for smoking slips
// ─────────────────────────────────────────────────────────────────────────────
const _kTriggers = [
  'Stress',
  'Boredom',
  'Social',
  'After meal',
  'Craving',
  'Other'
];

const _kTriggerColors = <String, Color>{
  'Stress': Color(0xFFFF6B6B),
  'Boredom': Color(0xFF748FFC),
  'Social': Color(0xFF51CF66),
  'After meal': Color(0xFFFFD43B),
  'Craving': Color(0xFFFF922B),
  'Other': Color(0xFFADB5BD),
};

// ─────────────────────────────────────────────────────────────────────────────
// Health milestones — unlocked by days clean
// ─────────────────────────────────────────────────────────────────────────────
class _Milestone {
  final Duration threshold;
  final String label;
  final String emoji;
  final String description;
  const _Milestone(this.threshold, this.label, this.emoji, this.description);
}

const _kMilestones = [
  _Milestone(Duration(minutes: 20), '20 minutes', '🫀', 'Blood pressure drops'),
  _Milestone(Duration(hours: 12), '12 hours', '🌬️', 'CO levels normalize'),
  _Milestone(Duration(hours: 24), '24 hours', '❤️', 'Heart attack risk drops'),
  _Milestone(Duration(hours: 72), '72 hours', '🫁', 'Breathing easier'),
  _Milestone(Duration(days: 7), '1 week', '👃', 'Taste & smell improve'),
  _Milestone(Duration(days: 14), '2 weeks', '🏃', 'Circulation improves'),
  _Milestone(Duration(days: 30), '1 month', '💨', 'Lung function up 30%'),
  _Milestone(Duration(days: 365), '1 year', '🏆', 'Heart disease risk halved'),
];

// Currency symbol lookup (avoids intl dependency)
const _kCurrencySymbols = <String, String>{
  'USD': '\$',
  'EUR': '€',
  'GBP': '£',
  'INR': '₹',
  'JPY': '¥',
  'CAD': 'C\$',
  'AUD': 'A\$',
  'CNY': '¥',
  'KRW': '₩',
};

class SmokingTrackerView extends ConsumerStatefulWidget {
  final HabitModel habit;
  const SmokingTrackerView({super.key, required this.habit});

  @override
  ConsumerState<SmokingTrackerView> createState() => _SmokingTrackerViewState();
}

class _SmokingTrackerViewState extends ConsumerState<SmokingTrackerView> {
  HabitModel get habit => widget.habit;
  bool _schedulingAlarm = false;

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
    final streakStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('streaks')
        .doc(habit.id)
        .snapshots();
    final alarmsStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('scheduled_notifications')
        .where('status', isEqualTo: NotifStatus.pending)
        .orderBy('scheduledFor')
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: logsStream,
      builder: (context, logsSnap) {
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: streakStream,
          builder: (context, streakSnap) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: alarmsStream,
              builder: (context, alarmsSnap) {
                if ((logsSnap.connectionState == ConnectionState.waiting &&
                        !logsSnap.hasData) ||
                    (streakSnap.connectionState == ConnectionState.waiting &&
                        !streakSnap.hasData) ||
                    (alarmsSnap.connectionState == ConnectionState.waiting &&
                        !alarmsSnap.hasData)) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child:
                        Center(child: CircularProgressIndicator(color: kAmber)),
                  );
                }
                final error =
                    logsSnap.error ?? streakSnap.error ?? alarmsSnap.error;
                if (error != null) {
                  return LiquidCard(
                    padding: const EdgeInsets.all(16),
                    child: Text('Error: $error',
                        style: const TextStyle(color: kCoral)),
                  );
                }

                final logs =
                    logsSnap.data?.docs.map(HabitLog.fromFirestore).toList() ??
                        const [];
                final streak =
                    (streakSnap.data != null && streakSnap.data!.exists)
                        ? Streak.fromFirestore(streakSnap.data!)
                        : null;
                final alarms = alarmsSnap.data?.docs
                        .map(ScheduledNotification.fromFirestore)
                        .where((n) =>
                            n.habitId == habit.id &&
                            n.category == NotifCategory.slipRecovery)
                        .toList() ??
                    const [];

                final today = DateTime.now();
                final todayStr = _dateStr(today);
                final todayLogs = logs
                    .where((l) => _dateStr(l.occurredAt) == todayStr)
                    .toList()
                  ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
                final todaySlips =
                    todayLogs.fold<num>(0, (s, l) => s + (l.quantity ?? 1));
                final baseline = habit.baselinePerDay ?? 0;
                final daysClean = streak?.currentCount ?? 0;
                final isRelapse = todaySlips > baseline;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHero(todaySlips, baseline, daysClean, isRelapse),
                    const SizedBox(height: 14),
                    _buildLogButton(),
                    const SizedBox(height: 14),
                    _buildTodayList(todayLogs),
                    const SizedBox(height: 14),
                    _buildWeeklyChart(logs),
                    const SizedBox(height: 14),
                    _buildHeatmap(logs),
                    const SizedBox(height: 14),
                    _buildMilestones(daysClean),
                    const SizedBox(height: 14),
                    _buildRecoveryAlarms(alarms, logs),
                    const SizedBox(height: 14),
                    _buildCoachButton(),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  // ── Hero Card ──────────────────────────────────────────────────────────────

  Widget _buildHero(
      num todaySlips, num baseline, int daysClean, bool isRelapse) {
    final costPerUnit = habit.costPerUnit ?? 0;
    final sym = _kCurrencySymbols[habit.currency] ?? habit.currency ?? '\$';
    final savedPerDay =
        (baseline - todaySlips).clamp(0, baseline) * costPerUnit;
    final totalSaved = daysClean * baseline * costPerUnit + savedPerDay;

    return LiquidCard(
      radius: 22,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: kCoral.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.smoke_free_rounded, color: kCoral),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text('Smoking',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900, color: kInk)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$todaySlips',
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: kCoral)),
                Text('of $baseline baseline',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: kSub.withValues(alpha: 0.7))),
              ],
            ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            _heroMetric(Icons.calendar_today_rounded, '$daysClean',
                'days clean', kMint),
            if (!isRelapse)
              _heroMetric(Icons.savings_rounded,
                  '$sym${totalSaved.toStringAsFixed(2)}', 'saved', kAmber),
            if (isRelapse)
              _heroMetric(Icons.warning_amber_rounded, 'Relapse', 'week',
                  kCoral.withValues(alpha: 0.6)),
          ]),
        ],
      ),
    );
  }

  Widget _heroMetric(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Row(children: [
        Icon(icon, size: 18, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w900, color: color)),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: kSub.withValues(alpha: 0.6))),
          ],
        ),
      ]),
    );
  }

  // ── Log Slip Button (gentle gray) ─────────────────────────────────────────

  Widget _buildLogButton() {
    final active = habit.state == HabitState.active;
    return GestureDetector(
      onTap: active ? () => _showTriggerPicker() : null,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: active ? const Color(0xFFE9ECEF) : const Color(0xFFF1F3F5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFDEE2E6), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_alert_rounded,
                size: 20, color: active ? kInk : kSub),
            const SizedBox(width: 8),
            Text('Log Slip',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: active ? kInk : kSub,
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _showTriggerPicker() async {
    final trigger = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TriggerPickerSheet(),
    );
    // trigger is null if dismissed without action, '' if skipped
    if (trigger == null) return;
    await _logSlipWithTrigger(trigger.isEmpty ? null : trigger);
  }

  Future<void> _logSlipWithTrigger(String? trigger) async {
    try {
      final service = ref.read(habitServiceProvider);
      await service.logSlip(habit.id, trigger: trigger, source: 'ui');
      HapticFeedback.mediumImpact();
      // Check slip streak (3+ in 30 min)
      await _checkSlipStreak();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Log failed: $e'), backgroundColor: kCoral),
        );
      }
    }
  }

  Future<void> _checkSlipStreak() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final cutoff = DateTime.now().subtract(const Duration(minutes: 30));
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('habit_logs')
        .where('habitId', isEqualTo: habit.id)
        .where('logType', isEqualTo: 'slip')
        .where('occurredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff))
        .get();
    final count = snap.docs
        .fold<num>(0, (s, d) => s + ((d.data()['quantity'] as num?) ?? 1));
    if (count >= 3) {
      await ref.read(eventServiceProvider).emit(
        eventName: EventNames.slipStreakDetected,
        source: 'app',
        payload: {'habitId': habit.id, 'count': count},
      );
    }
  }

  // ── Today's Log List ──────────────────────────────────────────────────────

  Widget _buildTodayList(List<HabitLog> todayLogs) {
    return LiquidCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Today's Log",
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w900, color: kInk)),
          const SizedBox(height: 10),
          if (todayLogs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                  child: Text(
                'No slips today — keep going 💪',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: kSub.withValues(alpha: 0.7)),
              )),
            )
          else
            ...todayLogs.map((log) {
              final h = log.occurredAt.hour.toString().padLeft(2, '0');
              final m = log.occurredAt.minute.toString().padLeft(2, '0');
              final tag = log.trigger;
              final tagColor = _kTriggerColors[tag] ?? kSub;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Text('$h:$m',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: kSub.withValues(alpha: 0.6))),
                  const SizedBox(width: 12),
                  if (tag != null && tag.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: tagColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(tag,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: tagColor)),
                    )
                  else
                    Text('No trigger',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: kSub.withValues(alpha: 0.5))),
                  const Spacer(),
                  Text('×${log.quantity ?? 1}',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: kInk.withValues(alpha: 0.5))),
                ]),
              );
            }),
        ],
      ),
    );
  }

  // ── Weekly Chart (bars going down) ────────────────────────────────────────

  Widget _buildWeeklyChart(List<HabitLog> logs) {
    final now = DateTime.now();
    final points = <String, num>{
      for (var i = 6; i >= 0; i--) _dateStr(now.subtract(Duration(days: i))): 0,
    };
    for (final log in logs) {
      final key = _dateStr(log.occurredAt);
      if (points.containsKey(key)) {
        points[key] = (points[key] ?? 0) + (log.quantity ?? 1);
      }
    }
    final maxVal = points.values.fold<num>(1, (m, v) => v > m ? v : m);
    final entries = points.entries.toList();
    final todayKey = _dateStr(now);
    final dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return LiquidCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Weekly Slips',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w900, color: kInk)),
          const SizedBox(height: 14),
          SizedBox(
            height: 80,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < entries.length; i++)
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
                            heightFactor: entries[i].value == 0
                                ? 0.06
                                : (entries[i].value / maxVal)
                                    .clamp(0.06, 1.0)
                                    .toDouble(),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: entries[i].key == todayKey
                                      ? [kCoral, kCoral.withValues(alpha: 0.5)]
                                      : [
                                          kCoral.withValues(alpha: 0.35),
                                          kCoral.withValues(alpha: 0.15)
                                        ],
                                ),
                              ),
                            ),
                          ),
                        )),
                        const SizedBox(height: 6),
                        Text(
                          dayLabels[
                              (DateTime.parse(entries[i].key).weekday - 1) % 7],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: entries[i].key == todayKey
                                ? FontWeight.w900
                                : FontWeight.w700,
                            color: entries[i].key == todayKey
                                ? kInk
                                : kSub.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Trigger Heatmap (7 days × 24 hours) ──────────────────────────────────

  Widget _buildHeatmap(List<HabitLog> logs) {
    // Build grid: row = day-of-week offset (0=6 days ago, 6=today), col = hour
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
          const Text('Trigger Heatmap',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w900, color: kInk)),
          const SizedBox(height: 4),
          Text('Last 7 days × hour of day',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: kSub.withValues(alpha: 0.6))),
          const SizedBox(height: 12),
          SizedBox(
            height: 7 * 14.0,
            child: Row(children: [
              // Day labels
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (i) {
                  final d = now.subtract(Duration(days: 6 - i));
                  return SizedBox(
                    height: 12,
                    width: 20,
                    child: Text(
                      ['M', 'T', 'W', 'T', 'F', 'S', 'S'][(d.weekday - 1) % 7],
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: kSub.withValues(alpha: 0.6)),
                    ),
                  );
                }),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  children: List.generate(7, (row) {
                    return SizedBox(
                      height: 14,
                      child: Row(
                        children: List.generate(24, (col) {
                          final v = grid[row][col];
                          final intensity =
                              v == 0 ? 0.0 : (v / maxCell).clamp(0.2, 1.0);
                          return Expanded(
                            child: Container(
                              margin: const EdgeInsets.all(0.5),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                color: v == 0
                                    ? kCoral.withValues(alpha: 0.06)
                                    : kCoral.withValues(alpha: intensity),
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  }),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // ── Health Milestones ─────────────────────────────────────────────────────

  Widget _buildMilestones(int daysClean) {
    final cleanDuration = Duration(days: daysClean);
    return LiquidCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Health Milestones',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w900, color: kInk)),
          const SizedBox(height: 12),
          ..._kMilestones.map((m) {
            final unlocked = cleanDuration >= m.threshold;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: unlocked
                        ? kMint.withValues(alpha: 0.14)
                        : kSub.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                      child: Text(
                    unlocked ? m.emoji : '🔒',
                    style: TextStyle(fontSize: unlocked ? 18 : 14),
                  )),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: unlocked ? kInk : kSub.withValues(alpha: 0.5),
                        )),
                    Text(m.description,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: unlocked
                              ? kSub.withValues(alpha: 0.7)
                              : kSub.withValues(alpha: 0.4),
                        )),
                  ],
                )),
                if (unlocked)
                  Icon(Icons.check_circle_rounded,
                      size: 20, color: kMint.withValues(alpha: 0.7)),
              ]),
            );
          }),
        ],
      ),
    );
  }

  // ── Recovery Alarms ──────────────────────────────────────────────────────

  Widget _buildRecoveryAlarms(
    List<ScheduledNotification> alarms,
    List<HabitLog> logs,
  ) {
    final highRiskAlarmAt = _nextHighRiskAlarmTime(logs);
    return LiquidCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.alarm_rounded,
                  color: kAmber.withValues(alpha: 0.7), size: 22),
              const SizedBox(width: 12),
              const Text('Recovery Alarms',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w900, color: kInk)),
            ],
          ),
          const SizedBox(height: 12),
          if (alarms.isEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  highRiskAlarmAt == null
                      ? 'Log a few slips with triggers so high-risk slots can be identified.'
                      : 'Schedule a pre-emptive nudge 5 min before your highest-risk slot.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kSub.withValues(alpha: 0.65),
                    height: 1.4,
                  ),
                ),
                if (highRiskAlarmAt != null) ...[
                  const SizedBox(height: 12),
                  LiquidButton.outline(
                    label:
                        _schedulingAlarm ? 'Scheduling...' : 'Schedule Nudge',
                    color: kAmber,
                    height: 44,
                    leading: Icon(
                      Icons.alarm_add_rounded,
                      color: kAmber.withValues(alpha: 0.75),
                      size: 18,
                    ),
                    onTap: _schedulingAlarm
                        ? null
                        : () => _scheduleRecoveryAlarm(highRiskAlarmAt),
                  ),
                ],
              ],
            )
          else
            ...alarms.take(3).map((alarm) {
              final local = alarm.scheduledFor.toLocal();
              final timeStr =
                  '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                          color: kAmber, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Nudge scheduled for $timeStr',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: kInk),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  DateTime? _nextHighRiskAlarmTime(List<HabitLog> logs) {
    if (logs.isEmpty) return null;

    final byHour = List<int>.filled(24, 0);
    for (final log in logs) {
      byHour[log.occurredAt.hour] += (log.quantity ?? 1).round();
    }

    var highRiskHour = 0;
    var highRiskCount = 0;
    for (var hour = 0; hour < byHour.length; hour++) {
      if (byHour[hour] > highRiskCount) {
        highRiskHour = hour;
        highRiskCount = byHour[hour];
      }
    }
    if (highRiskCount == 0) return null;

    final now = DateTime.now();
    var alarmAt = DateTime(now.year, now.month, now.day, highRiskHour)
        .subtract(const Duration(minutes: 5));
    if (!alarmAt.isAfter(now)) {
      final tomorrow = now.add(const Duration(days: 1));
      alarmAt =
          DateTime(tomorrow.year, tomorrow.month, tomorrow.day, highRiskHour)
              .subtract(const Duration(minutes: 5));
    }
    return alarmAt;
  }

  Future<void> _scheduleRecoveryAlarm(DateTime alarmAt) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _schedulingAlarm) return;

    setState(() => _schedulingAlarm = true);
    try {
      final scheduled = await ref
          .read(notificationServiceProvider)
          .scheduleSlipRecovery(
            uid: uid,
            habitId: habit.id,
            habitName: habit.name,
            scheduledFor: alarmAt,
            intentSuffix: 'preemptive_${alarmAt.hour}',
            title: 'High-risk smoking window',
            body: 'A trigger window may be coming up. Take a short reset now.',
          );

      if (scheduled) {
        await ref.read(eventServiceProvider).emit(
          eventName: EventNames.notificationScheduled,
          source: 'smoking_tracker',
          payload: {
            'category': NotifCategory.slipRecovery,
            'habitId': habit.id,
            'scheduledFor': alarmAt.toIso8601String(),
          },
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              scheduled
                  ? 'Recovery nudge scheduled.'
                  : 'Could not schedule this nudge.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to schedule nudge: $e'),
            backgroundColor: kCoral,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _schedulingAlarm = false);
    }
  }

  // ── Talk to Coach ─────────────────────────────────────────────────────────

  Widget _buildCoachButton() {
    return LiquidButton.outline(
      label: 'Talk to Coach',
      color: kPurple,
      height: 50,
      leading: Icon(Icons.chat_rounded,
          color: kPurple.withValues(alpha: 0.7), size: 20),
      onTap: () {
        final tabController = DefaultTabController.maybeOf(context);
        if (tabController != null) {
          tabController.animateTo(3);
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Open the Coach tab to continue.')),
        );
      },
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static DateTime _dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _dateStr(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

// ═════════════════════════════════════════════════════════════════════════════
// TRIGGER PICKER SHEET
// ═════════════════════════════════════════════════════════════════════════════

class _TriggerPickerSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF7F8FB),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LiquidSheetHandle(),
          const SizedBox(height: 16),
          const Text('What triggered this?',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w900, color: kInk)),
          const SizedBox(height: 6),
          Text('Optional — helps spot patterns',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: kSub.withValues(alpha: 0.6))),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _kTriggers.map((trigger) {
              final color = _kTriggerColors[trigger] ?? kSub;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context, trigger);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withValues(alpha: 0.25)),
                  ),
                  child: Text(trigger,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: color)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => Navigator.pop(context, ''),
            child: Text('Skip',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kSub.withValues(alpha: 0.6))),
          ),
        ],
      ),
    );
  }
}
