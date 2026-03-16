import 'dart:ui';
import 'package:flutter/material.dart';
import '../onboarding_screen.dart';

class OnboardingPage1 extends StatefulWidget {
  const OnboardingPage1({super.key});

  @override
  State<OnboardingPage1> createState() => _OnboardingPage1State();
}

class _OnboardingPage1State extends State<OnboardingPage1> {
  final Set<String> _selectedItems = {'Health', 'Recovery'};

  static const List<_CategoryData> _items = [
    _CategoryData(
      title: 'Health',
      icon: Icons.favorite_rounded,
      description: 'Body, sleep & nutrition',
      primary: Color(0xFFEF4444),
    ),
    _CategoryData(
      title: 'Career',
      icon: Icons.rocket_launch_rounded,
      description: 'Goals & professional growth',
      primary: Color(0xFF6366F1),
    ),
    _CategoryData(
      title: 'Skill',
      icon: Icons.bolt_rounded,
      description: 'Learn & level up fast',
      primary: Color(0xFFF59E0B),
    ),
    _CategoryData(
      title: 'Recovery',
      icon: Icons.spa_rounded,
      description: 'Rest, mindset & calm',
      primary: Color(0xFF10B981),
    ),
    _CategoryData(
      title: 'Growth',
      icon: Icons.trending_up_rounded,
      description: 'Habits & self-improvement',
      primary: Color(0xFF3B82F6),
    ),
    _CategoryData(
      title: 'Focus',
      icon: Icons.center_focus_strong_rounded,
      description: 'Deep work & flow state',
      primary: Color(0xFFEC4899),
    ),
  ];

  Widget _buildCategoryRow(_CategoryData item) {
    final isSelected = _selectedItems.contains(item.title);
    return GestureDetector(
      onTap: () => setState(() {
        if (isSelected) {
          _selectedItems.remove(item.title);
        } else {
          _selectedItems.add(item.title);
        }
      }),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.72)
                    : Colors.white.withOpacity(0.52),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isSelected
                      ? item.primary.withOpacity(0.45)
                      : Colors.white.withOpacity(0.70),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  // Glass icon circle
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? item.primary.withOpacity(0.15)
                          : Colors.white.withOpacity(0.50),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? item.primary.withOpacity(0.25)
                            : Colors.white.withOpacity(0.80),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      item.icon,
                      color: isSelected ? item.primary : const Color(0xFF6B7280),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F111A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.description,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Glass checkmark indicator
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? item.primary : Colors.white.withOpacity(0.40),
                      border: Border.all(
                        color: isSelected
                            ? Colors.transparent
                            : Colors.white.withOpacity(0.80),
                        width: 1.5,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top + kIndicatorOverlayH;
    final bottom = MediaQuery.of(context).padding.bottom + kButtonOverlayH;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(24, top + 20, 24, bottom + 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What do you want\nto improve?',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F111A),
              height: 1.15,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Select all that apply',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 24),
          for (final item in _items) _buildCategoryRow(item),
        ],
      ),
    );
  }
}

/// Immutable data model for a single goal category row.
class _CategoryData {
  final String title;
  final IconData icon;
  final String description;
  final Color primary;

  const _CategoryData({
    required this.title,
    required this.icon,
    required this.description,
    required this.primary,
  });
}
