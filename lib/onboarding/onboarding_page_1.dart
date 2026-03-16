import 'package:flutter/material.dart';
import '../onboarding_screen.dart';
import '../widgets/goal_category_card.dart';

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
      secondary: Color(0xFFF97316),
    ),
    _CategoryData(
      title: 'Career',
      icon: Icons.rocket_launch_rounded,
      description: 'Goals & professional growth',
      primary: Color(0xFF6366F1),
      secondary: Color(0xFF8B5CF6),
    ),
    _CategoryData(
      title: 'Skill',
      icon: Icons.bolt_rounded,
      description: 'Learn & level up fast',
      primary: Color(0xFFF59E0B),
      secondary: Color(0xFFEF4444),
    ),
    _CategoryData(
      title: 'Recovery',
      icon: Icons.spa_rounded,
      description: 'Rest, mindset & calm',
      primary: Color(0xFF10B981),
      secondary: Color(0xFF06B6D4),
    ),
    _CategoryData(
      title: 'Growth',
      icon: Icons.trending_up_rounded,
      description: 'Habits & self-improvement',
      primary: Color(0xFF3B82F6),
      secondary: Color(0xFF6366F1),
    ),
    _CategoryData(
      title: 'Focus',
      icon: Icons.center_focus_strong_rounded,
      description: 'Deep work & flow state',
      primary: Color(0xFFEC4899),
      secondary: Color(0xFF8B5CF6),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top + kIndicatorOverlayH;
    final bottom = MediaQuery.of(context).padding.bottom + kButtonOverlayH;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(24, top + 20, 24, 0),
          sliver: const SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What do you want\nto improve?',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F111A),
                    height: 1.15,
                    letterSpacing: -1,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Select all that apply',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                  ),
                ),
                SizedBox(height: 24),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, bottom + 16),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = _items[index];
                final isSelected = _selectedItems.contains(item.title);
                return GoalCategoryCard(
                  title: item.title,
                  icon: item.icon,
                  description: item.description,
                  primaryColor: item.primary,
                  secondaryColor: item.secondary,
                  isSelected: isSelected,
                  onTap: () => setState(() {
                    if (isSelected) {
                      _selectedItems.remove(item.title);
                    } else {
                      _selectedItems.add(item.title);
                    }
                  }),
                );
              },
              childCount: _items.length,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.88,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
          ),
        ),
      ],
    );
  }
}

/// Immutable data model holding the display properties for a single
/// goal category tile rendered by [GoalCategoryCard] in the onboarding grid.
class _CategoryData {
  final String title;
  final IconData icon;
  final String description;
  final Color primary;
  final Color secondary;

  const _CategoryData({
    required this.title,
    required this.icon,
    required this.description,
    required this.primary,
    required this.secondary,
  });
}
