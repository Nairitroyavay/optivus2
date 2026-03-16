import 'dart:ui';
import 'package:flutter/material.dart';

/// A premium "Mini Folder" Liquid Glass card.
/// Optimized for grid layouts with a clear tab and realistic resin effects.
class LiquidCategoryCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color primaryColor;
  final bool isSelected;
  final VoidCallback onTap;

  const LiquidCategoryCard({
    super.key,
    required this.title,
    required this.icon,
    required this.primaryColor,
    required this.isSelected,
    required this.onTap,
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
              ),
            ),
          ),
        ),
      ),
    );
  }

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
  final Color color;
  final double size;
  final bool hasGlow;

  const _Droplet({required this.color, required this.size, this.hasGlow = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.4, -0.4),
          colors: [Colors.white.withValues(alpha: 0.9), color, color.withValues(alpha: 0.8)],
          stops: const [0.0, 0.3, 1.0],
        ),
        boxShadow: [
          if (hasGlow)
            BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
    );
  }
}

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
  @override
  Path getClip(Size size) => _getFolderTabPath(size);
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldDelegate) => false;
}

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
}
