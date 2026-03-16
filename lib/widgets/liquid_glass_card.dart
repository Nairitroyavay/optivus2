import 'dart:ui';
import 'package:flutter/material.dart';

/// An exact replica of the "Liquid Glass" folder-style card from the reference.
class LiquidGlassCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback? onButtonPressed;
  final List<Widget>? children;

  const LiquidGlassCard({
    super.key,
    this.title = 'Liquid glass',
    this.subtitle = 'UI kidd kit',
    this.buttonText = 'Upgrade plan',
    this.onButtonPressed,
    this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 280),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _FolderShapePainter(),
        child: ClipPath(
          clipper: _FolderShapeClipper(),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Stack(
                children: [
                  // Inner highlights
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.4),
                            Colors.white.withValues(alpha: 0.0),
                            Colors.black.withValues(alpha: 0.02),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Accents: Liquid Droplets
                  const Positioned(
                    top: 24,
                    left: 24,
                    child: _LiquidDropletAccents(),
                  ),

                  // Content
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (children != null) ...children! else ...[
                          const SizedBox(height: 20),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1F2937),
                              letterSpacing: -1.0,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            subtitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1F2937),
                              letterSpacing: -1.0,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 40),
                          _GlassPillButton(
                            text: buttonText,
                            onPressed: onButtonPressed,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiquidDropletAccents extends StatelessWidget {
  const _LiquidDropletAccents();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _Droplet(color: Colors.white.withValues(alpha: 0.4), size: 7),
            const SizedBox(width: 10),
            _Droplet(color: Colors.white.withValues(alpha: 0.4), size: 5),
            const SizedBox(width: 8),
            _Droplet(color: Colors.white.withValues(alpha: 0.4), size: 9),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const _Droplet(
              color: Color(0xFFFF4D6D),
              size: 22,
              hasGlow: true,
            ),
            const SizedBox(width: 16),
            const _Droplet(
              color: Color(0xFF4CC9F0),
              size: 22,
              hasGlow: true,
            ),
          ],
        ),
      ],
    );
  }
}

class _Droplet extends StatelessWidget {
  final Color color;
  final double size;
  final bool hasGlow;

  const _Droplet({
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
          center: const Alignment(-0.4, -0.4),
          colors: [
            Colors.white.withValues(alpha: 0.9),
            color,
            color.withValues(alpha: 0.7),
          ],
          stops: const [0.0, 0.3, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(1, 2),
          ),
          if (hasGlow)
            BoxShadow(
              color: color.withValues(alpha: 0.5),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
    );
  }
}

class _GlassPillButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;

  const _GlassPillButton({required this.text, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 40),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.6),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(34),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.4),
                    Colors.white.withValues(alpha: 0.05),
                  ],
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Top Shine
                  Positioned(
                    top: 6,
                    left: 20,
                    right: 20,
                    child: Container(
                      height: 14,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.7),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FolderShapePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;
    canvas.drawPath(_getFolderTabPath(size), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FolderShapeClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => _getFolderTabPath(size);
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldDelegate) => false;
}

Path _getFolderTabPath(Size size) {
  final path = Path();
  const double r = 45.0; // Corner radius
  const double tabWidth = 140.0;
  const double tabHeight = 35.0;
  const double curveRadius = 30.0;

  // Start at bottom-left
  path.moveTo(0, size.height - r);
  path.quadraticBezierTo(0, size.height, r, size.height);
  
  // Bottom edge
  path.lineTo(size.width - r, size.height);
  path.quadraticBezierTo(size.width, size.height, size.width, size.height - r);
  
  // Right edge
  path.lineTo(size.width, r);
  path.quadraticBezierTo(size.width, 0, size.width - r, 0);
  
  // Top edge (main body)
  path.lineTo(tabWidth + curveRadius, 0);
  
  // Curve up to the tab
  path.cubicTo(
    tabWidth + curveRadius / 2, 0,
    tabWidth + curveRadius / 2, -tabHeight,
    tabWidth, -tabHeight,
  );
  
  // Top of the tab
  path.lineTo(r, -tabHeight);
  path.quadraticBezierTo(0, -tabHeight, 0, -tabHeight + r);
  
  // Back down to main body height
  path.lineTo(0, size.height - r);
  
  path.close();

  // Shift the path so the tab is visible within bounds
  return path.shift(const Offset(0, tabHeight));
}
