// lib/views/habits/variants/mindful_eating_tracker_view.dart
//
// Mindful Eating tracker variant — shown when a habit has trackerType 'junk_food'
// or 'mindful_eating' AND profile/main.sensitiveContext.eatingDisorderFlag is true.
// Also honors the legacy eatingDisorderHistory field name via provider aliasing.
//
// Requirements (UF §10.6 / Task 7.6):
//   - No counts, no goals, no streaks, no money-saved display.
//   - mealMood slider 1–10 ("rushed/stressed → nourishing/calm") + optional note.
//   - Firestore write: users/{uid}/habit_logs/{logId}  (quantity = mealMood, logType: 'good')
//   - Event: good_habit_logged
//
// MindfulEatingLogSheet is public so tracker_tab.dart can import and reuse it.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus2/core/constants/event_names.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/core/utils/uuid_generator.dart';
import 'package:optivus2/models/habit_log_model.dart';
import 'package:optivus2/models/habit_model.dart';
import 'package:optivus2/providers/onboarding_provider.dart';

// ═════════════════════════════════════════════════════════════════════════════
// TRACKER VIEW — 7-day mood chart + Log Mood CTA
// ═════════════════════════════════════════════════════════════════════════════

class MindfulEatingTrackerView extends ConsumerWidget {
  final HabitModel habit;

  const MindfulEatingTrackerView({super.key, required this.habit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const _MeError(message: 'Not authenticated.');
    }

    final eatFlag = ref.watch(eatingDisorderFlagProvider).valueOrNull ?? false;

    // We check the flag inside the view. If flag is false, we show the standard Junk Food dashboard.
    // This view is used in HabitDetailScreen for both 'junk_food' and 'mindful_eating' trackerTypes.
    if (!eatFlag &&
        (habit.trackerType == 'junk_food' ||
            habit.trackerType == 'nutrition')) {
      return _JunkFoodDashboard(habit: habit);
    }

    final start = _dayStart(DateTime.now().subtract(const Duration(days: 6)));
    final logsStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('habit_logs')
        .where('habitId', isEqualTo: habit.id)
        .where('occurredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: logsStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator(color: kMint)),
          );
        }
        if (snap.hasError) {
          return _MeError(message: snap.error.toString());
        }
        final logs = (snap.data?.docs.map(HabitLog.fromFirestore).toList() ??
                const <HabitLog>[])
            .where((log) => log.logType == 'good' && log.unit == 'mood')
            .toList();
        return Column(
          children: [
            _SensitivityToggle(active: true, habit: habit),
            const SizedBox(height: 14),
            _MindfulEatingBody(habit: habit, logs: logs),
          ],
        );
      },
    );
  }

  static DateTime _dayStart(DateTime d) => DateTime(d.year, d.month, d.day);
}

// ─────────────────────────────────────────────────────────────────────────────
// SENSITIVITY TOGGLE — allows switching between Mindful Eating and Junk Food
// ─────────────────────────────────────────────────────────────────────────────

class _SensitivityToggle extends ConsumerWidget {
  final bool active;
  final HabitModel habit;

