import 'package:flutter/material.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/models/goal_model.dart';

/// Horizontal scrollable strip of milestones gathered from all active goals.
///
/// Each chip shows milestone title, completed/pending state, and the parent
/// identity tag. Renders an empty-state message when no milestones exist.
class MilestonesStrip extends StatelessWidget {
  final List<GoalModel> goals;

  const MilestonesStrip({super.key, required this.goals});

  @override
  Widget build(BuildContext context) {
    // Flatten milestones across all goals, attaching the parent identity tag
    final milestones = <_MilestoneEntry>[];
    for (final goal in goals) {
      final tag = goal.identityTag.isNotEmpty ? goal.identityTag : goal.title;
      for (final m in goal.milestones) {
        milestones.add(_MilestoneEntry(milestone: m, parentTag: tag));
      }
    }

    // Sort: incomplete first, then alphabetical
    milestones.sort((a, b) {
      if (a.milestone.completed != b.milestone.completed) {
        return a.milestone.completed ? 1 : -1;
      }
      return a.milestone.title.compareTo(b.milestone.title);
    });

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── section label ──
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(
              'MILESTONES',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: kSub,
                letterSpacing: 1.2,
              ),
            ),
          ),

          if (milestones.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: LiquidCard(
                frosted: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.emoji_events_rounded,
                      size: 18,
                      color: kSub.withValues(alpha: 0.4),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'No milestones yet',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: kSub.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 78,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                physics: const BouncingScrollPhysics(),
                itemCount: milestones.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, index) {
                  final entry = milestones[index];
                  return _MilestoneChip(entry: entry);
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _MilestoneEntry {
  final GoalMilestone milestone;
  final String parentTag;
  const _MilestoneEntry({required this.milestone, required this.parentTag});
}

class _MilestoneChip extends StatelessWidget {
  final _MilestoneEntry entry;
  const _MilestoneChip({required this.entry});

  @override
  Widget build(BuildContext context) {
    final done = entry.milestone.completed;
    final accentColor = done ? kMint : kAmber;

    return LiquidCard(
      frosted: true,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: 130,
          maxWidth: 200,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  done
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 16,
                  color: accentColor,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    entry.milestone.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: done ? kSub : kInk,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                entry.parentTag,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
