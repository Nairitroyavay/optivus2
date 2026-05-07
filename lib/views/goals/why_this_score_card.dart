import 'package:flutter/material.dart';
import 'package:optivus2/models/goal_model.dart';
import 'package:optivus2/models/habit_model.dart';

import '../../core/liquid_ui/liquid_ui.dart';

class WhyThisScoreCard extends StatefulWidget {
  final GoalModel goal;
  final List<HabitModel> habits;

  const WhyThisScoreCard({
    super.key,
    required this.goal,
    required this.habits,
  });

  @override
  State<WhyThisScoreCard> createState() => _WhyThisScoreCardState();
}

class _WhyThisScoreCardState extends State<WhyThisScoreCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final habitsCount = widget.habits.length;
    final milestonesCount = widget.goal.milestones.length;
    final completedMilestones =
        widget.goal.milestones.where((m) => m.completed).length;

    final baseMessage = widget.goal.progress >= 80
        ? 'Excellent progress!'
        : widget.goal.progress >= 50
            ? 'Making steady progress.'
            : 'Just getting started.';

    return LiquidCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.analytics_outlined, color: kBlue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Why this score?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: kInk,
                          ),
                        ),
                        if (!_isExpanded) ...[
                          const SizedBox(height: 4),
                          Text(
                            baseMessage,
                            style: TextStyle(
                              fontSize: 14,
                              color: kSub,
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: kSub,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(color: kInk.withValues(alpha: 0.1)),
                  const SizedBox(height: 12),
                  Text(
                    'Your score of ${widget.goal.progress}% is computed based on:',
                    style: const TextStyle(
                      fontSize: 14,
                      color: kSub,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildFactorRow(
                    icon: Icons.track_changes_rounded,
                    color: kMint,
                    label: 'Connected Habits',
                    value: '$habitsCount habits linked',
                  ),
                  const SizedBox(height: 8),
                  _buildFactorRow(
                    icon: Icons.flag_rounded,
                    color: kAmber,
                    label: 'Milestones Completed',
                    value: '$completedMilestones / $milestonesCount',
                  ),
                  const SizedBox(height: 8),
                  _buildFactorRow(
                    icon: Icons.monitor_weight_outlined,
                    color: kPurple,
                    label: 'Identity Weight',
                    value: 'Weight: ${widget.goal.weight}',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFactorRow({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: kSub,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: kInk,
          ),
        ),
      ],
    );
  }
}
