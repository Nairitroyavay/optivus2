
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LiquidCategoryCard — iOS liquid glass folder-tab card with animated states
// ─────────────────────────────────────────────────────────────────────────────
class LiquidCategoryCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color primaryColor;
  final bool isSelected;
  final VoidCallback onTap;
  final List<Widget>? customDroplets;

  const LiquidCategoryCard({
    super.key,
    required this.title,
    required this.icon,
    required this.primaryColor,
    required this.isSelected,
    required this.onTap,
    this.customDroplets,
  });

  @override
  State<LiquidCategoryCard> createState() => _LiquidCategoryCardState();
}

class _LiquidCategoryCardState extends State<LiquidCategoryCard>
    with SingleTickerProviderStateMixin {
  // Ripple pulse controller — fires once on each tap
  late final AnimationController _rippleCtrl;
  late final Animation<double> _rippleScale;
  late final Animation<double> _rippleOpacity;

  @override
  void initState() {
    super.initState();
    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _rippleScale = Tween<double>(begin: 0.6, end: 1.55).animate(
      CurvedAnimation(parent: _rippleCtrl, curve: Curves.easeOutCubic),
    );
    _rippleOpacity = Tween<double>(begin: 0.55, end: 0.0).animate(
      CurvedAnimation(parent: _rippleCtrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _rippleCtrl.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    _rippleCtrl.forward(from: 0);
    widget.onTap();
  }

  // ── Glass orb — unselected (neutral liquid drop) ───────────────────────────
  Widget _glassOrb(Color c) {
    const double s = 36.0;
    return Container(
      width: s, height: s,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Radial: light translucent centre → lavender → cooler rim
        gradient: const RadialGradient(
          center: Alignment(0.0, 0.15),
          radius: 0.88,
          colors: [
            Color(0xCCEEEFF8),  // translucent light lavender centre
            Color(0xFFD8DAE8),  // mid lavender
            Color(0xFFC4C7D8),  // slightly darker rim
          ],
          stops: [0.0, 0.58, 1.0],
        ),
        border: Border.all(color: const Color(0xFFD0D3E4), width: 2.0),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4)),
          BoxShadow(color: Color(0xCCFFFFFF), blurRadius: 6, offset: Offset(-2, -3)),
        ],
      ),
      child: ClipOval(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Large top-half bright highlight — the key liquid glass effect
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                height: s * 0.50,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xCCFFFFFF), Color(0x00FFFFFF)],
                  ),
                ),
              ),
            ),
            // Small crescent at top-left
            Positioned(
              top: 5, left: 6,
              child: Container(
                width: 16, height: 9,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0xDDFFFFFF), Color(0x00FFFFFF)],
                  ),
                ),
              ),
            ),
            // Icon
            Icon(widget.icon, size: 18, color: const Color(0xFF4A4D68).withValues(alpha: 0.80)),
          ],
        ),
      ),
    );
  }

  // ── Liquid colour orb — selected (vivid liquid drop) ───────────────────────
  Widget _colorOrb(Color c) {
    const double s = 36.0;
    final rim   = _darken(c, 0.10);
    final light = _lighten(c, 0.30);
    return Container(
      width: s, height: s,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Radial: translucent tint centre → full colour → dark rim
        gradient: RadialGradient(
          center: const Alignment(0.0, 0.15),
          radius: 0.90,
          colors: [
            light.withValues(alpha: 0.60),  // glassy centre
            c.withValues(alpha: 0.92),       // full colour mid
            rim,                             // dark rim
          ],
          stops: const [0.0, 0.60, 1.0],
        ),
        border: Border.all(color: rim.withValues(alpha: 0.75), width: 2.2),
        boxShadow: [
          // Coloured outer glow
          BoxShadow(color: c.withValues(alpha: 0.45), blurRadius: 22, offset: const Offset(0, 6), spreadRadius: -2),
          // Lift shadow
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 10, offset: const Offset(0, 4)),
          // Top inner-light
          BoxShadow(color: Colors.white.withValues(alpha: 0.70), blurRadius: 5, offset: const Offset(-2, -3)),
        ],
      ),
      child: ClipOval(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ── LARGE top-half bright highlight — makes it look like a liquid drop
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                height: s * 0.52,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xCCFFFFFF), Color(0x00FFFFFF)],
                  ),
                ),
              ),
            ),
            // Small tight crescent at top-left (specular)
            Positioned(
              top: 5, left: 6,
              child: Container(
                width: 16, height: 9,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0xEEFFFFFF), Color(0x00FFFFFF)],
                  ),
                ),
              ),
            ),
            // Icon — white with colour shadow
            Icon(widget.icon, size: 18, color: Colors.white,
              shadows: [Shadow(color: rim.withValues(alpha: 0.55), blurRadius: 5)]),
          ],
        ),
      ),
    );
  }


  // ── Combined orb: AnimatedOpacity crossfade between the two layers ─────────
  // WHY not AnimatedContainer? .lerp() cannot interpolate between gradients
  // with different stop counts (3 vs 4 stops) — it snaps visually.
  Widget _buildOrb() {
    final c   = widget.primaryColor;
    final sel = widget.isSelected;

    return SizedBox(
      width: 50, height: 50,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Ripple ring expands on tap
          AnimatedBuilder(
            animation: _rippleCtrl,
            builder: (_, __) => Opacity(
              opacity: _rippleOpacity.value,
              child: Transform.scale(
                scale: _rippleScale.value,
                child: Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: c.withValues(alpha: 0.48), width: 1.5),
                  ),
                ),
              ),
            ),
          ),

          // Glass orb fades OUT on select
          AnimatedOpacity(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOut,
            opacity: sel ? 0.0 : 1.0,
            child: _glassOrb(c),
          ),

          // Colour orb fades IN on select
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            opacity: sel ? 1.0 : 0.0,
            child: _colorOrb(c),
          ),

          // Checkmark springs in with elasticOut
          Positioned(
            top: 4, right: 4,
            child: AnimatedScale(
              scale: sel ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 320),
              curve: Curves.elasticOut,
              child: Container(
                width: 16, height: 16,
                decoration: BoxDecoration(
                  color: c, shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [BoxShadow(color: c.withValues(alpha: 0.45), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 9),
              ),
            ),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final c = widget.primaryColor;
    final sel = widget.isSelected;

    return GestureDetector(
      onTap: _handleTap,
      child: CustomPaint(
          painter: _FolderBorderPainter(isSelected: sel, primaryColor: c),
          child: ClipPath(
            clipper: _FolderClipper(),
            // ── NO BackdropFilter here — nesting it inside an outer
            // BackdropFilter (the LiquidGlassCard) causes visual artifacts
            // at the clip edges. The outer card already provides the blur.
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  // High-opacity white so cards clearly stand out from the
                  // big glass card's gray tint (0xC8E8E8ED)
                  colors: [
                    Colors.white.withValues(alpha: sel ? 0.96 : 0.88),
                    const Color(0xFFF3F4F8).withValues(alpha: sel ? 0.80 : 0.72),
                    const Color(0xFFE8EAF0).withValues(alpha: sel ? 0.65 : 0.55),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  // Top-left sheen overlay
                  Positioned.fill(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 350),
                      opacity: sel ? 1.0 : 0.5,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: sel ? 0.44 : 0.26),
                              Colors.white.withValues(alpha: 0.0),
                              const Color(0xFFCCD0DC).withValues(alpha: 0.05),
                            ],
                            stops: const [0.0, 0.45, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Decorative droplets
                  if (widget.customDroplets != null) ...widget.customDroplets!,

                  // Content
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 4),

                        // Icon orb — single widget, transitions in-place
                        _buildOrb(),

                        const SizedBox(height: 4),

                        // Title
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 300),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: sel ? c : const Color(0xFF1A2035),
                            letterSpacing: -0.3,
                            height: 1.1,
                          ),
                          child: Text(
                            widget.title,
                            textAlign: TextAlign.center,
                          ),
                        ),

                        const SizedBox(height: 2),
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
}

