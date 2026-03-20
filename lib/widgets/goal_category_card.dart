import 'package:flutter/material.dart';

/// A bold, colorful category card used on onboarding page 1.
/// Each card has its own gradient, a large icon, title, and
/// a crisp animated selection state — no glass/blur effects.
class GoalCategoryCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String description;
  final Color primaryColor;
  final Color secondaryColor;
  final bool isSelected;
  final VoidCallback onTap;

  const GoalCategoryCard({
    super.key,
    required this.title,
    required this.icon,
    required this.description,
    required this.primaryColor,
    required this.secondaryColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isSelected
                ? [primaryColor, secondaryColor]
                : [
                    primaryColor.withValues(alpha: 0.12),
                    secondaryColor.withValues(alpha: 0.18),
                  ],
          ),
          border: Border.all(
            color: isSelected
                ? primaryColor.withValues(alpha: 0.70)
                : primaryColor.withValues(alpha: 0.20),
            width: isSelected ? 2.0 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.30),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Stack(
          children: [
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon circle
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.25)
                          : primaryColor.withValues(alpha: 0.15),
                    ),
                    child: Icon(
                      icon,
                      size: 26,
                      color: isSelected ? Colors.white : primaryColor,
                    ),
                  ),
                  const Spacer(),
                  // Title
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : const Color(0xFF1F2937),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  // Description
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.80)
                          : const Color(0xFF6B7280),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),

            // Selection checkmark badge
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              top: 12,
              right: 12,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isSelected ? 1.0 : 0.0,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.30),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: primaryColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
