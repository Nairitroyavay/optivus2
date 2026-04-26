import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus2/providers/onboarding_provider.dart';
import 'package:optivus2/views/screens/onboarding_screen.dart';
import 'package:optivus2/widgets/liquid_glass_card.dart';
import 'package:optivus2/widgets/liquid_category_card.dart';

class OnboardingPage5 extends ConsumerStatefulWidget {
  const OnboardingPage5({super.key});

  @override
  ConsumerState<OnboardingPage5> createState() => _OnboardingPage5State();
}

class _OnboardingPage5State extends ConsumerState<OnboardingPage5> {
  String _selectedCoach = 'Supportive';

  void _selectCoach(String title) {
    setState(() {
      _selectedCoach = title;
    });
    ref.read(onboardingProvider.notifier).updateCoachStyle(title);
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
      isSelected: _selectedCoach == 'Custom',
      onTap: () => _selectCoach('Custom'),
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
          RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F111A),
                height: 1.15,
                letterSpacing: -1.0,
              ),
              children: [
                TextSpan(text: 'Pick how your\n'),
                TextSpan(
                  text: 'coach',
                  style: TextStyle(color: Color(0xFF8B5CF6)),
                ),
                TextSpan(text: ' should guide you?'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Choose a coaching style that matches your goals',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

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
                              // ── Supportive — royal blue ───────────
                              case 0:
                                return LiquidCategoryCard(
                                  title: 'Supportive',
                                  icon: Icons.volunteer_activism_rounded,
                                  primaryColor: const Color(0xFF3B82F6),
                                  isSelected: _selectedCoach == 'Supportive',
                                  onTap: () => _selectCoach('Supportive'),
                                  customDroplets: [
                                    _drop(8, -1, 14, const Color(0xFF3B82F6), glo: true, bottom: 68),
                                    _drop(24, -1, 9, const Color(0xFF60A5FA), bottom: 76),
                                    _drop(5, -1, 6, const Color(0xFF93C5FD).withValues(alpha: 0.7), bottom: 82),
                                    _drop(-1, 10, 10, const Color(0xFFDBEAFE).withValues(alpha: 0.9), right: 12),
                                    _drop(-1, 20, 6, const Color(0xFFBFDBFE).withValues(alpha: 0.80), right: 24),
                                    _drop(14, -1, 5, Colors.white.withValues(alpha: 0.60), bottom: 90),
                                  ],
                                );

                              // ── Tough Love — fire red/orange ────────
                              case 1:
                                return LiquidCategoryCard(
                                  title: 'Tough Love',
                                  icon: Icons.local_fire_department_rounded,
                                  primaryColor: const Color(0xFFEF4444),
                                  isSelected: _selectedCoach == 'Tough Love',
                                  onTap: () => _selectCoach('Tough Love'),
                                  customDroplets: [
                                    _drop(-1, 8, 16, const Color(0xFFF87171).withValues(alpha: 0.80), right: 14),
                                    _drop(-1, 7, 10, const Color(0xFFFCA5A5).withValues(alpha: 0.85), right: 32),
                                    _drop(-1, 22, 7, const Color(0xFFFECACA).withValues(alpha: 0.70), right: 12),
                                    _drop(-1, 18, 11, Colors.white.withValues(alpha: 0.55), right: 44),
                                    _drop(-1, 30, 6, Colors.white.withValues(alpha: 0.40), right: 26),
                                    _drop(8, -1, 9, const Color(0xFFFEE2E2).withValues(alpha: 0.80), bottom: 70),
                                    _drop(18, -1, 6, const Color(0xFFF87171).withValues(alpha: 0.60), bottom: 80),
                                  ],
                                );

                              // ── Analytical — teal ──────────
                              case 2:
                                return LiquidCategoryCard(
                                  title: 'Analytical',
                                  icon: Icons.biotech_rounded,
                                  primaryColor: const Color(0xFF14B8A6),
                                  isSelected: _selectedCoach == 'Analytical',
                                  onTap: () => _selectCoach('Analytical'),
                                  customDroplets: [
                                    _drop(8, 10, 16, const Color(0xFF5EEAD4).withValues(alpha: 0.70)),
                                    _drop(26, 8, 10, const Color(0xFFCCFBF1).withValues(alpha: 0.90)),
                                    _drop(6, 26, 8, const Color(0xFF2DD4BF).withValues(alpha: 0.65)),
                                    _drop(20, 22, 5, Colors.white.withValues(alpha: 0.55)),
                                    _drop(36, 18, 6, Colors.white.withValues(alpha: 0.42)),
                                    _drop(-1, -1, 10, const Color(0xFF5EEAD4).withValues(alpha: 0.55), right: 14, bottom: 72),
                                    _drop(-1, -1, 6, const Color(0xFF99F6E4).withValues(alpha: 0.50), right: 26, bottom: 82),
                                  ],
                                );

                              // ── Zen Master — soft violet ───────
                              case 3:
                                return LiquidCategoryCard(
                                  title: 'Zen Master',
                                  icon: Icons.self_improvement_rounded,
                                  primaryColor: const Color(0xFF8B5CF6),
                                  isSelected: _selectedCoach == 'Zen Master',
                                  onTap: () => _selectCoach('Zen Master'),
                                  customDroplets: [
                                    _drop(8, 12, 16, const Color(0xFF8B5CF6), glo: true),
                                    _drop(26, 8, 10, const Color(0xFFA78BFA), glo: true),
                                    _drop(4, 28, 7, Colors.white.withValues(alpha: 0.55)),
                                    _drop(18, 28, 5, const Color(0xFFDDD6FE).withValues(alpha: 0.75)),
                                    _drop(-1, 12, 9, const Color(0xFF7C3AED).withValues(alpha: 0.65), glo: true, right: 12),
                                    _drop(-1, 22, 6, const Color(0xFFC4B5FD).withValues(alpha: 0.65), right: 22),
                                    _drop(34, 16, 5, Colors.white.withValues(alpha: 0.48)),
                                    _drop(38, 24, 4, Colors.white.withValues(alpha: 0.38)),
                                  ],
                                );

                              // ── Motivational — rose pink ───────────
                              case 4:
                                return LiquidCategoryCard(
                                  title: 'Motivational',
                                  icon: Icons.rocket_launch_rounded,
                                  primaryColor: const Color(0xFFF43F5E),
                                  isSelected: _selectedCoach == 'Motivational',
                                  onTap: () => _selectCoach('Motivational'),
                                  customDroplets: [
                                    _drop(-1, 8, 14, const Color(0xFFF43F5E), glo: true, right: 12),
                                    _drop(-1, 20, 9, const Color(0xFFFFE4E6).withValues(alpha: 0.90), right: 24),
                                    _drop(-1, 14, 6, Colors.white.withValues(alpha: 0.50), right: 38),
                                    _drop(-1, 28, 5, const Color(0xFFFECDD3).withValues(alpha: 0.70), right: 16),
                                    _drop(8, -1, 10, const Color(0xFFFB7185).withValues(alpha: 0.65), glo: true, bottom: 70),
                                    _drop(20, -1, 6, const Color(0xFFFDA4AF).withValues(alpha: 0.60), bottom: 80),
                                    _drop(32, -1, 5, Colors.white.withValues(alpha: 0.45), bottom: 76),
                                  ],
                                );

                              // ── Friendly — amber gold ─────────
                              case 5:
                                return LiquidCategoryCard(
                                  title: 'Friendly',
                                  icon: Icons.mood_rounded,
                                  primaryColor: const Color(0xFFF59E0B),
                                  isSelected: _selectedCoach == 'Friendly',
                                  onTap: () => _selectCoach('Friendly'),
                                  customDroplets: [
                                    _drop(10, 8, 14, const Color(0xFFF59E0B), glo: true),
                                    _drop(26, 14, 8, const Color(0xFFFBBF24), glo: true),
                                    _drop(8, 24, 6, Colors.white.withValues(alpha: 0.52)),
                                    _drop(22, 24, 5, const Color(0xFFFEF3C7).withValues(alpha: 0.75)),
                                    _drop(-1, 10, 10, const Color(0xFFFDE68A).withValues(alpha: 0.70), glo: true, right: 12),
                                    _drop(-1, 22, 7, const Color(0xFFFCD34D).withValues(alpha: 0.60), right: 22),
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