// ── Colour helpers ────────────────────────────────────────────────────────────
Color _lighten(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  return hsl
      .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
      .toColor();
}

Color _darken(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  return hsl
      .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
      .toColor();
}

// ─────────────────────────────────────────────────────────────────────────────
// 3D liquid glass droplet sphere
// ─────────────────────────────────────────────────────────────────────────────
class LiquidDroplet extends StatelessWidget {
  final Color color;
  final double size;
  final bool hasGlow;

  const LiquidDroplet({
    super.key,
    required this.color,
    required this.size,
    this.hasGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 0.9,
          colors: [
            Colors.white.withValues(alpha: 0.95),
            color.withValues(alpha: 0.80),
            color,
          ],
          stops: const [0.0, 0.35, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 3,
            offset: const Offset(1, 2),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.65),
            blurRadius: 2,
            offset: const Offset(-1, -1),
          ),
          if (hasGlow)
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 7,
              spreadRadius: 1,
              offset: const Offset(0, 2),
            ),
        ],
      ),
    );
  }
}

// ── Folder Shape — tab on TOP-RIGHT, fully within widget bounds ──────────────
Path _getFolderTabPath(Size size) {
  const double r       = 18.0;  // body corner radius
  const double tabH    = 10.0;  // tab height (top portion of widget)
  const double tabW    = 50.0;  // tab width
  const double kCurve  = 13.0;  // tab-entry transition curve

  // Layout:
  //   y = 0          → tab top edge
  //   y = tabH       → body top edge
  //   y = size.height → body bottom edge
  // This way the path is entirely inside [0, size.height] and NO shift is needed.

  final path = Path();

  // ── Start: left body mid-point
  path.moveTo(0, size.height - r);

  // ── Bottom-left corner
  path.quadraticBezierTo(0, size.height, r, size.height);
  // ── Bottom edge →
  path.lineTo(size.width - r, size.height);
  // ── Bottom-right corner
  path.quadraticBezierTo(size.width, size.height, size.width, size.height - r);
  // ── Right side ↑ to tab top (right side goes all the way up to y=0)
  path.lineTo(size.width, r);
  // ── Top-right corner of tab
  path.quadraticBezierTo(size.width, 0, size.width - r, 0);
  // ── Tab top ← (going left at y=0)
  path.lineTo(size.width - tabW, 0);
  // ── Tab left side curves from y=0 down to body top (y=tabH)
  path.cubicTo(
    size.width - tabW - kCurve * 0.5, 0,
    size.width - tabW - kCurve * 0.5, tabH,
    size.width - tabW - kCurve,       tabH,
  );
  // ── Body top ← (going left at y=tabH)
  path.lineTo(r, tabH);
  // ── Top-left corner of body
  path.quadraticBezierTo(0, tabH, 0, tabH + r);
  // ── Left side ↓ back to start
  path.lineTo(0, size.height - r);
  path.close();

  // No shift — path already fits within [0, size.height]
  return path;
}

