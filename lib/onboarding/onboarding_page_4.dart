import 'package:flutter/material.dart';
import '../onboarding_screen.dart';
import '../widgets/liquid_glass_card.dart';
import '../widgets/liquid_category_card.dart';

class OnboardingPage4 extends StatefulWidget {
  const OnboardingPage4({super.key});

  @override
  State<OnboardingPage4> createState() => _OnboardingPage4State();
}

class _OnboardingPage4State extends State<OnboardingPage4> {
  // Multi-select: match the reference (Build strong body + Find inner peace)
  final Set<String> _selected = {'Build strong body', 'Find inner peace'};

  void _toggle(String title) {
    setState(() {
      if (_selected.contains(title)) {
        _selected.remove(title);
      } else {
        _selected.add(title);
      }
    });
  }

  // ── Helper: Positioned liquid droplet ───────────────────────────────────
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

  // ── "Add your own" custom card ──────────────────────────────────────────
  Widget _buildCustomCard() {
    return LiquidCategoryCard(
      title: 'Custom',
      icon: Icons.add_rounded,
      primaryColor: const Color(0xFF64748B),
      isSelected: _selected.contains('Custom'),
      onTap: () => _toggle('Custom'),
      customDroplets: [
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
    final topPadding    = MediaQuery.of(context).padding.top    + kIndicatorOverlayH;
    final bottomPadding = MediaQuery.of(context).padding.bottom + kButtonOverlayH;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, bottomPadding + 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Title ───────────────────────────────────────────────────────
          RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              style: TextStyle(
                fontSize: 31,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F111A),
                height: 1.15,
                letterSpacing: -1,
              ),
              children: [
                TextSpan(text: 'Long-Term\n'),
                TextSpan(
                  text: 'Identity Goals',
                  style: TextStyle(color: Color(0xFFA07412)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── Subtitle ────────────────────────────────────────────────────
          Text(
            'Select the identities you want to embody\nor create your own path.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.blueGrey.shade700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          // ── Liquid glass board ──────────────────────────────────────────
          Expanded(
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
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
                              itemCount: 9, // 8 goals + 1 custom
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 16,
                                childAspectRatio: 1.6,
                              ),
                              itemBuilder: (context, index) {
                                switch (index) {
                                  // ── Become financially free — gold ──────
                                  case 0:
                                    return LiquidCategoryCard(
                                      title: 'Financially\nFree',
                                      icon: Icons.account_balance_wallet_rounded,
                                      primaryColor: const Color(0xFFFFB830),
                                      isSelected: _selected.contains('Financially\nFree'),
                                      onTap: () => _toggle('Financially\nFree'),
                                      customDroplets: [
                                        _drop(10, 8, 14, const Color(0xFFFFB830), glo: true),
                                        _drop(26, 14, 8, const Color(0xFFFFD580), glo: true),
                                        _drop(8, 24, 6, Colors.white.withValues(alpha: 0.52)),
                                        _drop(22, 24, 5, const Color(0xFFFFF6E0).withValues(alpha: 0.75)),
                                        _drop(-1, 10, 10, const Color(0xFFFDE68A).withValues(alpha: 0.70), glo: true, right: 12),
                                        _drop(-1, 22, 7, const Color(0xFFFBBF24).withValues(alpha: 0.60), right: 22),
                                        _drop(36, 20, 5, Colors.white.withValues(alpha: 0.45)),
                                      ],
                                    );

                                  // ── Build strong body — coral red ───────
                                  case 1:
                                    return LiquidCategoryCard(
                                      title: 'Strong\nBody',
                                      icon: Icons.fitness_center_rounded,
                                      primaryColor: const Color(0xFFFF6B6B),
                                      isSelected: _selected.contains('Strong\nBody'),
                                      onTap: () => _toggle('Strong\nBody'),
                                      customDroplets: [
                                        _drop(8, -1, 14, const Color(0xFFFF6B6B), glo: true, bottom: 68),
                                        _drop(24, -1, 9, const Color(0xFFFF9999), bottom: 76),
                                        _drop(5, -1, 6, const Color(0xFFFFB3B3).withValues(alpha: 0.7), bottom: 82),
                                        _drop(-1, 10, 10, const Color(0xFFFBE5E4).withValues(alpha: 0.9), right: 12),
                                        _drop(-1, 20, 6, const Color(0xFFFFCDD2).withValues(alpha: 0.80), right: 24),
                                        _drop(14, -1, 5, Colors.white.withValues(alpha: 0.60), bottom: 90),
                                      ],
                                    );

                                  // ── Become disciplined — teal ────────────
                                  case 2:
                                    return LiquidCategoryCard(
                                      title: 'Become\nDisciplined',
                                      icon: Icons.self_improvement_rounded,
                                      primaryColor: const Color(0xFF14B8A6),
                                      isSelected: _selected.contains('Become\nDisciplined'),
                                      onTap: () => _toggle('Become\nDisciplined'),
                                      customDroplets: [
                                        _drop(8, 10, 16, const Color(0xFF5EEAD4).withValues(alpha: 0.70)),
                                        _drop(26, 8, 10, const Color(0xFFCCFBF1).withValues(alpha: 0.90)),
                                        _drop(6, 26, 8, const Color(0xFF2DD4BF).withValues(alpha: 0.65)),
                                        _drop(20, 22, 5, Colors.white.withValues(alpha: 0.55)),
                                        _drop(-1, -1, 10, const Color(0xFF5EEAD4).withValues(alpha: 0.55), right: 14, bottom: 72),
                                        _drop(-1, -1, 6, const Color(0xFF99F6E4).withValues(alpha: 0.50), right: 26, bottom: 82),
                                      ],
                                    );

                                  // ── Master a new language — cyan ─────────
                                  case 3:
                                    return LiquidCategoryCard(
                                      title: 'New\nLanguage',
                                      icon: Icons.translate_rounded,
                                      primaryColor: const Color(0xFF00BCD4),
                                      isSelected: _selected.contains('New\nLanguage'),
                                      onTap: () => _toggle('New\nLanguage'),
                                      customDroplets: [
                                        _drop(-1, 8, 16, const Color(0xFF78FDFF).withValues(alpha: 0.80), right: 14),
                                        _drop(-1, 7, 10, const Color(0xFFE8FEFE).withValues(alpha: 0.85), right: 32),
                                        _drop(-1, 22, 7, const Color(0xFF67E8F9).withValues(alpha: 0.70), right: 12),
                                        _drop(-1, 18, 11, Colors.white.withValues(alpha: 0.55), right: 44),
                                        _drop(8, -1, 9, const Color(0xFFEFFEEC).withValues(alpha: 0.80), bottom: 70),
                                        _drop(18, -1, 6, const Color(0xFF78FDFF).withValues(alpha: 0.60), bottom: 80),
                                      ],
                                    );

                                  // ── Start a business — orange ────────────
                                  case 4:
                                    return LiquidCategoryCard(
                                      title: 'Start a\nBusiness',
                                      icon: Icons.rocket_launch_rounded,
                                      primaryColor: const Color(0xFFF97316),
                                      isSelected: _selected.contains('Start a\nBusiness'),
                                      onTap: () => _toggle('Start a\nBusiness'),
                                      customDroplets: [
                                        _drop(-1, 8, 14, const Color(0xFFF97316), glo: true, right: 12),
                                        _drop(-1, 20, 9, const Color(0xFFFED7AA).withValues(alpha: 0.90), right: 24),
                                        _drop(-1, 14, 6, Colors.white.withValues(alpha: 0.50), right: 38),
                                        _drop(-1, 28, 5, const Color(0xFFFDBA74).withValues(alpha: 0.70), right: 16),
                                        _drop(8, -1, 10, const Color(0xFFFB923C).withValues(alpha: 0.65), glo: true, bottom: 70),
                                        _drop(20, -1, 6, const Color(0xFFFED7AA).withValues(alpha: 0.60), bottom: 80),
                                      ],
                                    );

                                  // ── Find inner peace — soft violet ───────
                                  case 5:
                                    return LiquidCategoryCard(
                                      title: 'Inner\nPeace',
                                      icon: Icons.spa_rounded,
                                      primaryColor: const Color(0xFF8B5CF6),
                                      isSelected: _selected.contains('Inner\nPeace'),
                                      onTap: () => _toggle('Inner\nPeace'),
                                      customDroplets: [
                                        _drop(8, 12, 16, const Color(0xFF8B5CF6), glo: true),
                                        _drop(26, 8, 10, const Color(0xFFA78BFA), glo: true),
                                        _drop(4, 28, 7, Colors.white.withValues(alpha: 0.55)),
                                        _drop(18, 28, 5, const Color(0xFFDDD6FE).withValues(alpha: 0.75)),
                                        _drop(-1, 12, 9, const Color(0xFF7C3AED).withValues(alpha: 0.65), glo: true, right: 12),
                                        _drop(-1, 22, 6, const Color(0xFFC4B5FD).withValues(alpha: 0.65), right: 22),
                                      ],
                                    );

                                  // ── Be a better partner — rose pink ──────
                                  case 6:
                                    return LiquidCategoryCard(
                                      title: 'Better\nPartner',
                                      icon: Icons.favorite_rounded,
                                      primaryColor: const Color(0xFFF43F5E),
                                      isSelected: _selected.contains('Better\nPartner'),
                                      onTap: () => _toggle('Better\nPartner'),
                                      customDroplets: [
                                        _drop(-1, 8, 14, const Color(0xFFF43F5E), glo: true, right: 12),
                                        _drop(-1, 20, 9, const Color(0xFFFFE4E6).withValues(alpha: 0.90), right: 24),
                                        _drop(-1, 14, 6, Colors.white.withValues(alpha: 0.50), right: 38),
                                        _drop(-1, 28, 5, const Color(0xFFFECDD3).withValues(alpha: 0.70), right: 16),
                                        _drop(8, -1, 10, const Color(0xFFFB7185).withValues(alpha: 0.65), glo: true, bottom: 70),
                                        _drop(20, -1, 6, const Color(0xFFFDA4AF).withValues(alpha: 0.60), bottom: 80),
                                      ],
                                    );

                                  // ── Travel the world — royal blue ────────
                                  case 7:
                                    return LiquidCategoryCard(
                                      title: 'Travel the\nWorld',
                                      icon: Icons.public_rounded,
                                      primaryColor: const Color(0xFF3B82F6),
                                      isSelected: _selected.contains('Travel the\nWorld'),
                                      onTap: () => _toggle('Travel the\nWorld'),
                                      customDroplets: [
                                        _drop(8, -1, 14, const Color(0xFF3B82F6), glo: true, bottom: 68),
                                        _drop(24, -1, 9, const Color(0xFF60A5FA), bottom: 76),
                                        _drop(5, -1, 6, const Color(0xFF93C5FD).withValues(alpha: 0.7), bottom: 82),
                                        _drop(-1, 10, 10, const Color(0xFFDBEAFE).withValues(alpha: 0.9), right: 12),
                                        _drop(-1, 20, 6, const Color(0xFFBFDBFE).withValues(alpha: 0.80), right: 24),
                                        _drop(14, -1, 5, Colors.white.withValues(alpha: 0.60), bottom: 90),
                                      ],
                                    );

                                  // ── Add your own ─────────────────────────
                                  default:
                                    return _buildCustomCard();
                                }
                              },
                            ), // GridView
                          ), // SingleChildScrollView
                        ), // ShaderMask
                      ), // Padding
                    ), // LiquidGlassCard
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
