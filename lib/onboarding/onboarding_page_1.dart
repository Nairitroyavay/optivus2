import 'package:flutter/material.dart';
import '../onboarding_screen.dart';
<<<<<<< Updated upstream
=======
import '../widgets/liquid_glass_card.dart';
>>>>>>> Stashed changes
import '../widgets/liquid_category_card.dart';

class OnboardingPage1 extends StatefulWidget {
  const OnboardingPage1({super.key});

  @override
  State<OnboardingPage1> createState() => _OnboardingPage1State();
}

class _OnboardingPage1State extends State<OnboardingPage1> {
  final Set<String> _selectedCategories = {'Health', 'Recovery'};

<<<<<<< Updated upstream
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
=======
  void _toggleCategory(String title) {
    setState(() {
      if (_selectedCategories.contains(title)) {
        _selectedCategories.remove(title);
      } else {
        _selectedCategories.add(title);
      }
    });
  }

  // Helper: create a Positioned LiquidDroplet
  Widget _drop(double left, double top, double sz, Color col,
      {bool glo = false, double? right, double? bottom}) {
    return Positioned(
      left: left >= 0 ? left : null,
      top: top >= 0 ? top : null,
      right: right,
      bottom: bottom,
      child: LiquidDroplet(color: col, size: sz, hasGlow: glo),
    );
  }

  // ── Ambient iridescent orb blob (placed behind the glass card) ─────────────
  Widget _ambientOrb(double w, double h, List<Color> colors, Alignment center) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: center,
          radius: 0.8,
          colors: [
            ...colors.map((c) => c.withValues(alpha: 0.55)),
            colors.last.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
>>>>>>> Stashed changes
  }

  // Custom card — same folder shape as the rest
  Widget _buildCustomCard() {
    return LiquidCategoryCard(
      title: 'Custom',
      icon: Icons.add_rounded,
      primaryColor: const Color(0xFF64748B),
      isSelected: false,
      onTap: () {
        // TODO: show custom category input
      },
      customDroplets: [
        // Cluster of small white/slate drops
        _drop(10, 12, 10, Colors.white.withValues(alpha: 0.55)),
        _drop(22, 8, 7, Colors.white.withValues(alpha: 0.42)),
        _drop(6, 22, 6, Colors.white.withValues(alpha: 0.35)),
        _drop(18, 20, 5, const Color(0xFF94A3B8).withValues(alpha: 0.40)),
        _drop(30, 14, 4, Colors.white.withValues(alpha: 0.28)),
        _drop(-1, 10, 9, const Color(0xFFCBD5E1).withValues(alpha: 0.50), right: 16),
        _drop(-1, 20, 6, Colors.white.withValues(alpha: 0.38), right: 28),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top + kIndicatorOverlayH;
    final bottomPadding = MediaQuery.of(context).padding.bottom + kButtonOverlayH;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, bottomPadding + 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Title ─────────────────────────────────────────────────
          const Text(
            'What do you want\nto improve?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 31,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F111A),
              height: 1.15,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 10),

          // ── Subtitle — liquid glass pill chip ─────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.70),
                    width: 1.2,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.50),
                      Colors.white.withValues(alpha: 0.22),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  'Select all that apply',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.blueGrey.shade600,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ),
          ),
<<<<<<< Updated upstream
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
=======
          const SizedBox(height: 24),

