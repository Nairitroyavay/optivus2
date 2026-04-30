import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';

import '../../providers/goal_provider.dart';
import '../../providers/identity_provider.dart';

class GoalsTab extends ConsumerWidget {
  const GoalsTab({super.key});

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Color _parseColor(String? colorHex) {
    if (colorHex != null && colorHex.length == 7) {
      try {
        return Color(
          int.parse(colorHex.substring(1, 7), radix: 16) + 0xFF000000,
        );
      } catch (_) {}
    }
    return kMint;
  }

  IconData _iconForGoal(String? iconName) {
    switch (iconName) {
      case 'menu_book_rounded':
        return Icons.menu_book_rounded;
      case 'directions_run_rounded':
        return Icons.directions_run_rounded;
      case 'local_fire_department_rounded':
        return Icons.local_fire_department_rounded;
      default:
        return Icons.flag_rounded;
    }
  }

  String _updatedLabel(DateTime? date) {
    if (date == null) return 'Not computed yet';
    return 'Updated ${_formatDate(date)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalProvider);
    final identityAsync = ref.watch(identityProvider);

    final goals = goalsAsync.valueOrNull ?? [];
    final identity = identityAsync.valueOrNull;
    final progressPct = identity?.progressPct ?? 0;
    final identities = identity?.identities ?? const <String>[];
    final completedGoals = goals.where((goal) => goal.isCompleted).length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidBg(
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GOALS - $progressPct% Identity Match',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: kSub,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Active Milestones',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: kInk,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                  child: LiquidCard(
                    frosted: true,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '$completedGoals of ${goals.length} goals moving',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: kInk,
                                ),
                              ),
                            ),
                            Text(
                              '$progressPct%',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: kInk,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: (progressPct / 100).clamp(0.0, 1.0),
                            minHeight: 10,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.45),
                            valueColor:
                                const AlwaysStoppedAnimation<Color>(kMint),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          identity == null
                              ? 'Identity profile updates after onboarding, day close, or a major progress event.'
                              : _updatedLabel(identity.lastComputedAt),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: kSub,
                          ),
                        ),
                        if (identities.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: identities.take(6).map((identityLabel) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  identityLabel,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: kInk,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              if (goalsAsync.isLoading && goals.isEmpty)
                const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (goals.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(
                      child: Text(
                        'No goal documents yet. Complete onboarding or a major progress event to seed them.',
                        style:
                            TextStyle(color: kSub, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final goal = goals[index];
                        final targetStr = goal.targetDate != null
                            ? _formatDate(goal.targetDate!)
                            : 'No Deadline';
                        final color = _parseColor(goal.colorHex);
                        final iconData = _iconForGoal(goal.iconName);
                        final progress = goal.progressPct.clamp(0, 100);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: LiquidCard(
                            frosted: true,
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(iconData, color: color),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            goal.title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
                                              color: kInk,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            goal.description ??
                                                'Progress comes from your recent tasks, habits, and streaks.',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 13,
                                              color: kSub,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '$progress%',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 18,
                                            color: kInk,
                                          ),
                                        ),
                                        if (goal.isCompleted)
                                          const Icon(
                                            Icons.check_circle_rounded,
                                            color: kMint,
                                            size: 20,
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    value: (progress / 100).clamp(0.0, 1.0),
                                    minHeight: 8,
                                    backgroundColor:
                                        color.withValues(alpha: 0.12),
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(color),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Target: $targetStr',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: kSub,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      _updatedLabel(goal.lastComputedAt),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                        color: kSub,
                                      ),
                                    ),
                                  ],
                                ),
                                if (goal.identityTags.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children:
                                        goal.identityTags.take(4).map((tag) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          tag,
                                          style: TextStyle(
                                            color: color,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: goals.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
