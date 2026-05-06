import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/models/habit_log_model.dart';
import 'package:optivus2/models/habit_model.dart';

class MoneySavingTrackerView extends ConsumerStatefulWidget {
  final HabitModel habit;

  const MoneySavingTrackerView({super.key, required this.habit});

  @override
  ConsumerState<MoneySavingTrackerView> createState() =>
      _MoneySavingTrackerViewState();
}

class _MoneySavingTrackerViewState
    extends ConsumerState<MoneySavingTrackerView> {
  HabitModel get habit => widget.habit;
  String? _lastAggregateSyncKey;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(
          child: Text('Not signed in', style: TextStyle(color: kInk)));
    }

    final now = DateTime.now();
    final start = _dayStart(now.subtract(const Duration(days: 6)));
    final todayStr = _dateStr(now);

    final habitsStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('habits')
        .where('state', isEqualTo: HabitState.active.name)
        .snapshots();

    final logsStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('habit_logs')
        .where('occurredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .snapshots();

    final todayMoneySavedStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('money_saved')
        .doc(todayStr)
        .snapshots();

    final goalsStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('money_savings_goals')
        .where('status', isEqualTo: 'active')
        .limit(1)
        .snapshots();

    return StreamBuilder(
      stream: habitsStream,
      builder: (context, habitsSnap) {
        return StreamBuilder(
          stream: logsStream,
          builder: (context, logsSnap) {
            return StreamBuilder(
              stream: todayMoneySavedStream,
              builder: (context, todayMoneySnap) {
                return StreamBuilder(
                  stream: goalsStream,
                  builder: (context, goalsSnap) {
                    if ((habitsSnap.connectionState ==
                                ConnectionState.waiting &&
                            !habitsSnap.hasData) ||
                        (logsSnap.connectionState == ConnectionState.waiting &&
                            !logsSnap.hasData)) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                            child: CircularProgressIndicator(color: kMint)),
                      );
                    }

                    final habitsList = habitsSnap.data?.docs
                            .map(_MoneyHabit.fromFirestore)
                            .toList() ??
                        [];
                    final costHabits =
                        habitsList.where((h) => h.costPerUnit > 0).toList();
                    final logs = logsSnap.data?.docs
                            .map(HabitLog.fromFirestore)
                            .toList() ??
                        [];
                    final todayMoneyData = todayMoneySnap.data?.data();
                    final goalData = goalsSnap.data?.docs.isNotEmpty == true
                        ? goalsSnap.data!.docs.first.data()
                        : null;
                    final goalId = goalsSnap.data?.docs.isNotEmpty == true
                        ? goalsSnap.data!.docs.first.id
                        : null;

                    return _buildContent(uid, costHabits, logs, todayMoneyData,
                        goalId, goalData);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildContent(
      String uid,
      List<_MoneyHabit> costHabits,
      List<HabitLog> logs,
      Map<String, dynamic>? todayMoneyData,
      String? goalId,
      Map<String, dynamic>? goalData) {
    final now = DateTime.now();
    final todayStr = _dateStr(now);
    final todayLogs =
        logs.where((l) => _dateStr(l.occurredAt) == todayStr).toList();

    num totalPassiveToday = 0;
    bool relapsePaused = false;
    final savingsBySourceType = <String, num>{
      'cigarettes': 0,
      'junk': 0,
      'alcohol': 0,
    };

    for (final h in costHabits) {
      final hLogs = todayLogs
          .where(
              (l) => l.habitId == h.id && l.logType == 'slip' && !l.isDismissed)
          .toList();
      final slipsToday = hLogs.fold<num>(0, (s, l) => s + (l.quantity ?? 1));
      final baseline = h.baselinePerDay;
      final cost = h.costPerUnit;

      if (slipsToday > baseline) {
        relapsePaused = true;
      }
      final savedUnits = baseline - slipsToday;
      final saved = savedUnits > 0 ? savedUnits * cost : 0;
      totalPassiveToday += saved;

      final type = _sourceCat(h.trackerType);
      savingsBySourceType[type] = (savingsBySourceType[type] ?? 0) + saved;
    }

    final depositsList = (todayMoneyData?['deposits'] as List?) ?? [];
    final todayDepositsTotal =
        depositsList.fold<num>(0, (s, d) => s + ((d['amount'] as num?) ?? 0));
    savingsBySourceType['manual'] = todayDepositsTotal;

    final totalSavingsToday = totalPassiveToday + todayDepositsTotal;
    _syncDailyAggregate(todayStr, costHabits, logs);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeroSavingsCard(totalSavingsToday, relapsePaused),
        const SizedBox(height: 14),
        _buildLogDepositButton(uid),
        const SizedBox(height: 14),
        _buildSourcesPie(savingsBySourceType),
        const SizedBox(height: 14),
        _buildGoalRing(uid, goalId, goalData, totalSavingsToday),
        const SizedBox(height: 14),
        _buildWeeklyChart(costHabits, logs),
        const SizedBox(height: 14),
        _buildReflectiveCard(costHabits, logs),
      ],
    );
  }

  Widget _buildHeroSavingsCard(num totalSavingsToday, bool relapsePaused) {
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
                color: kMint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.savings_rounded, color: kMint),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text('Savings',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900, color: kInk)),
            ),
          ]),
          const SizedBox(height: 16),
          if (relapsePaused)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Savings counter paused today.\nTomorrow starts fresh.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kSub.withValues(alpha: 0.8)),
              ),
            )
          else
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '\$${totalSavingsToday.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: kMint),
                    ),
                    Text(
                      'saved today',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: kSub.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
            ]),
        ],
      ),
    );
  }

  Widget _buildLogDepositButton(String uid) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => _DepositSheet(uid),
        );
      },
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: const Color(0xFFE9ECEF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFDEE2E6), width: 1.5),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline_rounded, size: 20, color: kInk),
            SizedBox(width: 8),
            Text('Log Deposit',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800, color: kInk)),
          ],
        ),
      ),
    );
  }

  Widget _buildSourcesPie(Map<String, num> sources) {
    final total = sources.values.fold<num>(0, (s, v) => s + v);
    if (total == 0) return const SizedBox();

    final labels = {
      'cigarettes': 'Cigarettes',
      'junk': 'Junk',
      'alcohol': 'Alcohol',
      'manual': 'Manual',
      'other': 'Other',
    };
    final colors = {
      'cigarettes': kCoral,
      'junk': kAmber,
      'alcohol': kPurple,
      'manual': kMint,
      'other': kSub,
    };

    final sorted = sources.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return LiquidCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sources',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w900, color: kInk)),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 88,
                height: 88,
                child: CustomPaint(
                  painter: _SavingsPiePainter(
                    sorted,
                    colors,
                    total,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: sorted.map((e) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                                color: colors[e.key] ?? kSub,
                                shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text(
                          '${labels[e.key] ?? 'Other'} \$${e.value.toStringAsFixed(0)}',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: kSub.withValues(alpha: 0.8)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoalRing(String uid, String? goalId,
      Map<String, dynamic>? goalData, num todaySaved) {
    if (goalData == null) {
      return LiquidCard(
        radius: 22,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.flag_rounded, color: kSub, size: 32),
            const SizedBox(height: 12),
            const Text('No Active Goal',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w900, color: kInk)),
            const SizedBox(height: 8),
            LiquidButton.outline(
              label: 'Set Goal',
              color: kMint,
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => _GoalSheet(uid),
                );
              },
            ),
          ],
        ),
      );
    }

    final name = goalData['name'] ?? 'Goal';
    final target = (goalData['targetAmount'] as num?) ?? 100;
    final current = (goalData['currentAmount'] as num?) ?? 0;
    final emoji = goalData['emoji'] ?? '🎯';
    final progress = (current / target).clamp(0.0, 1.0);

    return LiquidCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            height: 70,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: progress.toDouble(),
                  strokeWidth: 8,
                  backgroundColor: kSub.withValues(alpha: 0.1),
                  color: progress >= 1.0 ? kMint : kAmber,
                ),
                Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 24))),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: kInk)),
                const SizedBox(height: 4),
                Text(
                  '\$${current.toStringAsFixed(0)} / \$${target.toStringAsFixed(0)}',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kSub.withValues(alpha: 0.7)),
                ),
                if (progress >= 1.0)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('Goal reached! 🎉',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: kMint)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart(List<_MoneyHabit> costHabits, List<HabitLog> logs) {
    final now = DateTime.now();
    final points = <String, num>{};

    for (var i = 6; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final dStr = _dateStr(d);
      final dLogs = logs.where((l) => _dateStr(l.occurredAt) == dStr).toList();

      num dayPassive = 0;
      for (final h in costHabits) {
        final hLogs = dLogs
            .where((l) =>
                l.habitId == h.id && l.logType == 'slip' && !l.isDismissed)
            .toList();
        final slips = hLogs.fold<num>(0, (s, l) => s + (l.quantity ?? 1));
        final savedUnits = h.baselinePerDay - slips;
        if (savedUnits > 0) dayPassive += savedUnits * h.costPerUnit;
      }
      points[dStr] = dayPassive;
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
          const Text('Passive Savings (7 Days)',
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
                                      ? [kMint, kMint.withValues(alpha: 0.5)]
                                      : [
                                          kMint.withValues(alpha: 0.35),
                                          kMint.withValues(alpha: 0.15)
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

  Widget _buildReflectiveCard(
      List<_MoneyHabit> costHabits, List<HabitLog> logs) {
    final now = DateTime.now();

    num weekPassive = 0;
    for (var i = 6; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final dStr = _dateStr(d);
      final dLogs = logs.where((l) => _dateStr(l.occurredAt) == dStr).toList();
      for (final h in costHabits) {
        final hLogs = dLogs
            .where((l) =>
                l.habitId == h.id && l.logType == 'slip' && !l.isDismissed)
            .toList();
        final slips = hLogs.fold<num>(0, (s, l) => s + (l.quantity ?? 1));
        final savedUnits = h.baselinePerDay - slips;
        if (savedUnits > 0) weekPassive += savedUnits * h.costPerUnit;
      }
    }

    String item = 'a coffee';
    if (weekPassive >= 100) {
      item = 'a new outfit';
    } else if (weekPassive >= 50) {
      item = 'a book collection';
    } else if (weekPassive >= 20) {
      item = 'a nice meal';
    }

    return LiquidCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: kPurple, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('What your discipline bought you',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: kPurple)),
                const SizedBox(height: 4),
                Text(
                  'Your discipline saved \$${weekPassive.toStringAsFixed(0)} this week — enough for $item.',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kInk.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static DateTime _dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _dateStr(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String _sourceCat(String? trackerType) {
    if (trackerType == 'smoking' || trackerType == 'cigarettes') {
      return 'cigarettes';
    }
    if (trackerType == 'junk_food' ||
        trackerType == 'junk' ||
        trackerType == 'nutrition') {
      return 'junk';
    }
    if (trackerType == 'alcohol') return 'alcohol';
    return 'other';
  }

  void _syncDailyAggregate(
      String todayStr, List<_MoneyHabit> costHabits, List<HabitLog> logs) {
    final relevantLogs = logs
        .where((l) =>
            _dateStr(l.occurredAt) == todayStr &&
            l.logType == 'slip' &&
            !l.isDismissed)
        .map((l) => '${l.habitId}:${l.quantity ?? 1}:${l.logId}')
        .toList()
      ..sort();
    final habitKey = costHabits
        .map((h) =>
            '${h.id}:${h.baselinePerDay}:${h.costPerUnit}:${h.trackerType}')
        .toList()
      ..sort();
    final syncKey = '$todayStr|${habitKey.join(',')}|${relevantLogs.join(',')}';
    if (_lastAggregateSyncKey == syncKey) return;
    _lastAggregateSyncKey = syncKey;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref
            .read(habitServiceProvider)
            .syncMoneySavedAggregateForDate(DateTime.now()),
      );
    });
  }
}

class _MoneyHabit {
  final String id;
  final String name;
  final String trackerType;
  final num baselinePerDay;
  final num costPerUnit;

  const _MoneyHabit({
    required this.id,
    required this.name,
    required this.trackerType,
    required this.baselinePerDay,
    required this.costPerUnit,
  });

  factory _MoneyHabit.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final kind = data['kind'] as String? ?? HabitKind.good.name;
    if (kind != HabitKind.bad.name) {
      return _MoneyHabit(
        id: doc.id,
        name: data['name'] as String? ?? '',
        trackerType: 'other',
        baselinePerDay: 0,
        costPerUnit: 0,
      );
    }

    return _MoneyHabit(
      id: doc.id,
      name: data['name'] as String? ?? '',
      trackerType: data['tracker_type'] as String? ??
          data['trackerType'] as String? ??
          'other',
      baselinePerDay: data['baseline_per_day'] as num? ??
          data['baselinePerDay'] as num? ??
          0,
      costPerUnit:
          data['cost_per_unit'] as num? ?? data['costPerUnit'] as num? ?? 0,
    );
  }
}

class _SavingsPiePainter extends CustomPainter {
  final List<MapEntry<String, num>> entries;
  final Map<String, Color> colors;
  final num total;

  const _SavingsPiePainter(this.entries, this.colors, this.total);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()..style = PaintingStyle.fill;
    var start = -1.5708;

    for (final entry in entries) {
      final sweep = (entry.value / total) * 6.2832;
      paint.color = colors[entry.key] ?? kSub;
      canvas.drawArc(rect, start, sweep.toDouble(), true, paint);
      start += sweep;
    }

    paint.color = const Color(0xFFF7F8FB);
    canvas.drawCircle(
        size.center(Offset.zero), size.shortestSide * 0.28, paint);
  }

  @override
  bool shouldRepaint(covariant _SavingsPiePainter oldDelegate) {
    return oldDelegate.entries != entries ||
        oldDelegate.colors != colors ||
        oldDelegate.total != total;
  }
}

