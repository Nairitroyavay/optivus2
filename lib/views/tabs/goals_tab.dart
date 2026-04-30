import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';

import '../../providers/goal_provider.dart';
import '../../providers/identity_provider.dart';

class GoalsTab extends ConsumerWidget {
  const GoalsTab({super.key});

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalProvider);
    final identityAsync = ref.watch(identityProvider);

    final goals = goalsAsync.valueOrNull ?? [];
    final identity = identityAsync.valueOrNull;
    final progressPct = identity?.progressPct ?? 0;

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
                        "No active goals found.",
                        style: TextStyle(color: kSub, fontWeight: FontWeight.w600),
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

                        Color color = kMint;
                        if (goal.colorHex != null && goal.colorHex!.length == 7) {
                          try {
                            color = Color(int.parse(goal.colorHex!.substring(1, 7), radix: 16) + 0xFF000000);
                          } catch (_) {}
                        }

                        IconData iconData = Icons.flag_rounded;
                        if (goal.iconName == 'menu_book_rounded') iconData = Icons.menu_book_rounded;
                        if (goal.iconName == 'directions_run_rounded') iconData = Icons.directions_run_rounded;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: LiquidCard(
                            frosted: true,
                            padding: const EdgeInsets.all(20),
                            child: Row(
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
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        goal.title,
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: kInk),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Target: $targetStr',
                                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: kSub),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded, color: kSub.withValues(alpha: 0.5)),
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
