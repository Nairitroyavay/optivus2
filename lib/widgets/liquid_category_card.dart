import 'dart:ui';
import 'package:flutter/material.dart';
<<<<<<< Updated upstream

/// A premium "Mini Folder" Liquid Glass card.
/// Optimized for grid layouts with a clear tab and realistic resin effects.
class LiquidCategoryCard extends StatelessWidget {
=======
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LiquidCategoryCard — iOS liquid glass folder-tab card with animated states
// ─────────────────────────────────────────────────────────────────────────────
class LiquidCategoryCard extends StatefulWidget {
>>>>>>> Stashed changes
  final String title;
  final IconData icon;
  final Color primaryColor;
  final bool isSelected;
  final VoidCallback onTap;
<<<<<<< Updated upstream
=======
  final List<Widget>? customDroplets;
>>>>>>> Stashed changes

  const LiquidCategoryCard({
    super.key,
    required this.title,
    required this.icon,
    required this.primaryColor,
    required this.isSelected,
    required this.onTap,
<<<<<<< Updated upstream
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: isSelected ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        child: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: isSelected 
                    ? primaryColor.withValues(alpha: 0.25) 
                    : Colors.black.withValues(alpha: 0.06),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: CustomPaint(
            painter: _FolderShapePainter(isSelected: isSelected, color: primaryColor),
            child: ClipPath(
              clipper: _FolderShapeClipper(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: isSelected ? 0.45 : 0.2),
                    border: Border.all(
                      color: isSelected 
                          ? primaryColor.withValues(alpha: 0.8) 
                          : Colors.white.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Inner Sheen & Depth
                      _buildReflections(),
                      
                      // Miniature Reference Droplets (Top-Left Tab area)
                      const Positioned(
                        top: 6,
                        left: 12,
                        child: _MiniDroplets(),
                      ),

                      // Selection Indicator (Top-Right)
                      if (isSelected)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: primaryColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                )
                              ],
                            ),
                            child: const Icon(Icons.check, color: Colors.white, size: 12),
                          ),
                        ),

                      // Main Content: Icon and Text
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 12), // Offset for the top tab
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected 
                                    ? primaryColor.withValues(alpha: 0.15) 
                                    : Colors.white.withValues(alpha: 0.2),
                              ),
                              child: Icon(
                                icon,
                                color: isSelected ? primaryColor : const Color(0xFF1F2937).withValues(alpha: 0.5),
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1F2937),
                                letterSpacing: -0.5,
                                height: 1.1,
                                shadows: isSelected ? [
                                  Shadow(
                                    color: primaryColor.withValues(alpha: 0.2),
                                    blurRadius: 8,
                                  )
                                ] : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
