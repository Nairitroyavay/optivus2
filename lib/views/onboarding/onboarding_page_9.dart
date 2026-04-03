import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:optivus2/views/screens/onboarding_screen.dart';
import 'package:optivus2/widgets/liquid_category_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// OnboardingPage9 — "Your AI Plan is Ready" pixel-perfect rewrite
//
// Flutter best-practice notes applied (2025):
//  • tileMode: TileMode.decal on ImageFilter.blur — prevents Impeller edge
//    artefacts on Android/iOS where clamp mode extends edge pixels.
//  • RepaintBoundary around each card — avoids GPU re-blur on scroll.
//  • withValues() throughout — no deprecated withOpacity().
// ─────────────────────────────────────────────────────────────────────────────
class OnboardingPage9 extends StatelessWidget {
  const OnboardingPage9({super.key});

  @override
  Widget build(BuildContext context) {
    final top    = MediaQuery.of(context).padding.top + kIndicatorOverlayH;
    final bottom = MediaQuery.of(context).padding.bottom + kButtonOverlayH;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, top + 16, 20, bottom + 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Hero title ─────────────────────────────────────────────────
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
                TextSpan(text: 'Your '),
                TextSpan(
                  text: 'AI Plan',
                  style: TextStyle(color: Color(0xFF6366F1)),
                ),
                TextSpan(text: ' is Ready'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Based on your inputs, Optvus has\ndesigned your optimal flow.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 24),

          // ──────────────────────────────────────────────────────────────
          // Daily Routine card
          // Iridescent gradient: ice-blue shimmer top-right → white center
          // ──────────────────────────────────────────────────────────────
          RepaintBoundary(
            child: _GlassCard(
              gradientColors: const [
                Color(0xFFD6E8FF), // soft icy blue — top-left
                Color(0xFFF0F6FF), // near-white blue
                Color(0xFFFFFFFF), // pure white center
                Color(0xFFF8F9FF), // hint of lavender bottom
              ],
              gradientBegin: Alignment.topLeft,
              gradientEnd: Alignment.bottomRight,
              gradientStops: const [0.0, 0.30, 0.65, 1.0],
              droplets: const [
                _DropSpec(right: 14, bottom: 14, size: 9,
                    color: Color(0xFF93C5FD), alpha: 0.50),
                _DropSpec(right: 27, bottom: 9,  size: 5,
                    color: Color(0xFFBFDBFE), alpha: 0.45),
              ],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        _SphereOrb(
                          icon: Icons.wb_sunny_rounded,
                          color: const Color(0xFF3B82F6),
                          bgStart: const Color(0xFFDBEAFE),
                          bgEnd: const Color(0xFFEFF6FF),
                        ),
                        const SizedBox(width: 10),
                        const Text('Daily Routine',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            )),
                      ]),
                      _PreviewChip(),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const _TimelineRow(time: '07:00 AM', title: 'Deep Work Session',    isActive: true,  isLast: false),
                  const _TimelineRow(time: '08:30 AM', title: 'Team Sync & Planning', isActive: false, isLast: true),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ──────────────────────────────────────────────────────────────
          // Top 3 Goals card
          // Iridescent: warm amber blush bottom-left → white
          // ──────────────────────────────────────────────────────────────
          RepaintBoundary(
            child: _GlassCard(
              gradientColors: const [
                Color(0xFFFFFFFF), // white
                Color(0xFFFFFBF0), // very subtle warm cream center
                Color(0xFFFFF3D0), // soft amber bottom-left glow
                Color(0xFFFFF9EC), // fade out
              ],
              gradientBegin: Alignment.topRight,
              gradientEnd: Alignment.bottomLeft,
              gradientStops: const [0.0, 0.40, 0.80, 1.0],
              droplets: const [
                _DropSpec(left: 14, bottom: 14, size: 9,
                    color: Color(0xFFFBBF24), alpha: 0.42),
                _DropSpec(left: 27, bottom: 9,  size: 5,
                    color: Color(0xFFFDE68A), alpha: 0.48),
              ],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        _SphereOrb(
                          icon: Icons.emoji_events_rounded,
                          color: const Color(0xFFF59E0B),
                          bgStart: const Color(0xFFFEF3C7),
                          bgEnd: const Color(0xFFFFF7ED),
                        ),
                        const SizedBox(width: 10),
                        const Text('Top 3 Goals',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            )),
                      ]),
                      const Icon(Icons.flag_rounded,
                          color: Color(0xFFD1D5DB), size: 26),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const _GoalRow(label: 'Launch MVP Product', checked: true),
                  const SizedBox(height: 8),
                  const _GoalRow(label: 'Run 5k Marathon',    checked: false),
                  const SizedBox(height: 8),
                  const _GoalRow(label: 'Read 2 books/mo',    checked: false),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ──────────────────────────────────────────────────────────────
          // Habit Focus card
          // Iridescent: strong mint-green wash across whole card
          // ──────────────────────────────────────────────────────────────
          RepaintBoundary(
            child: _GlassCard(
              gradientColors: const [
                Color(0xFFFFFFFF), // white top-right
                Color(0xFFEBFAF4), // very soft mint
                Color(0xFFD1FAE5), // mint wash — bottom-left
                Color(0xFFE8F9F2), // fade
              ],
              gradientBegin: Alignment.topRight,
              gradientEnd: Alignment.bottomLeft,
              gradientStops: const [0.0, 0.30, 0.75, 1.0],
              droplets: const [
                _DropSpec(right: 14, bottom: 14, size: 9,
                    color: Color(0xFF34D399), alpha: 0.42),
                _DropSpec(right: 27, bottom: 9,  size: 5,
                    color: Color(0xFF6EE7B7), alpha: 0.38),
              ],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    _SphereOrb(
                      icon: Icons.data_usage_rounded,
                      color: const Color(0xFF10B981),
                      bgStart: const Color(0xFFD1FAE5),
                      bgEnd: const Color(0xFFECFDF5),
                    ),
                    const SizedBox(width: 10),
                    const Text('Habit Focus',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        )),
                  ]),
                  const SizedBox(height: 20),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _RadialProgress(
                        icon: Icons.nightlight_round,
                        percentage: 75,
                        color: Color(0xFF3B82F6),
                        label: 'Sleep',
                      ),
                      _RadialProgress(
                        icon: Icons.fitness_center_rounded,
                        percentage: 60,
                        color: Color(0xFF10B981),
                        label: 'Fitness',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Compact drop-spec for const declarations
// ─────────────────────────────────────────────────────────────────────────────
class _DropSpec {
  final double? left, right, bottom;
  final double size;
  final Color color;
  final double alpha;

  const _DropSpec({
    this.left,
    this.right,
    this.bottom,
    required this.size,
    required this.color,
    required this.alpha,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// _GlassCard — iridescent frosted glass panel
//  • ClipRRect + BackdropFilter with TileMode.decal (Impeller-safe)
//  • Multi-stop gradient matching the reference's colour per card
//  • Single blur per card — no nested BackdropFilters
// ─────────────────────────────────────────────────────────────────────────────
class _GlassCard extends StatelessWidget {
  final Widget child;
  final List<Color> gradientColors;
  final Alignment gradientBegin;
  final Alignment gradientEnd;
  final List<double> gradientStops;
  final List<_DropSpec> droplets;

  const _GlassCard({
    required this.child,
    required this.gradientColors,
    required this.gradientBegin,
    required this.gradientEnd,
    required this.gradientStops,
    this.droplets = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Outer Glowing Gradient Rim ──
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
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
                  color: const Color(0xFFFF4D8D).withValues(alpha: 0.39),
                  blurRadius: 20,
                  offset: const Offset(-4, 0),
                ),
                BoxShadow(
                  color: const Color(0xFF40C4FF).withValues(alpha: 0.39),
                  blurRadius: 20,
                  offset: const Offset(4, 0),
                ),
              ],
            ),
          ),
        ),

        // ── Inner Frosted Card ──
        Container(
          margin: const EdgeInsets.all(3.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              // tileMode: TileMode.decal prevents Impeller edge-pixel extension artefacts
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18, tileMode: TileMode.decal),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: gradientBegin,
                    end: gradientEnd,
                    colors: gradientColors,
                    stops: gradientStops,
                  ),
                  boxShadow: [
                    // Top-left inner rim highlight (simulates glass thickness)
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.85),
                      blurRadius: 3,
                      offset: const Offset(-1, -1),
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
              // Top-left specular sheen (glass reflection effect)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: const Alignment(0.6, 0.5),
                      colors: [
                        Colors.white.withValues(alpha: 0.35),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),

              // Liquid droplet corner accents
              for (final d in droplets)
                Positioned(
                  left: d.left,
                  right: d.right,
                  bottom: d.bottom,
                  child: LiquidDroplet(
                    color: d.color.withValues(alpha: d.alpha),
                    size: d.size,
                  ),
                ),

              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: child,
              ),
            ],
          ),
        ),
      ),
    ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SphereOrb — section header icon
