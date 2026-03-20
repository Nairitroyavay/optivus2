
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/onboarding_provider.dart';
import '../onboarding_screen.dart';

// ═════════════════════════════════════════════════════════════════════════════
// Liquid-OS habit toggle switch — fully custom painted
// ═════════════════════════════════════════════════════════════════════════════
class _LiquidSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _LiquidSwitch({required this.value, required this.onChanged});

  @override
  State<_LiquidSwitch> createState() => _LiquidSwitchState();
}

class _LiquidSwitchState extends State<_LiquidSwitch>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;


  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: widget.value ? 1.0 : 0.0,
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic);
  }

  @override
  void didUpdateWidget(_LiquidSwitch old) {
    super.didUpdateWidget(old);
    if (widget.value != old.value) {
      widget.value ? _ctrl.forward() : _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => widget.onChanged(!widget.value),
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => CustomPaint(
          size: const Size(56, 32),
          painter: _SwitchPainter(_anim.value),
        ),
      ),
    );
  }
}

class _SwitchPainter extends CustomPainter {
  final double t; // 0.0 = off, 1.0 = on
  const _SwitchPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = h / 2;
    final trackRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      Radius.circular(r),
    );

    // ── 1. Drop shadow ─────────────────────────────────────────────────────
    final shadowPaint = Paint()
      ..color = Color.lerp(
          Colors.black.withValues(alpha: 0.08),
          const Color(0xFF00CDCD).withValues(alpha: 0.22),
          t)!
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 6);
    canvas.drawRRect(trackRect, shadowPaint);

    // ── 2. Track fill ──────────────────────────────────────────────────────
    // Off-state: frosted glass white
    final offPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.70),
          Colors.white.withValues(alpha: 0.35),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRRect(trackRect, offPaint);

    // On-state: cyan liquid gradient faded in by t
    if (t > 0) {
      final overPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF5FFFFF).withValues(alpha: t),
            const Color(0xFF00CDCD).withValues(alpha: t),
            const Color(0xFF007A8A).withValues(alpha: t),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, w, h));
      canvas.drawRRect(trackRect, overPaint);
    }

    // ── 3. Inner top highlight shimmer ────────────────────────────────────
    final sheenRect =
        RRect.fromRectAndRadius(Rect.fromLTWH(2, 1, w - 4, h * 0.4), Radius.circular(r));
    final sheenPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRRect(sheenRect, sheenPaint);

    // ── 4. Track border ────────────────────────────────────────────────────
    final borderColor = Color.lerp(
      Colors.white.withValues(alpha: 0.75),
      Colors.white.withValues(alpha: 0.50),
      t,
    )!;
    canvas.drawRRect(
      trackRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = borderColor,
    );

    // ── 5. Thumb position ──────────────────────────────────────────────────
    final thumbR = r - 3.5;
    final thumbX = r + t * (w - 2 * r);
    final thumbY = h / 2;
    final thumbCenter = Offset(thumbX, thumbY);

    // 5a. Thumb outer glow (on-state: cyan, off-state: none)
    if (t > 0.1) {
      canvas.drawCircle(
        thumbCenter,
        thumbR + 3,
        Paint()
          ..color =
              const Color(0xFF00FFFF).withValues(alpha: t * 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 6),
      );
    }

    // 5b. Thumb drop shadow
    canvas.drawCircle(
      thumbCenter + const Offset(0, 2),
      thumbR,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // 5c. Thumb body — radial glass sphere gradient
    final thumbRect =
        Rect.fromCircle(center: thumbCenter, radius: thumbR);
    final thumbPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.30, -0.45),
        radius: 0.85,
        colors: [
          Colors.white.withValues(alpha: 0.98),
          Colors.white.withValues(alpha: 0.75),
          Colors.white.withValues(alpha: 0.40),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(thumbRect);
    canvas.drawCircle(thumbCenter, thumbR, thumbPaint);

    // 5d. Specular highlight (top-left crescent)
    final hlOffset = Offset(thumbCenter.dx - thumbR * 0.28, thumbCenter.dy - thumbR * 0.32);
    canvas.drawOval(
      Rect.fromCenter(center: hlOffset, width: thumbR * 0.70, height: thumbR * 0.42),
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.90),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(thumbRect),
    );

    // 5e. Thumb border
    canvas.drawCircle(
      thumbCenter,
      thumbR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = Colors.white.withValues(alpha: 0.80),
    );
  }

  @override
  bool shouldRepaint(_SwitchPainter old) => old.t != t;
}