=======
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

  // ── Liquid colour orb (selected) ──────────────────────────────────────────
  Widget _buildSelectedOrb() {
    final c = widget.primaryColor;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // Animated glow ring (ripple pulse on tap)
        AnimatedBuilder(
          animation: _rippleCtrl,
          builder: (_, __) => Opacity(
            opacity: _rippleOpacity.value,
            child: Transform.scale(
              scale: _rippleScale.value,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: c.withValues(alpha: 0.6),
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
        ),

        // Outer ambient glow halo — always visible when selected
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              c.withValues(alpha: 0.22),
              c.withValues(alpha: 0.0),
            ]),
          ),
        ),

        // Orb body — liquid colour sphere
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Liquid radial gradient: bright white → primaryColor tones
            gradient: RadialGradient(
              center: const Alignment(-0.30, -0.45),
              radius: 0.90,
              colors: [
                Colors.white.withValues(alpha: 0.95),       // top-left specular
                _lighten(c, 0.30).withValues(alpha: 0.88),  // bright mid
                c,                                           // rich core
                _darken(c, 0.18),                           // deep edge
              ],
              stops: const [0.0, 0.28, 0.62, 1.0],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.80),
              width: 1.8,
            ),
            boxShadow: [
              BoxShadow(
                color: c.withValues(alpha: 0.38),
                blurRadius: 20,
                offset: const Offset(0, 6),
                spreadRadius: -2,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 5),
                spreadRadius: -3,
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.90),
                blurRadius: 8,
                offset: const Offset(-3, -4),
                spreadRadius: -3,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Icon in white/dark contrast
              Icon(
                widget.icon,
                size: 20,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: _darken(c, 0.25).withValues(alpha: 0.45),
                    blurRadius: 6,
                  ),
                ],
              ),
              // Specular top-left crescent highlight
              Positioned(
                top: 7,
                left: 7,
                child: Container(
                  width: 14,
                  height: 9,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
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

        // Checkmark badge — uses primaryColor
        Positioned(
          top: 2,
          right: 2,
          child: AnimatedScale(
            scale: widget.isSelected ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: widget.primaryColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: widget.primaryColor.withValues(alpha: 0.50),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 10),
            ),
          ),
        ),
      ],
    );
  }

  // ── Plain glass orb (unselected) ─────────────────────────────────────────
  Widget _buildUnselectedOrb() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.25, -0.35),
          radius: 0.85,
          colors: [
            Colors.white.withValues(alpha: 0.68),
            Colors.white.withValues(alpha: 0.28),
            Colors.white.withValues(alpha: 0.08),
          ],
          stops: const [0.0, 0.50, 1.0],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.50),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        widget.icon,
        size: 20,
        color: const Color(0xFF1A2035).withValues(alpha: 0.72),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.primaryColor;
    final sel = widget.isSelected;

    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedScale(
        scale: sel ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutBack,
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
                  // Neutral milky white — NO color tint, both states
                  colors: [
                    Colors.white.withValues(alpha: sel ? 0.62 : 0.38),
                    const Color(0xFFEEF0F5).withValues(alpha: sel ? 0.50 : 0.28),
                    const Color(0xFFDDE0EC).withValues(alpha: sel ? 0.30 : 0.15),
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
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 10),

                        // Icon orb
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 380),
                          switchInCurve: Curves.easeOutBack,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, anim) => ScaleTransition(
                            scale: anim,
                            child: FadeTransition(opacity: anim, child: child),
                          ),
                          child: sel
                              ? KeyedSubtree(
                                  key: const ValueKey('selected'),
                                  child: _buildSelectedOrb(),
                                )
                              : KeyedSubtree(
                                  key: const ValueKey('unselected'),
                                  child: _buildUnselectedOrb(),
                                ),
                        ),

                        const SizedBox(height: 8),

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

                        // "Selected" pill badge
                        AnimatedSize(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                          child: sel
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: c.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: c.withValues(alpha: 0.35),
                                        width: 1.0,
                                      ),
                                    ),
                                    child: Text(
                                      'Selected',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: c,
                                        letterSpacing: 0.1,
                                      ),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ],
>>>>>>> Stashed changes
              ),
            ),
          ),
        ),
      ),
    );
  }
<<<<<<< Updated upstream

  Widget _buildReflections() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.4),
              Colors.white.withValues(alpha: 0.0),
              Colors.black.withValues(alpha: 0.03),
            ],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
      ),
    );
  }
}

class _MiniDroplets extends StatelessWidget {
  const _MiniDroplets();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _Droplet(color: Colors.white.withValues(alpha: 0.4), size: 3),
            const SizedBox(width: 4),
            _Droplet(color: Colors.white.withValues(alpha: 0.4), size: 5),
          ],
        ),
        const SizedBox(height: 4),
        const Row(
          children: [
            _Droplet(color: Color(0xFFFF4D6D), size: 8, hasGlow: true), 
            SizedBox(width: 6),
            _Droplet(color: Color(0xFF4CC9F0), size: 8, hasGlow: true),
          ],
        ),
      ],
    );
  }
}

class _Droplet extends StatelessWidget {
=======
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
>>>>>>> Stashed changes
  final Color color;
  final double size;
  final bool hasGlow;

<<<<<<< Updated upstream
  const _Droplet({required this.color, required this.size, this.hasGlow = false});
=======
  const LiquidDroplet({
    super.key,
    required this.color,
    required this.size,
    this.hasGlow = false,
  });
>>>>>>> Stashed changes

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
<<<<<<< Updated upstream
          center: const Alignment(-0.4, -0.4),
          colors: [Colors.white.withValues(alpha: 0.9), color, color.withValues(alpha: 0.8)],
          stops: const [0.0, 0.3, 1.0],
        ),
        boxShadow: [
          if (hasGlow)
            BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 1)),
