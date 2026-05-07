import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/models/goal_model.dart';

/// "Today's Identity Push" motivational card.
///
/// Picks the highest-priority active goal and surfaces its identity tag + `why`
/// as a motivational nudge. Hidden when no active goals exist.
class TodayIdentityPushCard extends StatelessWidget {
  final List<GoalModel> activeGoals;

  const TodayIdentityPushCard({super.key, required this.activeGoals});

  @override
  Widget build(BuildContext context) {
    // Pick the first active goal with a non-empty `why` as today's focus
    final focus = activeGoals.cast<GoalModel?>().firstWhere(
          (g) => g!.status == GoalStatus.active && g.why.isNotEmpty,
          orElse: () => activeGoals.isNotEmpty ? activeGoals.first : null,
        );

    if (focus == null) return const SizedBox.shrink();

    final tag = focus.identityTag.isNotEmpty ? focus.identityTag : focus.title;
    final motivational = focus.why.isNotEmpty
        ? focus.why
        : 'Keep showing up as "$tag" today — every small step counts.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          // Detail navigation stubbed — Task 9.3
        },
        child: LiquidCard(
          frosted: true,
          tint: kPurple.withValues(alpha: 0.08),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── header ──
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          kPurple.withValues(alpha: 0.22),
                          kAmber.withValues(alpha: 0.14),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 18,
                      color: kPurple.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "Today's Focus",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: kInk,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: kSub.withValues(alpha: 0.4),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── identity tag pill ──
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: kPurple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  tag,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kPurple,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── motivational snippet ──
              Text(
                motivational,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: kInk.withValues(alpha: 0.72),
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
