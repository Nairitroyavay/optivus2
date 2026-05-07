import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/models/goal_model.dart';

/// A single identity card for the 2-column grid on the Goals tab.
///
/// Shows identity icon, tag name, progress bar, status badge.
/// Long-press opens a quick-action bottom sheet (Pause / Archive / View).
class IdentityCard extends StatelessWidget {
  final GoalModel goal;
  final VoidCallback? onTap;

  const IdentityCard({super.key, required this.goal, this.onTap});

  // ── colour helpers ──────────────────────────────────────────────────────────

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
      case 'self_improvement_rounded':
        return Icons.self_improvement;
      case 'school_rounded':
        return Icons.school_rounded;
      case 'work_rounded':
        return Icons.work_rounded;
      default:
        return Icons.flag_rounded;
    }
  }

  // ── quick-action bottom sheet ───────────────────────────────────────────────

  void _showQuickMenu(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuickMenuSheet(goal: goal),
    );
  }

  // ── build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(goal.colorHex);
    final iconData = _iconForGoal(goal.iconName);
    final progress = goal.progressPct.clamp(0, 100);
    final isPaused = goal.status == GoalStatus.paused;
    final tag = goal.identityTag.isNotEmpty ? goal.identityTag : goal.title;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap?.call();
      },
      onLongPress: () => _showQuickMenu(context),
      child: LiquidCard(
        frosted: true,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── icon + status row ──
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(iconData, color: color, size: 22),
                ),
                const Spacer(),
                if (isPaused)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: kRose.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Paused',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: kRose,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: kMint.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Active',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: kMint,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 14),

            // ── identity tag ──
            Text(
              tag,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: kInk,
                height: 1.3,
              ),
            ),

            const Spacer(),

            // ── progress bar + pct ──
            Row(
              children: [
                Text(
                  '$progress%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const Spacer(),
                if (goal.isCompleted)
                  const Icon(Icons.check_circle_rounded, color: kMint, size: 16),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (progress / 100).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// QUICK MENU BOTTOM SHEET
// ═════════════════════════════════════════════════════════════════════════════

class _QuickMenuSheet extends StatelessWidget {
  final GoalModel goal;
  const _QuickMenuSheet({required this.goal});

  @override
  Widget build(BuildContext context) {
    final tag = goal.identityTag.isNotEmpty ? goal.identityTag : goal.title;
    final isPaused = goal.status == GoalStatus.paused;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: kSub.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Text(
                tag,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: kInk,
                ),
              ),
              const SizedBox(height: 20),

              // ── action tiles ──
              _MenuTile(
                icon: isPaused
                    ? Icons.play_arrow_rounded
                    : Icons.pause_rounded,
                label: isPaused ? 'Resume' : 'Pause',
                color: kAmber,
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                  // read-only — no Firestore writes per spec
                },
              ),
              const SizedBox(height: 8),
              _MenuTile(
                icon: Icons.archive_rounded,
                label: 'Archive',
                color: kSub,
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
              _MenuTile(
                icon: Icons.visibility_rounded,
                label: 'View Details',
                color: kBlue,
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                  // Route to detail screen — stubbed until Task 9.3
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
