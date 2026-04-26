import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus2/providers/onboarding_provider.dart';
import 'package:optivus2/views/screens/onboarding_screen.dart';

class OnboardingPage7 extends ConsumerStatefulWidget {
  const OnboardingPage7({super.key});

  @override
  ConsumerState<OnboardingPage7> createState() => _OnboardingPage7State();
}

class _OnboardingPage7State extends ConsumerState<OnboardingPage7> {
  String _selectedAccountability = 'Strict'; // Default match to image

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final acc = ref.read(onboardingProvider).accountabilityType;
      if (acc.isNotEmpty) {
        setState(() {
          _selectedAccountability = acc;
        });
      }
    });
  }

  Widget _buildAccountabilityCard({
    required String title,
    required String description,
    required String emojiIcon,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() => _selectedAccountability = title);
        ref.read(onboardingProvider.notifier).updateAccountability(title);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 20),
        child: Stack(
          children: [
            // ── Outer Glowing Gradient Rim (visible when selected) ──
            if (isSelected)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFF4D8D), // Pink
                        Color(0xFF40C4FF), // Cyan
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF4D8D).withAlpha(100),
                        blurRadius: 20,
                        offset: const Offset(-4, 0),
                      ),
                      BoxShadow(
                        color: const Color(0xFF40C4FF).withAlpha(100),
                        blurRadius: 20,
                        offset: const Offset(4, 0),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Inner Frosted Card ──
            Container(
              margin: EdgeInsets.all(isSelected ? 3.0 : 0.0), // Space for the gradient rim
              padding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: isSelected ? 17 : 20, // Adjust padding to keep height stable
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(isSelected ? 26 : 28),
                color: Colors.white.withAlpha(isSelected ? 230 : 160), // Frosted glass look
                border: !isSelected
                    ? Border.all(color: Colors.white.withAlpha(180), width: 1.5)
                    : null,
                boxShadow: !isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withAlpha(10),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        )
                      ]
                    : [],
              ),
              child: Row(
                children: [
                  // Icon Area
                  Text(
                    emojiIcon,
                    style: const TextStyle(fontSize: 40),
                  ),
                  const SizedBox(width: 18),
                  // Text Area
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F111A),
                          height: 1.35,
                          letterSpacing: -0.3,
                        ),
                        children: [
                          TextSpan(
                            text: '$title. ',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          TextSpan(
                            text: description,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.blueGrey.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, top + 10, 24, bottom + 16),
        child: Column(
          children: [
            // ── Small Header ──
            const Opacity(
              opacity: 0.6,
              child: Text(
                'Accountability',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Color(0xFF0F111A),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Main Title ──
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
                  TextSpan(text: 'How should we\nhandle '),
                  TextSpan(
                    text: 'slip-ups?',
                    style: TextStyle(color: Color(0xFFEF4444)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Subtitle ──
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'Choose your level of accountability when you miss a daily target.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // ── Cards ListView ──
            _buildAccountabilityCard(
              title: 'Forgiving',
              description: 'Gently roll missed tasks over to tomorrow. Focus on the comeback, not the failure.',
              emojiIcon: '🪶',
              isSelected: _selectedAccountability == 'Forgiving',
            ),
            _buildAccountabilityCard(
              title: 'Strict',
              description: 'Call me out. Force me to explain why I missed it before letting me reschedule.',
              emojiIcon: '📋',
              isSelected: _selectedAccountability == 'Strict',
            ),
            _buildAccountabilityCard(
              title: 'Ruthless',
              description: 'Zero excuses. Strip away pleasantries, give me a harsh truth pill, and demand immediate action.',
              emojiIcon: '🔒',
              isSelected: _selectedAccountability == 'Ruthless',
            ),
          ],
        ),
      ),
    );
  }
}