// Mimics the reference's frosted glass sphere with a soft radial gradient
// ─────────────────────────────────────────────────────────────────────────────
class _SphereOrb extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bgStart; // lighter tint
  final Color bgEnd;   // slightly deeper tint

  const _SphereOrb({
    required this.icon,
    required this.color,
    required this.bgStart,
    required this.bgEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.25, -0.35),
          radius: 0.85,
          colors: [
            Colors.white.withValues(alpha: 0.95),    // bright specular centre
            bgStart.withValues(alpha: 0.90),          // soft tint
            bgEnd.withValues(alpha: 0.80),            // rim
          ],
          stops: const [0.0, 0.50, 1.0],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.88),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
          // Inner top-left white highlight
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.90),
            blurRadius: 4,
            offset: const Offset(-1, -2),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 19),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// "Preview" chip — white glass pill, no nested BackdropFilter
// ─────────────────────────────────────────────────────────────────────────────
class _PreviewChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.80),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Text(
        'Preview',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF374151),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Timeline row — active dot with large blue ring + glow, inactive plain circle
// ─────────────────────────────────────────────────────────────────────────────
class _TimelineRow extends StatelessWidget {
  final String time;
  final String title;
  final bool isActive;
  final bool isLast;

  const _TimelineRow({
    required this.time,
    required this.title,
    required this.isActive,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Dot + vertical line
          SizedBox(
            width: 22,
            child: Column(children: [
              Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? const Color(0xFF3B82F6)
                      : Colors.white.withValues(alpha: 0.95),
                  border: Border.all(
                    // Active: thick pale-blue ring. Inactive: thin gray ring.
                    color: isActive
                        ? const Color(0xFFBADAFD)
                        : const Color(0xFFD1D5DB),
                    width: isActive ? 4.0 : 1.5,
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: const Color(0xFF3B82F6).withValues(alpha: 0.40),
                            blurRadius: 10,
                            spreadRadius: 1,
                          )
                        ]
                      : null,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Center(
                    child: Container(
                      width: 1.5,
                      color: const Color(0xFFDDE3EC),
                    ),
                  ),
                ),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(time,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      )),
                  const SizedBox(height: 2),
                  Text(title,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B8DAC),
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Goal row — white glass pill with gradient for subtle 3-D feel
// ─────────────────────────────────────────────────────────────────────────────
class _GoalRow extends StatelessWidget {
  final String label;
  final bool checked;

  const _GoalRow({required this.label, required this.checked});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFF8F9FC),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.80),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            checked ? Icons.check_circle : Icons.radio_button_unchecked,
            color: checked
                ? const Color(0xFF3B82F6)
                : const Color(0xFFD1D5DB),
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Radial progress — 270° arc ring with icon + percentage
// ─────────────────────────────────────────────────────────────────────────────
class _RadialProgress extends StatelessWidget {
  final IconData icon;
  final int percentage;
  final Color color;
  final String label;

  const _RadialProgress({
    required this.icon,
    required this.percentage,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 90,
          height: 90,
          child: CustomPaint(
            painter: _ArcPainter(
              value: percentage / 100,
              color: color,
              trackColor: color.withValues(alpha: 0.12),
              strokeWidth: 8.0,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 22),
                  const SizedBox(height: 3),
                  Text(
                    '$percentage%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            )),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 270° arc CustomPainter — starts at ~7 o'clock, sweeps clockwise
// ─────────────────────────────────────────────────────────────────────────────
class _ArcPainter extends CustomPainter {
  final double value;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  const _ArcPainter({
    required this.value,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2;
    final rect  = Rect.fromLTWH(
        inset, inset, size.width - strokeWidth, size.height - strokeWidth);

    // Track (full 270°)
    canvas.drawArc(
      rect,
      math.pi * 0.75,
      math.pi * 1.5,
      false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    // Value arc
    if (value > 0) {
      canvas.drawArc(
        rect,
        math.pi * 0.75,
        math.pi * 1.5 * value,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ArcPainter old) =>
      old.value != value || old.color != color || old.strokeWidth != strokeWidth;
}