=======
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
>>>>>>> Stashed changes
        ],
      ),
    );
  }
}

<<<<<<< Updated upstream
class _FolderShapePainter extends CustomPainter {
  final bool isSelected;
  final Color color;
  _FolderShapePainter({required this.isSelected, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isSelected ? color.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.02)
      ..style = PaintingStyle.fill;
    canvas.drawPath(_getFolderTabPath(size), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _FolderShapeClipper extends CustomClipper<Path> {
=======
// ── Folder Shape — tab on TOP-RIGHT (matches reference) ─────────────────────
Path _getFolderTabPath(Size size) {
  const double r       = 18.0;  // body corner radius
  const double tabH    = 10.0;  // how far tab protrudes above body top
  const double tabW    = 50.0;  // tab width
  const double kCurve  = 13.0;  // tab-entry transition curve

  final path = Path();
  // Trace clockwise starting from the left side mid-point:
  path.moveTo(0, size.height - r);

  // ── Bottom-left corner
  path.quadraticBezierTo(0, size.height, r, size.height);
  // ── Bottom edge →
  path.lineTo(size.width - r, size.height);
  // ── Bottom-right corner
  path.quadraticBezierTo(size.width, size.height, size.width, size.height - r);
  // ── Right side ↑ — goes all the way up to TAB TOP (tab is on the right)
  path.lineTo(size.width, -tabH + r);
  // ── Top-right corner of tab
  path.quadraticBezierTo(size.width, -tabH, size.width - r, -tabH);
  // ── Tab top ← (going left)
  path.lineTo(size.width - tabW, -tabH);
  // ── Tab left side curves back down to body top level
  path.cubicTo(
    size.width - tabW - kCurve * 0.5, -tabH,
    size.width - tabW - kCurve * 0.5, 0,
    size.width - tabW - kCurve, 0,
  );
  // ── Body top ← (going left across the rest of top edge)
  path.lineTo(r, 0);
  // ── Top-left corner of body
  path.quadraticBezierTo(0, 0, 0, r);
  // ── Left side ↓ back to start
  path.lineTo(0, size.height - r);
  path.close();

  return path.shift(const Offset(0, tabH));
}

class _FolderClipper extends CustomClipper<Path> {
>>>>>>> Stashed changes
  @override
  Path getClip(Size size) => _getFolderTabPath(size);
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldDelegate) => false;
}

<<<<<<< Updated upstream
Path _getFolderTabPath(Size size) {
  final path = Path();
  const double r = 24.0; // Body corner radius
  const double tabHeight = 16.0;
  const double tabWidth = 56.0;
  const double tabCurve = 16.0;

  // Bottom-left
  path.moveTo(0, size.height - r);
  path.quadraticBezierTo(0, size.height, r, size.height);
  
  // Bottom-right
  path.lineTo(size.width - r, size.height);
  path.quadraticBezierTo(size.width, size.height, size.width, size.height - r);
  
  // Top-right
  path.lineTo(size.width, r);
  path.quadraticBezierTo(size.width, 0, size.width - r, 0);
  
  // Main top edge
  path.lineTo(tabWidth + tabCurve, 0);
  
  // Transition to Tab
  path.cubicTo(
    tabWidth + tabCurve / 2, 0,
    tabWidth + tabCurve / 2, -tabHeight,
    tabWidth, -tabHeight,
  );
  
  // Tab top
  path.lineTo(r, -tabHeight);
  path.quadraticBezierTo(0, -tabHeight, 0, -tabHeight + r);

  path.lineTo(0, size.height - r);
  path.close();

  return path.shift(const Offset(0, tabHeight));
=======
class _FolderBorderPainter extends CustomPainter {
  final bool isSelected;
  final Color primaryColor;
  _FolderBorderPainter({required this.isSelected, required this.primaryColor});

  @override
  void paint(Canvas canvas, Size size) {
    final path = _getFolderTabPath(size);
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

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
>>>>>>> Stashed changes
}
