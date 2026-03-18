import 'dart:ui';
import 'dart:math' show pi, sin, cos;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Unified liquid-glass button — looks like a glass cylinder
/// with airy, semi-transparent liquid inside.
class AppButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String text;

  const AppButton({
    super.key,
    required this.onPressed,
    required this.text,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> with TickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _timeNotifier = ValueNotifier(0.0);
  double _timeMultiplier = 1.0;
  Duration? _lastElapsed;
  late AnimationController _hoverController;
  bool _isHandlingTap = false;

  Offset _pointerPosition = Offset.zero;
  Offset _smoothedPointer = const Offset(200, 50);
  double _interactionStrength = 0.0;
  bool _isInteracting = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      if (_lastElapsed != null) {
        final delta = (elapsed - _lastElapsed!).inMicroseconds / 1000000.0;
        _timeNotifier.value += delta * _timeMultiplier;
        final targetStrength = _isInteracting ? 1.0 : 0.0;
        _interactionStrength += (targetStrength - _interactionStrength) * 8.0 * delta;
        if (_interactionStrength > 0.01) {
          _smoothedPointer += (_pointerPosition - _smoothedPointer) * 12.0 * delta;
        }
      }
      _lastElapsed = elapsed;
    });
    _ticker.start();
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    _timeNotifier.dispose();
    _hoverController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (!_isHandlingTap) {
      _hoverController.forward();
      _timeMultiplier = 4.0;
    }
  }

  void _onTapUp(TapUpDetails _) async {
    if (_isHandlingTap) return;
    _isHandlingTap = true;
    if (_hoverController.status != AnimationStatus.completed) {
      await _hoverController.forward().orCancel;
    }
    widget.onPressed();
    if (mounted) {
      _hoverController.reverse();
      _timeMultiplier = 1.0;
      _isInteracting = false;
    }
    _isHandlingTap = false;
  }

  void _onTapCancel() {
    if (!_isHandlingTap) {
      _hoverController.reverse();
      _timeMultiplier = 1.0;
      _isInteracting = false;
    }
  }

  void _updatePointer(Offset localPosition, double width) {
    final double tankLeft = (width / 2.0) - 200.0;
    const double tankTop = (60.0 / 2.0) - 50.0;
    _pointerPosition = Offset(
      localPosition.dx - tankLeft,
      localPosition.dy - tankTop,
    );
  }

  Widget _buildBlob({
    required double size,
    required Color color,
    required double freqX,
    required double freqY,
    required double phaseX,
    required double phaseY,
  }) {
    return ValueListenableBuilder<double>(
      valueListenable: _timeNotifier,
      builder: (context, time, _) {
        final speedTime = time * 0.4;
        final double baseX =
            (sin(speedTime * freqX + phaseX) + 1) / 2 * (400 - size * 0.5) - (size * 0.25);
        final double baseY =
            (cos(speedTime * freqY + phaseY) + 1) / 2 * (100 - size * 0.5) - (size * 0.25);
        final double attractionRadius = size * 0.4;
        final double targetX =
            _smoothedPointer.dx + (cos(phaseX) * attractionRadius) - (size / 2);
        final double targetY =
            _smoothedPointer.dy + (sin(phaseY) * attractionRadius) - (size / 2);
        final double pull = _interactionStrength * (0.6 + (freqX % 0.35));
        final double x = baseX + (targetX - baseX) * pull;
        final double y = baseY + (targetY - baseY) * pull;
        return Positioned(
          left: x,
          top: y,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final buttonWidth = constraints.maxWidth;
        return MouseRegion(
          onEnter: (_) => _isInteracting = true,
          onExit: (_) => _isInteracting = false,
          onHover: (e) => _updatePointer(e.localPosition, buttonWidth),
          child: Listener(
            onPointerDown: (e) {
              _isInteracting = true;
              _updatePointer(e.localPosition, buttonWidth);
            },
            onPointerMove: (e) => _updatePointer(e.localPosition, buttonWidth),
            onPointerUp: (_) => _isInteracting = false,
            onPointerCancel: (_) => _isInteracting = false,
            child: GestureDetector(
              onTapDown: _onTapDown,
              onTapUp: _onTapUp,
              onTapCancel: _onTapCancel,
              child: AnimatedBuilder(
                animation: _hoverController,
                builder: (context, _) {
                  final scaleVal = Tween<double>(begin: 1.0, end: 0.96).transform(
                    Curves.easeOutQuad.transform(_hoverController.value),
                  );
                  return Transform.scale(
                     scale: scaleVal,
                    child: Stack(
                      children: [
                        // ── Outer glass rim — visible against white background ─
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(33),
                        // Slightly tinted so it shows against the white screen
                        color: const Color(0xFFD8E8EF).withOpacity(0.45),
                        // gradient border applied via CustomPaint above
                        boxShadow: [
                          // Pastel blue drop shadow — separates from background
                          BoxShadow(
                            color: const Color(0xFF92E0FF).withOpacity(0.55),
                            blurRadius: 22,
                            spreadRadius: 0,
                            offset: const Offset(0, 6),
                          ),
                          // Soft inset top highlight
                          BoxShadow(
                            color: Colors.white.withOpacity(0.55),
                            blurRadius: 5,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      // ── Inner liquid surface ───────────────────────────
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // 1. Very light translucent base — lets
                              //    background show through for the glass feel
                              Container(color: Colors.white.withOpacity(0.40)),

                              // 2. Liquid blobs: mostly original soft pastels +
                              //    a large white blob for airiness, two vivid
                              //    accents for colour pop — all at low opacity
                              //    so the blend stays transparent.
                              ImageFiltered(
                                imageFilter: ImageFilter.blur(sigmaX: 40.0, sigmaY: 40.0),
                                child: SizedBox(
                                  width: 400,
                                  height: 100,
                                  child: Stack(
                                    children: [
                                      // White — large, drifts around, keeps
                                      // the liquid feeling bright & airy
                                      _buildBlob(size: 200, color: Colors.white.withOpacity(0.90),              freqX: 1.29, freqY: 0.73, phaseX: 3 * pi / 2, phaseY: pi),
                                      // Original pastel peach
                                      _buildBlob(size: 160, color: const Color(0xFFFFC6BA).withOpacity(0.75),   freqX: 1.13, freqY: 0.54, phaseX: 0,           phaseY: 0),
                                      // Original pale sky-blue
                                      _buildBlob(size: 170, color: const Color(0xFF92E0FF).withOpacity(0.70),   freqX: 0.67, freqY: 0.92, phaseX: pi,           phaseY: pi / 1.5),
                                      // Original soft mint
                                      _buildBlob(size: 155, color: const Color(0xFFC2E5DC).withOpacity(0.70),   freqX: 0.77, freqY: 1.51, phaseX: pi / 4,       phaseY: 3 * pi / 2),
                                      // Vivid accent — coral (low opacity)
                                      _buildBlob(size: 120, color: const Color(0xFFFF3C5F).withOpacity(0.45),   freqX: 0.81, freqY: 1.25, phaseX: pi / 2,       phaseY: pi / 3),
                                      // Vivid accent — cyan (low opacity)
                                      _buildBlob(size: 140, color: const Color(0xFF00D4FF).withOpacity(0.45),   freqX: 0.53, freqY: 0.61, phaseX: 5 * pi / 3,   phaseY: pi / 4),
                                    ],
                                  ),
                                ),
                              ),

                              // 3a. Cylinder TOP highlight — convex sheen
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(30),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    stops: const [0.0, 0.18, 0.42, 1.0],
                                    colors: [
                                      Colors.white.withOpacity(0.82),
                                      Colors.white.withOpacity(0.45),
                                      Colors.white.withOpacity(0.0),
                                      Colors.white.withOpacity(0.0),
                                    ],
                                  ),
                                ),
                              ),

                              // 3b. Crisp glass rim border
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.75),
                                    width: 1.5,
                                  ),
                                ),
                              ),

                              // 4. Label
                              Text(
                                widget.text,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F111A),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ), // End of inner liquid container
                    // Foreground gradient border
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _GradientBorderPainter(
                            radius: 33,
                            strokeWidth: 1.4,
                            gradient: const SweepGradient(
                              colors: [
                                Color(0xFFFF6B6B), // Home
                                Color(0xFFA3FF91), // Routine
                                Color(0xFF78FDFF), // Tracker
                                Color(0xFFC084FC), // Coach
                                Color(0xFFFF8CC2), // Goals
                                Color(0xFFFFB830), // Profile
                                Color(0xFFFF6B6B), // Wrap around to first color
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GradientBorderPainter extends CustomPainter {
  final double radius;
  final double strokeWidth;
  final Gradient gradient;

  _GradientBorderPainter({
    required this.radius,
    required this.strokeWidth,
    required this.gradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _GradientBorderPainter oldDelegate) {
    return oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.gradient != gradient;
  }
}
