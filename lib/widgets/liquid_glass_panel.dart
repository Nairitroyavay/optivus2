import 'dart:ui';
import 'package:flutter/material.dart';

class LiquidGlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool hasScrews; // Enables corner pins like a physical acrylic plaque

  const LiquidGlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(32.0),
    this.hasScrews = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.7),
          width: 1.5,
        ),
        boxShadow: [
          // Soft ambient drop shadow underneath
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
          // Bright inner highlight for 3D thickness
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.4),
            blurRadius: 20,
            spreadRadius: -2,
            offset: const Offset(-2, -2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(38.5),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Stack(
            children: [
              // Liquid resin rim light gradient
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(38.5),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      stops: const [0.0, 0.2, 0.4, 1.0],
                      colors: [
                        Colors.white.withValues(alpha: 0.8), // Bright gleam
                        Colors.white.withValues(alpha: 0.2), 
                        Colors.white.withValues(alpha: 0.0), // Transparent center
                        Colors.black.withValues(alpha: 0.05), // Darker edge
                      ],
                    ),
                  ),
                ),
              ),
              if (hasScrews) ..._buildScrews(), // Inject corner pins if requested
              Padding(
                padding: padding,
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Builder method for the four acrylic glass screws/pins
  List<Widget> _buildScrews() {
    const double inset = 16.0;
    return [
      _buildScrew(top: inset, left: inset),
      _buildScrew(top: inset, right: inset),
      _buildScrew(bottom: inset, left: inset),
      _buildScrew(bottom: inset, right: inset),
    ];
  }

  Widget _buildScrew({double? top, double? left, double? right, double? bottom}) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white, // Solid bright white core
          boxShadow: [
            // Outset soft glow
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.8),
              blurRadius: 8,
              spreadRadius: 1,
            ),
            // Sharp inner core shadow
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(2, 2),
            ),
            // Outer drop shadow for elevation
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(2, 4),
            ),
          ],
        ),
      ),
    );
  }
}

