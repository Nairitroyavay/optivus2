import 'package:flutter/material.dart';
import '../onboarding_screen.dart';
import '../widgets/liquid_category_card.dart';

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
      primary: Color(0xFFEF4444),
    ),
    _CategoryData(
      title: 'Career',
      icon: Icons.rocket_launch_rounded,
      primary: Color(0xFF6366F1),
    ),
    _CategoryData(
      title: 'Skill',
      icon: Icons.bolt_rounded,
      primary: Color(0xFFF59E0B),
    ),
    _CategoryData(
      title: 'Recovery',
      icon: Icons.spa_rounded,
      primary: Color(0xFF10B981),
    ),
    _CategoryData(
      title: 'Growth',
      icon: Icons.trending_up_rounded,
      primary: Color(0xFF3B82F6),
    ),
    _CategoryData(
      title: 'Focus',
      icon: Icons.center_focus_strong_rounded,
      primary: Color(0xFFEC4899),
    ),
  ];

  void _toggleCategory(_CategoryData item) {
    setState(() {
      if (_selectedItems.contains(item.title)) {
        _selectedItems.remove(item.title);
      } else {
        _selectedItems.add(item.title);
      }
    });
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
          const SizedBox(height: 32),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 32, // More space for the folder tab overlap
              childAspectRatio: 0.9,
            ),
            itemCount: _items.length,
            itemBuilder: (context, index) {
              final item = _items[index];
              return LiquidCategoryCard(
                title: item.title,
                icon: item.icon,
                primaryColor: item.primary,
                isSelected: _selectedItems.contains(item.title),
                onTap: () => _toggleCategory(item),
              );
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _CategoryData {
  final String title;
  final IconData icon;
  final Color primary;

  const _CategoryData({
    required this.title,
    required this.icon,
    required this.primary,
  });
}
