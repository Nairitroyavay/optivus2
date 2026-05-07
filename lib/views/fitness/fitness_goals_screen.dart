// lib/views/fitness/fitness_goals_screen.dart
//
// Goal management — list active goals with progress rings,
// create new goals, edit/archive existing ones.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/models/fitness_goal_model.dart';
import 'package:optivus2/services/firestore_service.dart';

class FitnessGoalsScreen extends ConsumerWidget {
  const FitnessGoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(fitnessGoalsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidBg(
        colors: const [Color(0xFF78FDFF), Color(0xFFE8FEFE)],
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
                child: Row(
                  children: [
                    LiquidIconBtn(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => context.pop(),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'Fitness Goals',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: kInk,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    LiquidIconBtn(
                      icon: Icons.add_rounded,
                      onTap: () => _showCreateGoalSheet(context, ref),
                    ),
                  ],
                ),
              ),

              // ── Body ──
              Expanded(
                child: goalsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: kAmber),
                  ),
                  error: (err, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: LiquidCard(
                        frosted: true,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: kCoral, size: 42),
                            const SizedBox(height: 12),
                            Text(
                              'Failed to load goals: $err',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: kSub.withValues(alpha: 0.7),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  data: (goals) {
                    if (goals.isEmpty) {
                      return _EmptyGoalsCard(
                        onAdd: () => _showCreateGoalSheet(context, ref),
                      );
                    }
                    return ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                      itemCount: goals.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, index) =>
                          _GoalCard(goal: goals[index], ref: ref),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateGoalSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateGoalSheet(ref: ref),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Goal Card with progress ring
// ─────────────────────────────────────────────────────────────────────────────

class _GoalCard extends StatelessWidget {
  final FitnessGoalModel goal;
  final WidgetRef ref;

  const _GoalCard({required this.goal, required this.ref});

  static const _goalTypeLabels = <String, String>{
    'weekly_distance': 'Weekly Distance',
    'weekly_activities': 'Weekly Activities',
    'weekly_duration': 'Weekly Duration',
    'monthly_distance': 'Monthly Distance',
  };

  @override
  Widget build(BuildContext context) {
    final pct = goal.progressPct;
    final label = _goalTypeLabels[goal.goalType] ?? goal.goalType;

    return LiquidCard(
      frosted: true,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Progress ring
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: pct,
                  strokeWidth: 5,
                  backgroundColor: kSub.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation(
                    pct >= 1.0 ? kMint : kBlue,
                  ),
                ),
                Text(
                  '${(pct * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: kInk,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: kInk,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${goal.currentValue.toStringAsFixed(1)} / '
                  '${goal.targetValue.toStringAsFixed(1)} ${goal.unit}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kSub.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          if (pct >= 1.0)
            const Icon(Icons.check_circle_rounded, color: kMint, size: 24),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Create Goal Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _CreateGoalSheet extends StatefulWidget {
  final WidgetRef ref;

  const _CreateGoalSheet({required this.ref});

  @override
  State<_CreateGoalSheet> createState() => _CreateGoalSheetState();
}

class _CreateGoalSheetState extends State<_CreateGoalSheet> {
  String _goalType = 'weekly_distance';
  final _targetController = TextEditingController();
  bool _saving = false;

  static const _goalTypes = [
    ('weekly_distance', 'Weekly Distance', 'km'),
    ('weekly_activities', 'Weekly Activities', 'count'),
    ('weekly_duration', 'Weekly Duration', 'minutes'),
    ('monthly_distance', 'Monthly Distance', 'km'),
  ];

  String get _unit =>
      _goalTypes.firstWhere((t) => t.$1 == _goalType).$3;

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF5FEFE),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24, 20, 24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: kSub.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'New Fitness Goal',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: kInk,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _goalTypes.map((t) {
              return ChoiceChip(
                label: Text(t.$2),
                selected: _goalType == t.$1,
                selectedColor: kBlue.withValues(alpha: 0.2),
                onSelected: (_) => setState(() => _goalType = t.$1),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          LiquidTextField(
            hint: 'Target value ($_unit)',
            prefixIcon: Icons.flag_rounded,
            controller: _targetController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
          ),
          const SizedBox(height: 20),
          LiquidButton(
            label: _saving ? 'Saving...' : 'Create Goal',
            leading: _saving
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2, color: kWhite,
                    ),
                  )
                : const Icon(Icons.check_rounded, color: kWhite),
            onTap: _saving ? null : _createGoal,
          ),
        ],
      ),
    );
  }

  Future<void> _createGoal() async {
    final targetStr = _targetController.text.trim();
    final target = double.tryParse(targetStr);
    if (target == null || target <= 0) return;

    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final goalId = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection(FirestoreService.kFitnessGoals)
          .doc()
          .id;

      final goal = FitnessGoalModel(
        goalId: goalId,
        goalType: _goalType,
        targetValue: target,
        unit: _unit,
        startDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection(FirestoreService.kFitnessGoals)
          .doc(goalId)
          .set(goal.toMap());

      // Emit event
      await widget.ref.read(fitnessEventServiceProvider).emitGoalCreated(
            goalId: goalId,
            goalType: _goalType,
            targetValue: target,
            unit: _unit,
          );

      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyGoalsCard extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyGoalsCard({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: LiquidCard(
          frosted: true,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: kMint.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.flag_rounded,
                  size: 32,
                  color: kMint.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No goals set',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: kInk,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Set a fitness goal to track your progress and stay motivated.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: kSub.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              LiquidButton(
                label: 'Create Goal',
                leading:
                    const Icon(Icons.add_rounded, color: kWhite, size: 20),
                onTap: onAdd,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