          // ── Outer liquid glass board (fills remaining space) ───────
          Expanded(
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // ── Ambient iridescent glow orbs behind the card ──
                    Positioned(
                      top: -30,
                      left: -20,
                      child: _ambientOrb(
                        180, 180,
                        [const Color(0xFFF9A8D4), const Color(0xFFC084FC)],
                        Alignment.center,
                      ),
                    ),
                    Positioned(
                      top: 40,
                      right: -30,
                      child: _ambientOrb(
                        160, 160,
                        [const Color(0xFF7DD3FC), const Color(0xFF818CF8)],
                        Alignment.center,
                      ),
                    ),
                    Positioned(
                      bottom: 20,
                      left: -10,
                      child: _ambientOrb(
                        140, 140,
                        [const Color(0xFF6EE7B7), const Color(0xFF34D399)],
                        Alignment.center,
                      ),
                    ),
                    Positioned(
                      bottom: -20,
                      right: -10,
                      child: _ambientOrb(
                        150, 150,
                        [const Color(0xFFFDE68A), const Color(0xFFFBAF72)],
                        Alignment.center,
                      ),
                    ),

                    // ── Frosted glass card ────────────────────────────
                    LiquidGlassCard(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      cornerRadius: 36,
                      tabDrop: 44,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          top: 26, left: 12, right: 12, bottom: 12,
                        ),
                        child: GridView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: 7,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 1.6,
                          ),
                          itemBuilder: (context, index) {
                            switch (index) {
                              // ── Health — coral red (Home tab) ───────────
                              case 0:
                                return LiquidCategoryCard(
                                  title: 'Health',
                                  icon: Icons.favorite_rounded,
                                  primaryColor: const Color(0xFFFF6B6B),
                                  isSelected: _selectedCategories.contains('Health'),
                                  onTap: () => _toggleCategory('Health'),
                                  customDroplets: [
                                    _drop(8, -1, 14, const Color(0xFFFF6B6B), glo: true, bottom: 68),
                                    _drop(24, -1, 9, const Color(0xFFFF9999), bottom: 76),
                                    _drop(5, -1, 6, const Color(0xFFFFB3B3).withValues(alpha: 0.7), bottom: 82),
                                    _drop(-1, 10, 10, const Color(0xFFFBE5E4).withValues(alpha: 0.9), right: 12),
                                    _drop(-1, 20, 6, const Color(0xFFFFCDD2).withValues(alpha: 0.80), right: 24),
                                    _drop(14, -1, 5, Colors.white.withValues(alpha: 0.60), bottom: 90),
                                  ],
                                );

                              // ── Career — mint green (Routine tab) ────────
                              case 1:
                                return LiquidCategoryCard(
                                  title: 'Career',
                                  icon: Icons.work_rounded,
                                  primaryColor: const Color(0xFF4ADE80),
                                  isSelected: _selectedCategories.contains('Career'),
                                  onTap: () => _toggleCategory('Career'),
                                  customDroplets: [
                                    _drop(-1, 8, 16, const Color(0xFFA3FF91).withValues(alpha: 0.80), right: 14),
                                    _drop(-1, 7, 10, const Color(0xFFBBF7D0).withValues(alpha: 0.85), right: 32),
                                    _drop(-1, 22, 7, const Color(0xFF86EFAC).withValues(alpha: 0.70), right: 12),
                                    _drop(-1, 18, 11, Colors.white.withValues(alpha: 0.55), right: 44),
                                    _drop(-1, 30, 6, Colors.white.withValues(alpha: 0.40), right: 26),
                                    _drop(8, -1, 9, const Color(0xFFEFFEEC).withValues(alpha: 0.80), bottom: 70),
                                    _drop(18, -1, 6, const Color(0xFFA3FF91).withValues(alpha: 0.60), bottom: 80),
                                  ],
                                );

                              // ── Skill — cyan teal (Tracker tab) ──────────
                              case 2:
                                return LiquidCategoryCard(
                                  title: 'Skill',
                                  icon: Icons.school_rounded,
                                  primaryColor: const Color(0xFF00BCD4),
                                  isSelected: _selectedCategories.contains('Skill'),
                                  onTap: () => _toggleCategory('Skill'),
                                  customDroplets: [
                                    _drop(8, 10, 16, const Color(0xFF78FDFF).withValues(alpha: 0.70)),
                                    _drop(26, 8, 10, const Color(0xFFE8FEFE).withValues(alpha: 0.90)),
                                    _drop(6, 26, 8, const Color(0xFF67E8F9).withValues(alpha: 0.65)),
                                    _drop(20, 22, 5, Colors.white.withValues(alpha: 0.55)),
                                    _drop(36, 18, 6, Colors.white.withValues(alpha: 0.42)),
                                    _drop(-1, -1, 10, const Color(0xFF78FDFF).withValues(alpha: 0.55), right: 14, bottom: 72),
                                    _drop(-1, -1, 6, const Color(0xFFA5F3FC).withValues(alpha: 0.50), right: 26, bottom: 82),
                                  ],
                                );

                              // ── Recovery — soft violet (Coach tab) ───────
                              case 3:
                                return LiquidCategoryCard(
                                  title: 'Recovery',
                                  icon: Icons.eco_rounded,
                                  primaryColor: const Color(0xFFC084FC),
                                  isSelected: _selectedCategories.contains('Recovery'),
                                  onTap: () => _toggleCategory('Recovery'),
                                  customDroplets: [
                                    _drop(8, 12, 16, const Color(0xFFC084FC), glo: true),
                                    _drop(26, 8, 10, const Color(0xFFD8B4FE), glo: true),
                                    _drop(4, 28, 7, Colors.white.withValues(alpha: 0.55)),
                                    _drop(18, 28, 5, const Color(0xFFF5EEFF).withValues(alpha: 0.75)),
                                    _drop(-1, 12, 9, const Color(0xFFA855F7).withValues(alpha: 0.65), glo: true, right: 12),
                                    _drop(-1, 22, 6, const Color(0xFFE9D5FF).withValues(alpha: 0.65), right: 22),
                                    _drop(34, 16, 5, Colors.white.withValues(alpha: 0.48)),
                                    _drop(38, 24, 4, Colors.white.withValues(alpha: 0.38)),
                                  ],
                                );

                              // ── Growth — rose pink (Goals tab) ───────────
                              case 4:
                                return LiquidCategoryCard(
                                  title: 'Growth',
                                  icon: Icons.trending_up_rounded,
                                  primaryColor: const Color(0xFFFF8CC2),
                                  isSelected: _selectedCategories.contains('Growth'),
                                  onTap: () => _toggleCategory('Growth'),
                                  customDroplets: [
                                    _drop(-1, 8, 14, const Color(0xFFFF8CC2), glo: true, right: 12),
                                    _drop(-1, 20, 9, const Color(0xFFFCEDF3).withValues(alpha: 0.90), right: 24),
                                    _drop(-1, 14, 6, Colors.white.withValues(alpha: 0.50), right: 38),
                                    _drop(-1, 28, 5, const Color(0xFFFBB6CE).withValues(alpha: 0.70), right: 16),
                                    _drop(8, -1, 10, const Color(0xFFF472B6).withValues(alpha: 0.65), glo: true, bottom: 70),
                                    _drop(20, -1, 6, const Color(0xFFFDA4CF).withValues(alpha: 0.60), bottom: 80),
                                    _drop(32, -1, 5, Colors.white.withValues(alpha: 0.45), bottom: 76),
                                  ],
                                );

                              // ── Focus — amber gold (Profile tab) ─────────
                              case 5:
                                return LiquidCategoryCard(
                                  title: 'Focus',
                                  icon: Icons.center_focus_strong_rounded,
                                  primaryColor: const Color(0xFFFFB830),
                                  isSelected: _selectedCategories.contains('Focus'),
                                  onTap: () => _toggleCategory('Focus'),
                                  customDroplets: [
                                    _drop(10, 8, 14, const Color(0xFFFFB830), glo: true),
                                    _drop(26, 14, 8, const Color(0xFFFFD580), glo: true),
                                    _drop(8, 24, 6, Colors.white.withValues(alpha: 0.52)),
                                    _drop(22, 24, 5, const Color(0xFFFFF6E0).withValues(alpha: 0.75)),
                                    _drop(-1, 10, 10, const Color(0xFFFDE68A).withValues(alpha: 0.70), glo: true, right: 12),
                                    _drop(-1, 22, 7, const Color(0xFFFBBF24).withValues(alpha: 0.60), right: 22),
                                    _drop(36, 20, 5, Colors.white.withValues(alpha: 0.45)),
                                    _drop(40, 10, 4, const Color(0xFFFEF3C7).withValues(alpha: 0.60)),
                                  ],
                                );

                              default:
                                return _buildCustomCard();
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
>>>>>>> Stashed changes
        ],
      ),
    );
  }
}
<<<<<<< Updated upstream

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
=======
>>>>>>> Stashed changes
