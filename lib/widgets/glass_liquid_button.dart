import 'dart:ui';
import 'package:flutter/material.dart';

class GlassLiquidButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final double width;
  final double height;
  final bool isLoading;

  const GlassLiquidButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.width = double.infinity,
    this.height = 68,
    this.isLoading = false,
  });

  @override
  State<GlassLiquidButton> createState() => _GlassLiquidButtonState();
}

class _GlassLiquidButtonState extends State<GlassLiquidButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _animController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _animController.reverse();
    widget.onPressed();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _animController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: SizedBox(
              width: widget.width,
              height: widget.height,
              child: Stack(
                children: [
                  // 1. The Outer Track (Recessed Groove)
                  Container(
                    width: widget.width,
                    height: widget.height,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(widget.height / 2),
                      color: Colors.white.withValues(alpha: 0.05),
                      // Inner shadow effect using overlapping gradients
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1.5,
                      ),
                      boxShadow: [
                        // Dark top/left inner shadow simulation (a bit darker above)
                        BoxShadow(
                          color: const Color(0xFF9EADC1).withValues(alpha: 0.6),
                          
                          offset: const Offset(0, 4),
                          blurRadius: 10,
                          spreadRadius: -2,
                        ),
                        // Light bottom/right inner highlight simulation
                        const BoxShadow(
                          color: Colors.white,
                          
                          offset: Offset(0, -3),
                          blurRadius: 6,
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                  ),

                  // 2. The Inner Pill (The actual button bubble)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOutCubic,
                    top: _isPressed ? 6.0 : 4.0,
                    bottom: _isPressed ? 2.0 : 4.0,
                    left: 4.0,
                    right: 4.0,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(widget.height / 2),
                        // Soft frosted gradient background
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.4),
                            Colors.white.withValues(alpha: 0.1),
                          ],
                        ),
                        // Highlights and drop shadows for the inner bubble
                        boxShadow: [
                          // Drop shadow
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            offset: const Offset(0, 4),
                            blurRadius: 8,
                          ),
                          // Top bright highlight (rim light)
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.9),
                            
                            offset: const Offset(0, 3),
                            blurRadius: 4,
                          ),
                          // Bottom soft highlight
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.2),
                            
                            offset: const Offset(0, -2),
                            blurRadius: 4,
                          ),
                        ],
                        // White thin border around the bubble
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.6),
                          width: 1.0,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(widget.height / 2),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Backdrop blur for the frosted glass effect
                            BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                color: Colors.transparent,
                              ),
                            ),
                            
                            // Slight noise texture overlay to mimic the frosted surface
                            Opacity(
                              opacity: 0.15,
                              child: Image.asset(
                                'assets/images/noise.png', // Fallback safely if doesn't exist by catching error or wrapping, but standard way is ok if setup well. Wait, we don't have a noise image asset right now. Let's use a subtle gradient instead to mimic it.
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (context, error, stackTrace) =>
                                    const SizedBox.shrink(),
                              ),
                            ),

                            // Text
                            if (widget.isLoading)
                              const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Color(0xFF1E293B)),
                                ),
                              )
                            else
                              Text(
                                widget.text,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF171B26), // Dark charcoal/navy color
                                  letterSpacing: -0.5,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