// ═════════════════════════════════════════════════════════════════════════════
// Liquid-OS icon orb
// ═════════════════════════════════════════════════════════════════════════════
class _GlassOrb extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final List<Color> gradientColors; // iridescent tint inside the orb
  final Color glowColor;

  const _GlassOrb({
    required this.icon,
    required this.iconColor,
    required this.gradientColors,
    this.glowColor = Colors.transparent,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer glow ring
        if (glowColor != Colors.transparent)
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                glowColor.withValues(alpha: 0.18),
                glowColor.withValues(alpha: 0.0),
              ]),
            ),
          ),

        // Orb body
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.70),
                ...gradientColors.map((c) => c.withValues(alpha: 0.55)),
                Colors.white.withValues(alpha: 0.20),
              ],
              stops: _equalStops(gradientColors.length + 2),
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.80),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 14,
                offset: const Offset(0, 5),
                spreadRadius: -2,
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.85),
                blurRadius: 6,
                offset: const Offset(-2, -3),
                spreadRadius: -2,
              ),
              if (glowColor != Colors.transparent)
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                  spreadRadius: 1,
                ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Icon
              Icon(icon, color: iconColor, size: 22),
              // Specular top-left crescent shine
              Positioned(
                top: 7,
                left: 7,
                child: Container(
                  width: 14,
                  height: 9,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(7),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.85),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static List<double> _equalStops(int count) {
    return List.generate(count, (i) => i / (count - 1));
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Main page
// ═════════════════════════════════════════════════════════════════════════════
class OnboardingPage2 extends ConsumerStatefulWidget {
  const OnboardingPage2({super.key});
  @override
  ConsumerState<OnboardingPage2> createState() => _OnboardingPage2State();
}

class _OnboardingPage2State extends ConsumerState<OnboardingPage2> {
  bool _cigarettes = false;
  bool _doomScrolling = false;
  bool _junkFood = false;
  bool _procrastination = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final habits = ref.read(onboardingProvider).badHabits;
      if (habits.isNotEmpty) {
        setState(() {
          _cigarettes = habits.contains('Cigarettes');
          _doomScrolling = habits.contains('Doom Scrolling');
          _junkFood = habits.contains('Junk Food');
          _procrastination = habits.contains('Procrastination');
        });
      }
    });
  }

  void _updateHabits() {
    final List<String> current = [];
    if (_cigarettes) current.add('Cigarettes');
    if (_doomScrolling) current.add('Doom Scrolling');
    if (_junkFood) current.add('Junk Food');
    if (_procrastination) current.add('Procrastination');
    ref.read(onboardingProvider.notifier).updateBadHabits(current);
  }

  // ── Single frosted-glass habit row with iridescent background ─────────────
  Widget _buildHabitRow({
    required IconData icon,
    required List<Color> orbGradient,
    required Color iconColor,
    required Color glowColor,
    // Iridescent tint colors for the row background
    required List<Color> rowTint,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.75),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
          // Inner highlight rim
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.50),
            blurRadius: 8,
            spreadRadius: -2,
            offset: const Offset(-1, -1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28.5),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Stack(
            children: [
              // ── Iridescent / oil-on-water background tint ──────────────
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.60),
                        rowTint[0].withValues(alpha: 0.28),
                        rowTint.length > 1
                            ? rowTint[1].withValues(alpha: 0.22)
                            : rowTint[0].withValues(alpha: 0.12),
                        Colors.white.withValues(alpha: 0.18),
                      ],
                      stops: const [0.0, 0.35, 0.65, 1.0],
                    ),
                  ),
                ),
              ),
              // ── Top thin specular line ───────────────────────────────
              Positioned(
                top: 0,
                left: 12,
                right: 12,
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Colors.white.withValues(alpha: 0.0),
                      Colors.white.withValues(alpha: 0.85),
                      Colors.white.withValues(alpha: 0.0),
                    ]),
                  ),
                ),
              ),
              // ── Row content ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                child: Row(
                  children: [
                    _GlassOrb(
                      icon: icon,
                      iconColor: iconColor,
                      gradientColors: orbGradient,
                      glowColor: glowColor,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A2E),
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                    _LiquidSwitch(value: value, onChanged: onChanged),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── "Add Custom Habit" glass pill ─────────────────────────────────────────
  Widget _buildAddCustomButton() {
    return GestureDetector(
      onTap: () {},
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.70),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.45),
              blurRadius: 8,
              spreadRadius: -2,
              offset: const Offset(-1, -1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28.5),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Stack(
              children: [
                // iridescent tint
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.55),
                          Colors.white.withValues(alpha: 0.28),
                          Colors.white.withValues(alpha: 0.18),
                        ],
                      ),
                    ),
                  ),
                ),
                // Specular top line
                Positioned(
                  top: 0,
                  left: 24,
                  right: 24,
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        Colors.white.withValues(alpha: 0.0),
                        Colors.white.withValues(alpha: 0.80),
                        Colors.white.withValues(alpha: 0.0),
                      ]),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.85),
                              Colors.white.withValues(alpha: 0.40),
                            ],
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.70),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.add, color: Color(0xFF5A5A72), size: 14),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Add Custom Habit',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3A3A55),
                          letterSpacing: -0.2,
                        ),
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

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top + kIndicatorOverlayH;
    final bottom = MediaQuery.of(context).padding.bottom + kButtonOverlayH;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(24, top + 20, 24, bottom + 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Title ──────────────────────────────────────────────────────────
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
                TextSpan(
                  text: 'Drop ',
                  style: TextStyle(color: Color(0xFFF97316)),
                ),
                TextSpan(text: 'Bad Habits'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Select habits you want Optivus to help you eliminate.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 28),

          // ── Liquid glass background panel ─────────────────────────────────
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(36),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.72),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.50),
                  blurRadius: 12,
                  spreadRadius: -3,
                  offset: const Offset(-2, -2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(34.5),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
                child: Stack(
                  children: [
                    // Glass fill — very translucent white gradient
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            stops: const [0.0, 0.35, 0.70, 1.0],
                            colors: [
                              Colors.white.withValues(alpha: 0.42),
                              Colors.white.withValues(alpha: 0.22),
                              Colors.white.withValues(alpha: 0.12),
                              Colors.white.withValues(alpha: 0.08),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Specular top-edge highlight line
                    Positioned(
                      top: 0,
                      left: 32,
                      right: 32,
                      child: Container(
                        height: 1.2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Colors.white.withValues(alpha: 0.0),
                            Colors.white.withValues(alpha: 0.90),
                            Colors.white.withValues(alpha: 0.0),
                          ]),
                        ),
                      ),
                    ),
                    // Content
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Cigarettes — warm amber / pink iridescence
                          _buildHabitRow(
                            icon: Icons.smoking_rooms_outlined,
                            orbGradient: [const Color(0xFFFFB87A), const Color(0xFFF97D6A)],
                            iconColor: const Color(0xFF92400E),
                            glowColor: const Color(0xFFFF9E5C),
                            rowTint: [const Color(0xFFFFC9A0), const Color(0xFFFFA0B0)],
                            title: 'Cigarettes',
                            value: _cigarettes,
                            onChanged: (v) {
                              setState(() => _cigarettes = v);
                              _updateHabits();
                            },
                          ),

                          // Doom Scrolling — sky blue with cyan iridescence
                          _buildHabitRow(
                            icon: Icons.phone_iphone_rounded,
                            orbGradient: [const Color(0xFF98E8FF), const Color(0xFF38BDF8)],
                            iconColor: const Color(0xFF0369A1),
                            glowColor: const Color(0xFF00CDCD),
                            rowTint: [const Color(0xFFB0E8FF), const Color(0xFFB0C8FF)],
                            title: 'Doom Scrolling',
                            value: _doomScrolling,
                            onChanged: (v) {
                              setState(() => _doomScrolling = v);
                              _updateHabits();
                            },
                          ),

                          // Junk Food — golden yellow / peach iridescence
                          _buildHabitRow(
                            icon: Icons.fastfood_rounded,
                            orbGradient: [const Color(0xFFFFE68A), const Color(0xFFFFB347)],
                            iconColor: const Color(0xFF78350F),
                            glowColor: const Color(0xFFF59E0B),
                            rowTint: [const Color(0xFFFFE9A0), const Color(0xFFFFD0A0)],
                            title: 'Junk Food',
                            value: _junkFood,
                            onChanged: (v) {
                              setState(() => _junkFood = v);
                              _updateHabits();
                            },
                          ),

                          // Procrastination — violet / lavender iridescence
                          _buildHabitRow(
                            icon: Icons.schedule_rounded,
                            orbGradient: [const Color(0xFFD9C4FF), const Color(0xFF9F7AEA)],
                            iconColor: const Color(0xFF4C1D95),
                            glowColor: const Color(0xFF8B5CF6),
                            rowTint: [const Color(0xFFD8B4FF), const Color(0xFFB4BCFF)],
                            title: 'Procrastination',
                            value: _procrastination,
                            onChanged: (v) {
                              setState(() => _procrastination = v);
                              _updateHabits();
                            },
                          ),

                          const SizedBox(height: 2),

                          // Add Custom Habit
                          _buildAddCustomButton(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
