import 'dart:ui';
import 'package:flutter/material.dart';

class LiquidGlassCard extends StatelessWidget {
  final double width;
  final double height;
  final Widget? child;
  final double cornerRadius;
  final double tabDrop;

  const LiquidGlassCard({
    super.key,
    this.width = 340,
    this.height = 300,
    this.child,
    this.cornerRadius = 32.0,
    this.tabDrop = 40.0,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: [
            // ── 1. iOS-style gray frosted glass (ClipPath + BackdropFilter + blur) ──
            // BackdropFilter.blur is the only 100%-proven API for this in Flutter.
            // CupertinoPopupSurface uses the same underneath for its iOS material surface.
            ClipPath(
              clipper: _FolderClipper(cornerRadius: cornerRadius, tabDrop: tabDrop),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                child: Container(
                  decoration: const BoxDecoration(
                    // #E8E8ED is Apple's iOS system grouped background gray
                    color: Color(0xC8E8E8ED), // ~78% opacity matches iOS material
                  ),
                ),
              ),
            ),

            // ── 2. Top-left white sheen (gives glassy depth) ───────────
            ClipPath(
              clipper: _FolderClipper(cornerRadius: cornerRadius, tabDrop: tabDrop),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.22),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.50],
                  ),
                ),
              ),
            ),


            // ── 3. Border + drop shadow via CustomPainter ──────────────
            CustomPaint(
              size: Size(width, height),
              painter: _FolderGlassPainter(cornerRadius: cornerRadius, tabDrop: tabDrop),
            ),

            // ── 4. Content — ClipPath ensures scrollable children
            //    don't paint outside the glass card shape
            ClipPath(
              clipper: _FolderClipper(cornerRadius: cornerRadius, tabDrop: tabDrop),
              child: child ?? _buildDefaultContent(context),
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildDefaultContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Top left droplets area
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Little clear drops (just visual accents)
                      _buildClearDrop(context, 8, 8, Colors.white.withValues(alpha: 0.4)),
                      const SizedBox(width: 20),
                      _buildClearDrop(context, 10, 10, Colors.white.withValues(alpha: 0.4)),
                      const SizedBox(width: 4),
                      _buildClearDrop(context, 14, 14, Colors.white.withValues(alpha: 0.4)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const SizedBox(width: 4),
                      // Pink droplet
                      _buildColoredDrop(
                        const Color(0xFFF06292), // Pink
                        const Color(0xFFE91E63),
                        shadow: const Color(0x4DE91E63),
                      ),
                      const SizedBox(width: 12),
                      // Blue droplet
                      _buildColoredDrop(
                        const Color(0xFF64B5F6), // Blue
                        const Color(0xFF2196F3),
                        shadow: const Color(0x4D2196F3),
                      ),
                    ],
                  ),
                  
                  const Spacer(),
                  // Text Area
                  const Text(
                    'Liquid glass\nUI kidd kit',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E242C), // Dark slate/charcoal
                      height: 1.15,
                      letterSpacing: -0.5,
                    ),
                  ),
                  
                  const Spacer(),
                  // The Button
                  _buildUpgradeButton(),
                  const SizedBox(height: 12),
                ],
              ),
    );
  }

  // Build the colorful 3D droplets
  Widget _buildColoredDrop(Color lightColor, Color darkColor, {required Color shadow}) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.8), // Strong highlight
            lightColor,
            darkColor,
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
        boxShadow: [
          // Colored contact shadow
          BoxShadow(
            color: shadow,
            offset: const Offset(4, 8),
            blurRadius: 10,
          ),
          // Inner glow
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.8),
            offset: const Offset(-2, -2),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }

  // Build the clear water droplets
  Widget _buildClearDrop(BuildContext context, double w, double h, Color baseColor) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: baseColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(2, 4),
            blurRadius: 4,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.8),
            offset: const Offset(-1, -1),
            blurRadius: 2,
          ),
        ],
      ),
    );
  }

  // Build the 'Upgrade plan' glass button
  Widget _buildUpgradeButton() {
    return Container(
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        color: Colors.white.withValues(alpha: 0.1),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          // Soft outer drop shadow
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 12),
            blurRadius: 20,
          ),
          // Bright inner top rim highlight
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.7),
            offset: const Offset(0, 4),
            blurRadius: 8,
          ),
          // Soft inner bottom shadow for depth
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -4),
            blurRadius: 8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: const Center(
            child: Text(
              'Upgrade plan',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E242C),
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Custom Shape Logic Below
// ─────────────────────────────────────────────────────────────

Path _getFolderShape(Size size, double r, double tabDrop) {
  final double tabWidth = size.width * 0.45; // Width of the high tab

  final Path path = Path();
  // Start top-left
  path.moveTo(0, r);
  // Top-left corner
  path.quadraticBezierTo(0, 0, r, 0);
  // Top tab flat part
  path.lineTo(tabWidth - 25, 0);
  // S-curve down to the lower top edge
  path.cubicTo(
    tabWidth + 5, 0,
    tabWidth + 5, tabDrop,
    tabWidth + 35, tabDrop,
  );
  // Lower top edge
  path.lineTo(size.width - r, tabDrop);
  // Top-right corner
  path.quadraticBezierTo(size.width, tabDrop, size.width, tabDrop + r);
  // Right edge
  path.lineTo(size.width, size.height - r);
  // Bottom-right corner
  path.quadraticBezierTo(size.width, size.height, size.width - r, size.height);
  // Bottom edge
  path.lineTo(r, size.height);
  // Bottom-left corner
  path.quadraticBezierTo(0, size.height, 0, size.height - r);
  // Close back to top-left
  path.close();

  return path;
}

class _FolderClipper extends CustomClipper<Path> {
  final double cornerRadius;
  final double tabDrop;

  _FolderClipper({required this.cornerRadius, required this.tabDrop});

  @override
  Path getClip(Size size) {
    return _getFolderShape(size, cornerRadius, tabDrop);
  }

  @override
  bool shouldReclip(covariant _FolderClipper oldClipper) =>
      oldClipper.cornerRadius != cornerRadius || oldClipper.tabDrop != tabDrop;
}

class _FolderGlassPainter extends CustomPainter {
  final double cornerRadius;
  final double tabDrop;

  _FolderGlassPainter({required this.cornerRadius, required this.tabDrop});

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = _getFolderShape(size, cornerRadius, tabDrop);

    // 1. Drop shadow behind the whole card
    canvas.drawShadow(
      path,
      Colors.black.withValues(alpha: 0.08),
      20.0,
      false, // transparentOccluder
    );

    // 2. Thick glassy border (Outer/Inner Highlight)
    // Create a gradient for the border to look like light hitting glass
    final Paint borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.9), // Bright top-left reflection
          Colors.white.withValues(alpha: 0.1),
          Colors.white.withValues(alpha: 0.5), // Soft bottom-right reflection
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(path, borderPaint);

    // 3. Optional inner gloss (recessed edge effect)
    // Draw a slightly shifted path with a softer brush
    final Path innerPath = path.shift(const Offset(1.5, 1.5));
    final Paint innerBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.white.withValues(alpha: 0.6);
    // Use clip to ensure inner gloss doesn't bleed out
    canvas.save();
    canvas.clipPath(path);
    canvas.drawPath(innerPath, innerBorderPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
