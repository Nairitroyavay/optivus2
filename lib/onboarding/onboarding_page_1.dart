import 'package:flutter/material.dart';
import '../onboarding_screen.dart';

class OnboardingPage1 extends StatefulWidget {
  const OnboardingPage1({super.key});

  @override
  State<OnboardingPage1> createState() => _OnboardingPage1State();
}

class _OnboardingPage1State extends State<OnboardingPage1> {
  final Set<String> _selectedItems = {'Health', 'Recovery'};

  final List<Map<String, dynamic>> _items = [
    {'title': 'Health', 'icon': Icons.favorite},
    {'title': 'Career', 'icon': Icons.work},
    {'title': 'Skill', 'icon': Icons.school},
    {'title': 'Recovery', 'icon': Icons.spa},
    {'title': 'Growth', 'icon': Icons.self_improvement},
    {'title': 'Focus', 'icon': Icons.center_focus_strong},
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
                final isSelected = _selectedItems.contains(item['title']);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (isSelected) _selectedItems.remove(item['title']);
                    else _selectedItems.add(item['title']);
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF89F4DD) : Colors.transparent,
                        width: 2.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFFE0FDF7) : const Color(0xFFF3F4F6),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  item['icon'],
                                  color: isSelected ? const Color(0xFF0D9488) : const Color(0xFF9CA3AF),
                                  size: 26,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                item['title'],
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              if (isSelected) ...[
                                const SizedBox(height: 4),
                                const Text('Selected', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0D9488))),
                              ]
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Positioned(
                            top: 12,
                            right: 12,
                            child: Icon(Icons.check_circle, color: Color(0xFF0D9488), size: 20),
                          ),
                      ],
                    ),
                  ),
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
