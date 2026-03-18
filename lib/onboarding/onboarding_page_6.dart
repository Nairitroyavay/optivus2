import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../onboarding_screen.dart';
import '../widgets/animated_bot_avatar.dart';

class OnboardingPage6 extends StatefulWidget {
  const OnboardingPage6({super.key});

  @override
  State<OnboardingPage6> createState() => _OnboardingPage6State();
}

class _OnboardingPage6State extends State<OnboardingPage6> {
  final TextEditingController _nameController = TextEditingController();

  String get coachName =>
      _nameController.text.trim().isEmpty ? 'Arjun' : _nameController.text.trim();

  // "Use color only 6 tab top color"
  // Mapping the chips to the primary colors defined in page 5.
  static const List<_SuggestionChip> _suggestions = [
    _SuggestionChip('Dad',    Color(0xFF3B82F6)), // 0: Supportive (Blue)
    _SuggestionChip('Maa',    Color(0xFFF43F5E)), // 4: Motivational (Rose Pink)
    _SuggestionChip('Sensei', Color(0xFF14B8A6)), // 2: Analytical (Teal)
    _SuggestionChip('Bro',    Color(0xFFF59E0B)), // 5: Friendly (Amber Gold)
    _SuggestionChip('Sir',    Color(0xFFEF4444)), // 1: Tough Love (Red)
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ── Liquid Glass Input Field ────────────────────────────────────────────────
  Widget _buildGlassInput() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        // Amber translucent overlay to match reference photo
        color: const Color(0xFFFBBF24).withValues(alpha: 0.22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
        boxShadow: [
          // Ambient amber glow shadow
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
          // Deep drop shadow
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32.5),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Stack(
            children: [
              // Inner white glow top-left matching LiquidOS styling
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.7),
                        blurRadius: 8,
                        offset: const Offset(-2, -2),
                        blurStyle: BlurStyle.inner,
                      ),
                    ],
                  ),
                ),
              ),
              // Prominent top highlight reflection
              Positioned(
                top: 2, left: 14, right: 14,
                child: Container(
                  height: 24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.65),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              // Text Field Content
              TextField(
                controller: _nameController,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(
                  color: Color(0xFF92400E),
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
                cursorColor: const Color(0xFF92400E),
                decoration: InputDecoration(
                  hintText: 'Enter coach name...',
                  hintStyle: TextStyle(
                    color: const Color(0xFF92400E).withValues(alpha: 0.55),
                    fontWeight: FontWeight.w500,
                    fontSize: 18,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: Icon(
                      Icons.edit_rounded,
                      color: const Color(0xFF92400E).withValues(alpha: 0.65),
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 3D Solid Glass/Jelly Bean Chip ──────────────────────────────────────────
  Widget _buildSolidGlassChip(_SuggestionChip chip) {
    final hsl = HSLColor.fromColor(chip.color);
    final darkText = hsl.withLightness((hsl.lightness - 0.45).clamp(0.0, 1.0)).toColor();
    final rimColor = hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
    final lightColor = hsl.withLightness((hsl.lightness + 0.20).clamp(0.0, 1.0)).toColor();

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _nameController.text = chip.label);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          // Radial gradient creating the 3D volume
          gradient: RadialGradient(
            center: const Alignment(0.0, 0.2),
            radius: 1.5,
            colors: [
              lightColor.withValues(alpha: 0.65),
              chip.color.withValues(alpha: 0.85),
              rimColor.withValues(alpha: 0.95),
            ],
            stops: const [0.0, 0.45, 1.0],
          ),
          border: Border.all(color: rimColor.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            // Colored bounce light
            BoxShadow(
              color: chip.color.withValues(alpha: 0.50),
              blurRadius: 16,
              offset: const Offset(0, 6),
              spreadRadius: -2,
            ),
            // Black occlusion shadow
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
            // Top inner rim light
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.55),
              blurRadius: 4,
              offset: const Offset(-1, -2),
              blurStyle: BlurStyle.inner,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28.5),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.hardEdge,
            children: [
              // Broad curved top highlight
              Positioned(
                top: 0, left: 0, right: 0,
                child: Container(
                  height: 20,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xDDFBFCFF), Color(0x00FFFFFF)],
                    ),
                  ),
                ),
              ),
              // Smaller intense specular crescent
              Positioned(
                top: 4, left: 12,
                child: Container(
                  width: 18, height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xEEFFFFFF), Color(0x00FFFFFF)],
                    ),
                  ),
                ),
              ),
              // Text Content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                child: Text(
                  chip.label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: darkText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Debossed Text Panel inside Preview Card ─────────────────────────────────
  Widget _buildInsetTextPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1),
        boxShadow: [
          // Inner dark shade (top/left)
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(2, 4),
            blurStyle: BlurStyle.inner,
          ),
          // Inner light shade (bottom/right)
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.8),
            blurRadius: 10,
            offset: const Offset(-2, -2),
            blurStyle: BlurStyle.inner,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              'Good morning, Nairit.',
              key: const ValueKey('greeting'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              '— Coach $coachName',
              key: ValueKey(coachName),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── The Big Preview Card ────────────────────────────────────────────────────
  Widget _buildPreviewCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.45), // soft frosted opacity
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(-1, -2),
            blurStyle: BlurStyle.inner, // inner sheen
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26.5),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'PREVIEW',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.blueGrey.shade600,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Icon(
                      Icons.visibility_rounded,
                      color: Colors.blueGrey.shade400,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Bot Orb + Indented Message Window
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AnimatedBotAvatar(),
                    const SizedBox(width: 18),
                    Expanded(child: _buildInsetTextPanel()),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic paddings
    final top = MediaQuery.of(context).padding.top + kIndicatorOverlayH;
    final bottom = MediaQuery.of(context).padding.bottom + kButtonOverlayH;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(26, top + 16, 26, bottom + 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title ───────────────────────────────────────────────────────────
          const Text(
            'What Should We\nCall Your Coach?',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F111A),
              height: 1.15,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 32),

          // ── Amber Glass Input ───────────────────────────────────────────────
          _buildGlassInput(),
          const SizedBox(height: 36),

          // ── Suggestions Header ──────────────────────────────────────────────
          Text(
            'SUGGESTIONS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.blueGrey.shade600,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),

          // ── Glass Jelly Bean Chips Horizontal Scroll ────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.none, // Allow outer glow to shine
            child: Row(
              children: [
                for (int i = 0; i < _suggestions.length; i++) ...[
                  _buildSolidGlassChip(_suggestions[i]),
                  if (i < _suggestions.length - 1) const SizedBox(width: 12),
                ],
              ],
            ),
          ),
          const SizedBox(height: 36),

          // ── Frosted Glass Preview Card ──────────────────────────────────────
          _buildPreviewCard(),
        ],
      ),
    );
  }
}

// ── Model ─────────────────────────────────────────────────────────────────────
class _SuggestionChip {
  final String label;
  final Color color;
  const _SuggestionChip(this.label, this.color);
}
