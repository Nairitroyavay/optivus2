import 'package:flutter/material.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';

class TrackerTab extends StatelessWidget {
  const TrackerTab({super.key});

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
                        'TRACKER',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: kSub,
                          letterSpacing: 1.5,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Your Progress',
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
                      final metrics = [
                        {'title': 'Water Intake', 'value': '1.5L / 2L', 'progress': 0.75, 'color': kBlue, 'icon': Icons.water_drop_rounded},
                        {'title': 'Steps', 'value': '6,000 / 10K', 'progress': 0.60, 'color': kMint, 'icon': Icons.directions_walk_rounded},
                        {'title': 'Sleep', 'value': '6h 30m', 'progress': 0.80, 'color': kPurple, 'icon': Icons.bedtime_rounded},
                      ];
                      final metric = metrics[index];
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
                                  Icon(metric['icon'] as IconData, color: metric['color'] as Color),
                                  const SizedBox(width: 8),
                                  Text(
                                    metric['title'] as String,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: kInk),
                                  ),
                                  const Spacer(),
                                  Text(
                                    metric['value'] as String,
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kSub),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              LinearProgressIndicator(
                                value: metric['progress'] as double,
                                backgroundColor: (metric['color'] as Color).withValues(alpha: 0.2),
                                color: metric['color'] as Color,
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: 3,
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
