import 'dart:ui';
import 'package:flutter/material.dart';

class LiquidTextField extends StatelessWidget {
  final String hintText;
  final bool obscureText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextEditingController? controller;

  const LiquidTextField({
    super.key,
    required this.hintText,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18), // Base opacity to catch light
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.85), // Crisper outer border
          width: 1.5,
        ),
        boxShadow: [
          // Soft ambient drop shadow underneath
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
          // Bright white inner shadow on top/left to define volume
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.5),
            blurRadius: 16,
            spreadRadius: -2,
            offset: const Offset(-2, -2),
          ),
          // Darker inner shadow on bottom/right to simulate depth
          BoxShadow(
             color: Colors.black.withValues(alpha: 0.05),
             blurRadius: 10,
             spreadRadius: -4,
             offset: const Offset(4, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28.5), // Match border inset perfectly
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18), // Increased for "thick" glass look
          child: Stack(
            children: [
              // VERY crisp, distinct rim light at top/left mimicking molded resin
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28.5),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      stops: const [0.0, 0.15, 0.4, 1.0],
                      colors: [
                        Colors.white.withValues(alpha: 0.95), // Brightest corner
                        Colors.white.withValues(alpha: 0.4),  // Rapid falloff
                        Colors.white.withValues(alpha: 0.0),  // Transparent body
                        Colors.black.withValues(alpha: 0.03), // Slight bottom-right occlusion
                      ],
                    ),
                  ),
                ),
              ),
              TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: const TextStyle(
              color: Color(0xFF1E202A), // Dark slate/almost black
              fontWeight: FontWeight.w600, // Thicker font
              fontSize: 16,
              letterSpacing: 0.3,
            ),
            cursorColor: const Color(0xFF1E202A),
            decoration: InputDecoration(
              prefixIcon: prefixIcon != null
                  ? Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.white.withValues(alpha: 0.25), // Frosty inset base
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.5), width: 1.0),
                          boxShadow: [
                            // Inner shadow effect (indentation)
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              offset: const Offset(2, 2),
                              blurRadius: 6,
                            ),
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.6),
                              offset: const Offset(-2, -2),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Icon(
                          prefixIcon,
                          color: const Color(0xFF1E202A),
                          size: 22,
                        ),
                      ),
                    )
                  : null,
              suffixIcon: suffixIcon != null
                  ? Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: suffixIcon,
                    )
                  : null,
              hintText: hintText,
              hintStyle: TextStyle(
                color: const Color(0xFF1E202A).withValues(alpha: 0.45),
                fontWeight: FontWeight.w500,
                fontSize: 16,
                letterSpacing: 0.3,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: prefixIcon == null ? 20 : 0, // Indent a bit more if no prefix
                vertical: 18,
              ),
            ),
          ),
            ],
          ),
        ),
      ),
    );
  }
}