  const _SensitivityToggle({required this.active, required this.habit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LiquidCard(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      tint: kAmber.withValues(alpha: 0.05),
      child: Row(
        children: [
          Icon(
            active
                ? Icons.health_and_safety_rounded
                : Icons.info_outline_rounded,
            color: active ? kMint : kAmber,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active ? 'Mindful Eating Mode' : 'Standard Tracking',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: kInk,
                  ),
                ),
                Text(
                  active
                      ? 'Focus on nourishment and calm'
                      : 'Track slips, costs, and triggers',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kSub.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _toggle(context, ref),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: active ? kSub : kMint,
            ),
            child: Text(
              active ? 'Opt-out' : 'Enable',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    if (active) {
      // Friction confirmation modal (UF §10.6)
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text(
            'Disable Mindful Eating?',
            style: TextStyle(fontWeight: FontWeight.w900, color: kInk),
          ),
          content: const Text(
            'This will re-enable slip counters, goal targets, and cost tracking for food habits. We recommend this only if you feel your relationship with food is currently stable.',
            style: TextStyle(fontSize: 15, height: 1.4, color: kInk),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep Mindful Mode',
                  style: TextStyle(color: kSub, fontWeight: FontWeight.w700)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Disable',
                  style: TextStyle(color: kCoral, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        ref.read(onboardingProvider.notifier).forceDisableMindfulEating();
      }
    } else {
      ref.read(onboardingProvider.notifier).enableMindfulEating();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// JUNK FOOD DASHBOARD — slips, cost saved, 7-day chart, triggers
// ─────────────────────────────────────────────────────────────────────────────

class _JunkFoodDashboard extends ConsumerWidget {
  final HabitModel habit;

  const _JunkFoodDashboard({required this.habit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const _MeError(message: 'Not authenticated.');

    final start = _dayStart(DateTime.now().subtract(const Duration(days: 6)));
    final logsStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('habit_logs')
        .where('habitId', isEqualTo: habit.id)
        .where('occurredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: logsStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: kAmber));
        }
        final logs = (snap.data?.docs.map(HabitLog.fromFirestore).toList() ??
                const <HabitLog>[])
            .where((log) => log.logType == 'slip')
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SensitivityToggle(active: false, habit: habit),
            const SizedBox(height: 14),
            _JunkFoodHero(habit: habit, logs: logs),
            const SizedBox(height: 14),
            LiquidButton(
              label: 'Log Junk Food',
              color: kCoral,
              leading: const Icon(Icons.add_alert_rounded,
                  color: Colors.white, size: 20),
              onTap: habit.state == HabitState.active
                  ? () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => JunkFoodLogSheet(habit: habit),
                      )
                  : null,
            ),
            const SizedBox(height: 14),
            _JunkFoodWeeklyChart(logs: logs),
            const SizedBox(height: 14),
            _TriggerHeatmap(logs: logs),
          ],
        );
      },
    );
  }

  static DateTime _dayStart(DateTime d) => DateTime(d.year, d.month, d.day);
}

class _JunkFoodHero extends StatelessWidget {
  final HabitModel habit;
  final List<HabitLog> logs;

  const _JunkFoodHero({required this.habit, required this.logs});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayStr = _dateStr(now);
    final todayLogs = logs.where((l) => _dateStr(l.occurredAt) == todayStr);
    final todaySlips = todayLogs.fold<num>(0, (s, l) => s + (l.quantity ?? 1));
    final baseline = habit.baselinePerDay ?? 0;

    final costPerUnit = habit.costPerUnit ?? 0;
    final savedToday = (baseline - todaySlips).clamp(0, baseline) * costPerUnit;

    return LiquidCard(
      radius: 22,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: kCoral.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(habit.emoji ?? '🍔',
                      style: const TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text('Junk Food',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: kInk)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$todaySlips',
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: kCoral)),
                  Text('slips today',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: kSub.withValues(alpha: 0.7))),
                ],
              ),
            ],
          ),
          if (costPerUnit > 0) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.savings_rounded, color: kAmber, size: 20),
                const SizedBox(width: 10),
                Text(
                  '\$${savedToday.toStringAsFixed(2)} saved today',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: kInk,
                  ),
                ),
                const Spacer(),
                Text(
                  'vs baseline ($baseline/day)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: kSub.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _dateStr(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

class _JunkFoodWeeklyChart extends StatelessWidget {
  final List<HabitLog> logs;

  const _JunkFoodWeeklyChart({required this.logs});

  @override
  Widget build(BuildContext context) {
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
                                          ? [
                                              kCoral,
                                              kCoral.withValues(alpha: 0.5)
                                            ]
                                          : [
                                              kCoral.withValues(alpha: 0.35),
                                              kCoral.withValues(alpha: 0.15)
                                            ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            dayLabels[
                                (DateTime.parse(entries[i].key).weekday - 1) %
                                    7],
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
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _dateStr(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

class _TriggerHeatmap extends StatelessWidget {
  final List<HabitLog> logs;

  const _TriggerHeatmap({required this.logs});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final grid = List.generate(7, (_) => List.filled(24, 0));
    for (final log in logs) {
      final diff = now.difference(log.occurredAt).inDays;
      if (diff < 0 || diff > 6) continue;
      final row = 6 - diff;
      grid[row][log.occurredAt.hour] += (log.quantity ?? 1).toInt();
    }
    final maxCell = grid.expand((r) => r).fold<int>(1, (m, v) => v > m ? v : m);

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
            child: Row(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (i) {
                    final d = now.subtract(Duration(days: 6 - i));
                    return SizedBox(
                      height: 12,
                      width: 20,
                      child: Text(
                        [
                          'M',
                          'T',
                          'W',
                          'T',
                          'F',
                          'S',
                          'S'
                        ][(d.weekday - 1) % 7],
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// JUNK FOOD LOG SHEET — emoji quick-add, trigger picker, photo, cost
// ═════════════════════════════════════════════════════════════════════════════

class JunkFoodLogSheet extends ConsumerStatefulWidget {
  final HabitModel habit;

  const JunkFoodLogSheet({super.key, required this.habit});

  @override
  ConsumerState<JunkFoodLogSheet> createState() => _JunkFoodLogSheetState();
}

class _JunkFoodLogSheetState extends ConsumerState<JunkFoodLogSheet> {
  String? _selectedEmoji;
  String? _selectedTrigger;
  bool _hasLocalPhoto = false;
  final _noteController = TextEditingController();
  bool _isLogging = false;

  final List<Map<String, String>> _emojiChips = [
    {'emoji': '🍕', 'label': 'Pizza'},
    {'emoji': '🍔', 'label': 'Burger'},
    {'emoji': '🥤', 'label': 'Soda'},
    {'emoji': '🍫', 'label': 'Sweets'},
    {'emoji': '🍟', 'label': 'Fries'},
    {'emoji': '🌯', 'label': 'Fast food'},
    {'emoji': '🍿', 'label': 'Snacks'},
  ];

  final List<String> _triggers = [
    'Cravings',
    'Stress',
    'Social',
    'Lazy',
    'Tired',
    'Other'
  ];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLogging) return;
    setState(() => _isLogging = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Not authenticated');

      final logId = generateId();
      final now = DateTime.now();
      final noteText = _noteController.text.trim();
      final finalNote = '${_selectedEmoji ?? ""} $noteText'.trim();

      final logData = <String, dynamic>{
        'logId': logId,
        'habitId': widget.habit.id,
        'habitKind': 'bad',
        'logType': 'slip',
        'occurredAt': Timestamp.fromDate(now),
        'loggedAt': Timestamp.fromDate(now),
        'quantity': 1,
        'unit': 'slip',
        if (_selectedTrigger != null) 'trigger': _selectedTrigger,
        if (_selectedTrigger != null) 'triggerTag': _selectedTrigger,
        if (_selectedTrigger != null) 'trigger_tag': _selectedTrigger,
        if (widget.habit.costPerUnit != null)
          'costPerUnit': widget.habit.costPerUnit,
        if (widget.habit.costPerUnit != null) 'cost': widget.habit.costPerUnit,
        if (_hasLocalPhoto) 'hasLocalPhoto': true,
        if (_hasLocalPhoto) 'photoStoragePolicy': 'local_only',
        if (finalNote.isNotEmpty) 'note': finalNote,
        'source': 'manual',
        'schemaVersion': 1,
      };

      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      batch.set(
        firestore
            .collection('users')
            .doc(uid)
            .collection('habit_logs')
            .doc(logId),
        logData,
      );

      await batch.commit();

      await ref.read(eventServiceProvider).emit(
        eventName: EventNames.badHabitSlipLogged,
        source: 'manual',
        payload: {
          'habitId': widget.habit.id,
          'habitName': widget.habit.name,
          'logId': logId,
          'amount': 1,
          'unit': 'slip',
          'trigger': _selectedTrigger,
          if (_selectedTrigger != null) 'triggerTag': _selectedTrigger,
          if (widget.habit.costPerUnit != null)
            'cost': widget.habit.costPerUnit,
          if (_hasLocalPhoto) 'hasLocalPhoto': true,
          'ts': now.toIso8601String(),
        },
      );

      HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Log failed: $e'), backgroundColor: kCoral),
        );
      }
    } finally {
      if (mounted) setState(() => _isLogging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(24, 10, 24, 24 + bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LiquidSheetHandle(),
            const SizedBox(height: 16),
            const Text(
              'Log Junk Food Slip',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w900, color: kInk),
            ),
            const SizedBox(height: 20),

            // Emoji Chips
            const Text('What was it?',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: kSub)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _emojiChips.map((chip) {
                final selected = _selectedEmoji == chip['emoji'];
                return GestureDetector(
                  onTap: () => setState(
                      () => _selectedEmoji = selected ? null : chip['emoji']),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? kCoral.withValues(alpha: 0.15)
                          : kSub.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected ? kCoral : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Text('${chip['emoji']} ${chip['label']}',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: selected ? kCoral : kInk)),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // Trigger Picker
            const Text('What triggered it?',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: kSub)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _triggers.map((trigger) {
                final selected = _selectedTrigger == trigger;
                return GestureDetector(
                  onTap: () => setState(
                      () => _selectedTrigger = selected ? null : trigger),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? kAmber.withValues(alpha: 0.15)
                          : kSub.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected ? kAmber : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Text(trigger,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: selected ? kAmber : kInk)),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // Photo & Cost Row
            Row(
              children: [
                Expanded(
                  child: LiquidButton.outline(
                    label: _hasLocalPhoto ? 'Photo Local' : 'Add Photo',
                    leading: const Icon(Icons.camera_alt_rounded, size: 18),
                    onTap: () {
                      setState(() => _hasLocalPhoto = !_hasLocalPhoto);
                      if (_hasLocalPhoto) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Photo marked local-only. No image is uploaded or shared.',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                if (widget.habit.costPerUnit != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: kSub.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.attach_money_rounded,
                            size: 18, color: kInk),
                        Text(
                          '${widget.habit.costPerUnit}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 18),

            LiquidTextField(
              hint: 'Note (optional)',
              prefixIcon: Icons.edit_note_rounded,
              controller: _noteController,
            ),

            const SizedBox(height: 24),

            LiquidButton(
              label: _isLogging ? 'Logging...' : 'Log Slip',
              color: kCoral,
              onTap: _isLogging ? null : _submit,
            ),
            const SizedBox(height: 10),
            LiquidButton.outline(
              label: 'Cancel',
              color: kSub,
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Body — composed of status card, 7-day chart, recent notes, insight, CTA
// ─────────────────────────────────────────────────────────────────────────────

class _MindfulEatingBody extends StatelessWidget {
  final HabitModel habit;
  final List<HabitLog> logs;

  const _MindfulEatingBody({required this.habit, required this.logs});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayStr = _dateStr(now);

    // Build 7-day mood map (quantity field = mealMood 1–10).
    // For days with multiple logs, keep the last recorded mood.
    final points = <String, num>{
      for (var i = 6; i >= 0; i--) _dateStr(now.subtract(Duration(days: i))): 0,
    };
    for (final log in logs) {
      final key = _dateStr(log.occurredAt);
      if (points.containsKey(key) && (log.quantity ?? 0) > 0) {
        points[key] = log.quantity!;
      }
    }

    final todayMood = points[todayStr] ?? 0;

    // Most recent logs that have a note (up to 3).
    final noted = logs
        .where((l) => l.note != null && l.note!.isNotEmpty)
        .toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MoodStatusCard(todayMood: todayMood),
        const SizedBox(height: 14),
        _MoodChartCard(points: points, todayStr: todayStr),
        if (noted.isNotEmpty) ...[
          const SizedBox(height: 14),
          _RecentNotesCard(notes: noted.take(3).toList()),
        ],
        const SizedBox(height: 14),
        const _InsightCard(),
        const SizedBox(height: 14),
        Builder(
          builder: (ctx) => LiquidButton(
            label: 'Log Mood',
            color: kMint,
            leading: const Icon(
              Icons.restaurant_menu_rounded,
              color: Colors.white,
              size: 20,
            ),
            onTap: habit.state == HabitState.active
                ? () => showModalBottomSheet<void>(
                      context: ctx,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => MindfulEatingLogSheet(habit: habit),
                    )
                : null,
          ),
        ),
      ],
    );
  }

  static String _dateStr(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Status card — today's mood score
// ─────────────────────────────────────────────────────────────────────────────

class _MoodStatusCard extends StatelessWidget {
  final num todayMood;

  const _MoodStatusCard({required this.todayMood});

  @override
  Widget build(BuildContext context) {
    final hasToday = todayMood > 0;

    return LiquidCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: kMint.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                _emojiForMood(todayMood.toDouble()),
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mindful Eating',
                  style: TextStyle(
                    color: kInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Today\'s check-in',
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
                hasToday ? '${todayMood.round()}/10' : '—',
                style: const TextStyle(
                  color: kMint,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                hasToday
                    ? _labelForMood(todayMood.toDouble())
                    : 'No check-in yet',
                style: TextStyle(
                  color: kSub.withValues(alpha: 0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _emojiForMood(double v) {
    if (v <= 0) return '🍽️';
    if (v <= 3) return '😔';
    if (v <= 5) return '😐';
    if (v <= 7) return '🙂';
    return '😊';
  }

  static String _labelForMood(double v) {
    if (v <= 3) return 'Rushed / stressed';
    if (v <= 6) return 'Neutral';
    return 'Nourishing / calm';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 7-day mood chart — bars colored by mood level
// ─────────────────────────────────────────────────────────────────────────────

class _MoodChartCard extends StatelessWidget {
  final Map<String, num> points;
  final String todayStr;

  const _MoodChartCard({required this.points, required this.todayStr});

  @override
  Widget build(BuildContext context) {
    final entries = points.entries.toList();
    final hasData = entries.any((e) => e.value > 0);

    return LiquidCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '7-day mood',
            style: TextStyle(
              color: kInk,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Rushed / stressed ← → Nourishing / calm',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: kSub.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 14),
          if (!hasData)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  'No mindful eating check-ins in the last 7 days.',
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
                                  heightFactor: entry.value == 0
                                      ? 0.06
                                      : (entry.value / 10)
                                          .clamp(0.06, 1.0)
                                          .toDouble(),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      color: entry.value == 0
                                          ? kSub.withValues(alpha: 0.10)
                                          : _barColor(entry.value.toDouble())
                                              .withValues(alpha: 0.75),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              entry.key.substring(8),
                              style: TextStyle(
                                color: entry.key == todayStr
                                    ? kInk
                                    : kSub.withValues(alpha: 0.72),
                                fontSize: 10,
                                fontWeight: entry.key == todayStr
                                    ? FontWeight.w900
                                    : FontWeight.w800,
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

  static Color _barColor(double v) {
    if (v <= 3) return kCoral;
    if (v <= 6) return kAmber;
    return kMint;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recent reflections — last 3 noted logs
// ─────────────────────────────────────────────────────────────────────────────

class _RecentNotesCard extends StatelessWidget {
  final List<HabitLog> notes;

  const _RecentNotesCard({required this.notes});

  @override
  Widget build(BuildContext context) {
    return LiquidCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent reflections',
            style: TextStyle(
              color: kInk,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          ...notes.map((log) {
            final h = log.occurredAt.hour.toString().padLeft(2, '0');
            final m = log.occurredAt.minute.toString().padLeft(2, '0');
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$h:$m',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: kSub.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      log.note!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: kInk,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI insight card — static until Task 11.x wires live AI copy
// ─────────────────────────────────────────────────────────────────────────────

class _InsightCard extends StatelessWidget {
  const _InsightCard();

  @override
  Widget build(BuildContext context) {
    return LiquidCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome_rounded, color: kMint, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'AI interpretation placeholder: keep food feedback neutral and pattern-focused, never punitive.',
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

// ═════════════════════════════════════════════════════════════════════════════
// MINDFUL EATING LOG SHEET — public; imported by tracker_tab.dart
//
// Writes a mood snap (mealMood 1–10) to:
//   users/{uid}/habit_logs/{logId}           (canonical)
//   users/{uid}/habits/{id}/logs/{date}/items/{logId}  (legacy dual-write)
//
// Emits: good_habit_logged
// Never shows: calorie count, slip count, goal progress, streak, money saved.
// ═════════════════════════════════════════════════════════════════════════════

class MindfulEatingLogSheet extends ConsumerStatefulWidget {
  final HabitModel habit;

  const MindfulEatingLogSheet({super.key, required this.habit});

  @override
  ConsumerState<MindfulEatingLogSheet> createState() =>
      _MindfulEatingLogSheetState();
}

class _MindfulEatingLogSheetState extends ConsumerState<MindfulEatingLogSheet> {
  double _moodValue = 5.0;
  final _noteController = TextEditingController();
  bool _isLogging = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _moodEmoji(double v) {
    if (v <= 2) return '😖';
    if (v <= 4) return '😟';
    if (v <= 6) return '😐';
    if (v <= 8) return '🙂';
    return '😊';
  }

  static String _moodLabel(double v) {
    if (v <= 2) return 'Very rushed / stressed';
    if (v <= 4) return 'Somewhat rushed';
    if (v <= 6) return 'Neutral';
    if (v <= 8) return 'Fairly nourishing';
    return 'Nourishing / calm';
  }

  static String _dateStr(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_isLogging) return;
    setState(() => _isLogging = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Not authenticated');

      final habitId = widget.habit.id;
      final logId = generateId();
      final now = DateTime.now();
      final moodSnap = _moodValue.roundToDouble();
      final note = _noteController.text.trim();

      final logData = <String, dynamic>{
        'logId': logId,
        'habitId': habitId,
        'habitKind': widget.habit.kind.name,
        // logType 'good' — mood snap is a positive check-in, not a slip.
        'logType': 'good',
        'occurredAt': Timestamp.fromDate(now),
        'loggedAt': Timestamp.fromDate(now),
        'quantity': moodSnap, // mealMood 1–10
        'unit': 'mood',
        if (note.isNotEmpty) 'note': note,
        'source': 'manual',
        'schemaVersion': 1,
      };

      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      // Canonical path
      batch.set(
        firestore
            .collection('users')
            .doc(uid)
            .collection('habit_logs')
            .doc(logId),
        logData,
      );

      // Legacy nested copy (dual-write for backward compat)
      batch.set(
        firestore
            .collection('users')
            .doc(uid)
            .collection('habits')
            .doc(habitId)
            .collection('logs')
            .doc(_dateStr(now))
            .collection('items')
            .doc(logId),
        logData,
      );

      await batch.commit();

      // Emit event after successful batch commit.
      // We write directly to Firestore above (bypassing HabitService.logGood)
      // because logGood enforces kind == good; this habit is kind == bad.
      // Pattern is consistent with SmokingTrackerView and TrackerVariantBase.
      await ref.read(eventServiceProvider).emit(
        eventName: EventNames.goodHabitLogged,
        source: 'manual',
        payload: {
          'habitId': habitId,
          'habitName': widget.habit.name,
          'logId': logId,
          'amount': moodSnap,
          'unit': 'mood',
          'mealMood': moodSnap,
          'ts': now.toIso8601String(),
          'occurredAt': now.toIso8601String(),
          'loggedAt': now.toIso8601String(),
          if (note.isNotEmpty) 'note': note,
          'source': 'manual',
        },
      );

      HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Log failed: $e'),
            backgroundColor: kCoral,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLogging = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(24, 10, 24, 24 + bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LiquidSheetHandle(),
            const SizedBox(height: 16),

            // ── Header ─────────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: kMint.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text('🍽️', style: TextStyle(fontSize: 22)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'How was that meal?',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: kInk,
                        ),
                      ),
                      Text(
                        widget.habit.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: kSub.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // ── Emoji + label ───────────────────────────────────────────────
            Center(
              child: Text(
                _moodEmoji(_moodValue),
                style: const TextStyle(fontSize: 44),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _moodLabel(_moodValue),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: kInk,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Slider ─────────────────────────────────────────────────────
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: kMint,
                inactiveTrackColor: kMint.withValues(alpha: 0.18),
                thumbColor: kMint,
                overlayColor: kMint.withValues(alpha: 0.12),
                trackHeight: 6,
              ),
              child: Slider(
                value: _moodValue,
                min: 1,
                max: 10,
                divisions: 9,
                label: _moodValue.round().toString(),
                onChanged:
                    _isLogging ? null : (v) => setState(() => _moodValue = v),
              ),
            ),
            Row(
              children: [
                Text(
                  'Rushed / Stressed',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: kCoral.withValues(alpha: 0.8),
                  ),
                ),
                const Spacer(),
                Text(
                  'Nourishing / Calm',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: kMint.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // ── Note field ──────────────────────────────────────────────────
            LiquidTextField(
              hint: 'Note (optional)',
              prefixIcon: Icons.edit_note_rounded,
              controller: _noteController,
            ),

            const SizedBox(height: 22),

            // ── Submit ──────────────────────────────────────────────────────
            LiquidButton(
              label: _isLogging ? 'Logging...' : 'Save Mood Snap',
              color: kMint,
              leading: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 19,
              ),
              onTap: _isLogging ? null : _submit,
            ),
            const SizedBox(height: 10),
            LiquidButton.outline(
              label: 'Cancel',
              color: kSub,
              height: 48,
              onTap: _isLogging ? null : () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error widget
// ─────────────────────────────────────────────────────────────────────────────

class _MeError extends StatelessWidget {
  final String message;

  const _MeError({required this.message});

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
