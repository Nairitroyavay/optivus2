import 'dart:ui';
import 'package:flutter/material.dart';
import '../onboarding_screen.dart';
import '../widgets/liquid_glass_card.dart';
import '../widgets/liquid_category_card.dart';

class OnboardingPage1 extends StatefulWidget {
  const OnboardingPage1({super.key});

  @override
  State<OnboardingPage1> createState() => _OnboardingPage1State();
}

class _OnboardingPage1State extends State<OnboardingPage1> {
  final Set<String> _selectedCategories = {'Health', 'Recovery'};
  final List<String> _allCategories = [
    'Health', 'Career', 'Skill', 'Recovery', 'Growth', 'Focus'
  ];

  bool get _isAllSelected => _selectedCategories.containsAll(_allCategories);

  void _toggleCategory(String title) {
    setState(() {
      if (_selectedCategories.contains(title)) {
        _selectedCategories.remove(title);
      } else {
        _selectedCategories.add(title);
      }
    });
  }

  void _toggleAll() {
    setState(() {
      if (_isAllSelected) {
        _selectedCategories.clear();
      } else {
        _selectedCategories.addAll(_allCategories);
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
          const SizedBox(height: 32),


          // ── Outer liquid glass board (fills remaining space) ───────
          Expanded(
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [

                    // ── Frosted glass card ────────────────────────────
                    LiquidGlassCard(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      cornerRadius: 36,
                      tabDrop: 44,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          top: 50, left: 12, right: 12, bottom: 12,
                        ),
                        child: ShaderMask(
                          shaderCallback: (Rect bounds) {
                            return const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              // transparent → opaque (top) and opaque → transparent (bottom)
                              colors: [
                                Colors.transparent,
                                Colors.white,
                                Colors.white,
                                Colors.transparent,
                              ],
                              stops: [0.0, 0.06, 0.92, 1.0],
                            ).createShader(bounds);
                          },
                          blendMode: BlendMode.dstIn,
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
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
                        ),  // GridView.builder
                        ),  // SingleChildScrollView
                        ),  // ShaderMask
                      ),    // Padding
                    ),      // LiquidGlassCard

                    // ── Select All Button in Folder Cutout ─────────────
                    Positioned(
                      top: 4,
                      right: 0,
                      child: GestureDetector(
                        onTap: _toggleAll,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: _isAllSelected 
                                        ? const Color(0xFF2196F3).withValues(alpha: 0.6)
                                        : Colors.white.withValues(alpha: 0.85),
                                    width: 1.5,
                                  ),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: _isAllSelected
                                        ? [
                                            const Color(0xFF64B5F6).withValues(alpha: 0.35),
                                            const Color(0xFF2196F3).withValues(alpha: 0.15),
                                          ]
                                        : [
                                            Colors.white.withValues(alpha: 0.65),
                                            Colors.white.withValues(alpha: 0.35),
                                          ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _isAllSelected
                                          ? const Color(0xFF2196F3).withValues(alpha: 0.15)
                                          : Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  _isAllSelected ? 'Deselect all' : 'Select all',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: _isAllSelected
                                        ? const Color(0xFF1976D2)
                                        : const Color(0xFF4A5568),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