class _DepositSheet extends StatefulWidget {
  final String uid;
  const _DepositSheet(this.uid);

  @override
  State<_DepositSheet> createState() => _DepositSheetState();
}

class _DepositSheetState extends State<_DepositSheet> {
  final _amountCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();

  Future<void> _save() async {
    final amount = num.tryParse(_amountCtrl.text);
    final reason = _reasonCtrl.text.trim();
    if (amount == null || amount <= 0 || reason.isEmpty) return;
    final now = DateTime.now();
    final todayStr = _MoneySavingTrackerViewState._dateStr(now);

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .collection('money_saved')
        .doc(todayStr);

    final deposit = {
      'amount': amount,
      'reason': reason,
      'loggedAt': Timestamp.fromDate(now),
    };

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) {
        tx.update(ref, {
          'deposits': FieldValue.arrayUnion([deposit]),
          'totalDeposits': FieldValue.increment(amount),
          'totalSaved': FieldValue.increment(amount),
          'sources.manual': FieldValue.increment(amount),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        tx.set(ref, {
          'date': todayStr,
          'deposits': [deposit],
          'totalDeposits': amount,
          'totalPassive': 0,
          'totalSaved': amount,
          'sources': {
            'cigarettes': 0,
            'junk': 0,
            'alcohol': 0,
            'manual': amount,
          },
          'relapsePaused': false,
          'schemaVersion': 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });

    final goalsSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .collection('money_savings_goals')
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();
    if (goalsSnap.docs.isNotEmpty) {
      final goalRef = goalsSnap.docs.first.reference;
      await goalRef.update({
        'currentAmount': FieldValue.increment(amount),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF7F8FB),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LiquidSheetHandle(),
          const SizedBox(height: 16),
          const Text('Log Deposit',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w900, color: kInk)),
          const SizedBox(height: 20),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration:
                const InputDecoration(labelText: 'Amount', prefixText: '\$'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reasonCtrl,
            decoration: const InputDecoration(labelText: 'Reason'),
          ),
          const SizedBox(height: 20),
          LiquidButton(label: 'Save Deposit', onTap: _save),
        ],
      ),
    );
  }
}

class _GoalSheet extends StatefulWidget {
  final String uid;
  const _GoalSheet(this.uid);

  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  Future<void> _save() async {
    final amount = num.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0 || _nameCtrl.text.isEmpty) return;

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .collection('money_savings_goals')
        .doc();

    await ref.set({
      'name': _nameCtrl.text.trim(),
      'targetAmount': amount,
      'emoji': '🎯',
      'currentAmount': 0,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF7F8FB),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LiquidSheetHandle(),
          const SizedBox(height: 16),
          const Text('Set Savings Goal',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w900, color: kInk)),
          const SizedBox(height: 20),
          TextField(
            controller: _nameCtrl,
            decoration:
                const InputDecoration(labelText: 'Goal Name (e.g. New Laptop)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
                labelText: 'Target Amount', prefixText: '\$'),
          ),
          const SizedBox(height: 20),
          LiquidButton(label: 'Start Goal', onTap: _save),
        ],
      ),
    );
  }
}