class _FolderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => _getFolderTabPath(size);
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldDelegate) => false;
}

class _FolderBorderPainter extends CustomPainter {
  final bool isSelected;
  final Color primaryColor;
  _FolderBorderPainter({required this.isSelected, required this.primaryColor});

  @override
  void paint(Canvas canvas, Size size) {
    final path = _getFolderTabPath(size);
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // ── Soft drop shadow — gives card physical lift above big glass card
    canvas.drawShadow(
      path,
      Colors.black.withValues(alpha: isSelected ? 0.14 : 0.08),
      isSelected ? 10.0 : 6.0,
      false,
    );

    // ── Primary border — 1.8px so stroke stays within the clip boundary.
    // Thicker strokes (4-5px) bleed half their width OUTSIDE the path,
    // which leaks into neighbouring card space.
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isSelected
            ? [
                Colors.white.withValues(alpha: 0.98),
                const Color(0xFFC0C8E0).withValues(alpha: 0.60),
                Colors.white.withValues(alpha: 0.88),
              ]
            : [
                Colors.white.withValues(alpha: 0.82),
                const Color(0xFFB8C0D8).withValues(alpha: 0.50),
                Colors.white.withValues(alpha: 0.70),
              ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawPath(path, borderPaint);

    // ── Thin bright specular highlight (top-left edge only)
    final highlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: const Alignment(0.4, 0.4),
        colors: [
          Colors.white.withValues(alpha: 0.88),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(rect);
    canvas.drawPath(path, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant _FolderBorderPainter oldDelegate) =>
      oldDelegate.isSelected != isSelected ||
      oldDelegate.primaryColor != primaryColor;
}
