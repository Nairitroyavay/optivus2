import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus2/providers/onboarding_provider.dart';
import 'package:optivus2/views/screens/onboarding_screen.dart';

class OnboardingPage3 extends ConsumerStatefulWidget {
  const OnboardingPage3({super.key});

  @override
  ConsumerState<OnboardingPage3> createState() => _OnboardingPage3State();
}

class _OnboardingPage3State extends ConsumerState<OnboardingPage3> {
  final Set<String> _selectedHabits = {'Gym', 'Reading'};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final habits = ref.read(onboardingProvider).goodHabits;
      if (habits.isNotEmpty) {
        setState(() {
          _selectedHabits.clear();
          _selectedHabits.addAll(habits);
        });
      } else {
        // Initialize provider with defaults
        ref.read(onboardingProvider.notifier).updateGoodHabits(_selectedHabits.toList());
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 3-D Glass Orb  (used for both the icon circle AND the toggle)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildGlassOrb({
    required double size,
    required Color baseColor,   // dominant tint of the orb body
    required Color glowColor,   // outer glow / shadow colour
    required Widget child,
    bool selected = false,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Multi-stop radial-ish effect achieved via a diagonal gradient
        gradient: LinearGradient(
          begin: const Alignment(-0.8, -0.9),
          end: const Alignment(0.6, 0.9),
          stops: const [0.0, 0.35, 0.65, 1.0],
          colors: [
            Colors.white.withValues(alpha: selected ? 0.75 : 0.60),
            baseColor.withValues(alpha: selected ? 0.55 : 0.35),
            baseColor.withValues(alpha: selected ? 0.70 : 0.45),
            baseColor.withValues(alpha: selected ? 0.55 : 0.30),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: selected ? 0.80 : 0.65),
          width: 1.8,
        ),
        boxShadow: [
          // Outer drop shadow / coloured glow
          BoxShadow(
            color: glowColor.withValues(alpha: selected ? 0.55 : 0.20),
            blurRadius: selected ? 14 : 8,
            spreadRadius: selected ? 1 : 0,
            offset: const Offset(0, 4),
          ),
          // Upper-left bright rim (3D convex edge)
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.70),
            blurRadius: 4,
            spreadRadius: 0,
            offset: const Offset(-1.5, -1.5),
          ),
          // Bottom-right inner shadow (depth)
          BoxShadow(
            color: Colors.black.withValues(alpha: selected ? 0.18 : 0.10),
            blurRadius: 6,
            spreadRadius: 0,
            offset: const Offset(2, 3),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── Top-left specular highlight (glassy lens flare) ────────────
          Positioned(
            top: size * 0.10,
            left: size * 0.14,
            child: Container(
              width: size * 0.38,
              height: size * 0.22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size * 0.15),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: selected ? 0.90 : 0.75),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // ── Small lower-right secondary glint ─────────────────────────
          Positioned(
            bottom: size * 0.14,
            right: size * 0.16,
            child: Container(
              width: size * 0.14,
              height: size * 0.08,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size * 0.06),
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
          ),
          // ── Content (icon / checkmark) ─────────────────────────────────
          child,
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Toggle (right side of each card)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildToggle(bool isSelected) {
    return _buildGlassOrb(
      size: 36,
      selected: isSelected,
      baseColor: isSelected ? const Color(0xFF3DD68C) : const Color(0xFFB0BEC5),
      glowColor: isSelected ? const Color(0xFF22C55E) : Colors.grey,
      child: isSelected
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 18,
              shadows: [Shadow(color: Color(0xFF14532D), blurRadius: 4)])
          : const SizedBox.shrink(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Icon circle (left side of each card)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildIconOrb(IconData icon, bool isSelected) {
    return _buildGlassOrb(
      size: 48,
      selected: isSelected,
      baseColor: isSelected ? const Color(0xFF6FE6B0) : const Color(0xFFCDD5DA),
      glowColor: isSelected ? const Color(0xFF22C55E) : Colors.grey,
      child: Icon(
        icon,
        size: 22,
        color: isSelected ? const Color(0xFF15803D) : const Color(0xFF78909C),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Recessed progress bar — inset trough look
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildProgressBar(double progress) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              // Trough: slightly dark, inset appearance
              color: Colors.black.withValues(alpha: 0.07),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 3,
                  spreadRadius: 0,
                  offset: const Offset(0, 1),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.70),
                  blurRadius: 2,
                  spreadRadius: 0,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (progress / 100).clamp(0.0, 1.0),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF5B8BFA), // vivid blue
                        Color(0xFF34D399), // mint green
                        Color(0xFFFBBF24), // golden amber
                      ],
                      stops: [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${progress.toInt()}%',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF596270),
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // One habit card
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHabitCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required double progress,
  }) {
    final isSelected = _selectedHabits.contains(title);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedHabits.remove(title);
          } else {
            _selectedHabits.add(title);
          }
        });
        ref.read(onboardingProvider.notifier).updateGoodHabits(_selectedHabits.toList());
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          // ── Neumorphic glass capsule ────────────────────────────────────
          // The card itself is a blurred white pill that sits proud of the bg
          color: Colors.white.withValues(alpha: 0.38),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.70),
            width: 1.5,
          ),
          boxShadow: [
            // Main drop shadow — elevation
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 22,
              spreadRadius: 0,
              offset: const Offset(0, 8),
            ),
            // Secondary soft shadow for depth
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              spreadRadius: 0,
              offset: const Offset(0, 2),
            ),
            // Top-left bright rim (convex glass edge)
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.85),
              blurRadius: 0,
              spreadRadius: 0,
              offset: const Offset(-1, -1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32.5),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: 20,
              sigmaY: 20,
              tileMode: TileMode.decal, // prevents edge artifact (Flutter docs)
            ),
            child: Stack(
              children: [
                // ── Inner top rim gradient (convex glass surface sheen) ───
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 32,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(32.5),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.60),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                // ── Card content ─────────────────────────────────────────
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    isSelected ? 14 : 10,
                    14,
                    isSelected ? 14 : 10,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          _buildIconOrb(icon, isSelected),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1C2333),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF8499A8),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildToggle(isSelected),
                        ],
                      ),
                      // ── Progress bar (only when selected) ────────────
                      AnimatedSize(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        child: isSelected
                            ? Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: _buildProgressBar(progress),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top + kIndicatorOverlayH;
    final bottom = MediaQuery.of(context).padding.bottom + kButtonOverlayH;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, top + 26, 20, bottom + 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Title ───────────────────────────────────────────────────────
          RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F111A),
                height: 1.15,
                letterSpacing: -1.0,
                fontFamily: 'Poppins', // falls back gracefully if not available
              ),
              children: [
                TextSpan(text: 'Build Good '),
                TextSpan(
                  text: 'Habits',
                  style: TextStyle(color: Color(0xFF4ADE80)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Subtitle ─────────────────────────────────────────────────────
          const Text(
            'Select the habits you want to track daily to\nbuild a better version of yourself.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 28),

          // ── Cards ────────────────────────────────────────────────────────
          _buildHabitCard(
            icon: Icons.fitness_center_rounded,
            title: 'Gym',
            subtitle: 'Daily Goal: 45m',
            progress: 65,
          ),
          _buildHabitCard(
            icon: Icons.code_rounded,
            title: 'Coding',
            subtitle: 'Daily Goal: 2h',
            progress: 30,
          ),
          _buildHabitCard(
            icon: Icons.menu_book_rounded,
            title: 'Reading',
            subtitle: 'Daily Goal: 30m',
            progress: 50,
          ),
          _buildHabitCard(
            icon: Icons.self_improvement_rounded,
            title: 'Meditation',
            subtitle: 'Daily Goal: 15m',
            progress: 20,
          ),
          _buildHabitCard(
            icon: Icons.edit_note_rounded,
            title: 'Journaling',
            subtitle: 'Daily Goal: 10m',
            progress: 10,
          ),
        ],
      ),
    );
  }
}
