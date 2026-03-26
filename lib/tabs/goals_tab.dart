import 'package:flutter/material.dart';
import '../core/liquid_ui.dart';

class GoalsTab extends StatelessWidget {
  const GoalsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidBg(
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GOALS',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: kSub,
                          letterSpacing: 1.5,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
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
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final goals = [
                        {'title': 'Read 12 Books', 'deadline': 'End of Year', 'color': kRose, 'icon': Icons.menu_book_rounded},
                        {'title': 'Run a 5k', 'deadline': 'Next Month', 'color': kMint, 'icon': Icons.directions_run_rounded},
                      ];
                      final goal = goals[index];
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
                                  color: (goal['color'] as Color).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(goal['icon'] as IconData, color: goal['color'] as Color),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      goal['title'] as String,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: kInk),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Target: ${goal['deadline']}',
                                      style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: kSub),
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
                    childCount: 2,
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
