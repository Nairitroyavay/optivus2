import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PUBLIC WIDGET
// ─────────────────────────────────────────────────────────────────────────────

/// A two-phase indeterminate loader:
///   Phase 1 – wavy dark-grey arc chases its tail on a light-grey circular track.
///   Phase 2 – arc fades out; a dark-grey ✓ scales in.
///
/// [size] controls the diameter of the circular track.
/// The widget is self-contained – it drives its own timers.
class WavyLoadingIndicator extends StatefulWidget {
  final double size;

  const WavyLoadingIndicator({super.key, this.size = 40});

  @override
  State<WavyLoadingIndicator> createState() => _WavyLoadingIndicatorState();
}

class _WavyLoadingIndicatorState extends State<WavyLoadingIndicator>
    with TickerProviderStateMixin {
  // ── Phase 1: spinning wavy arc ──────────────────────────────────────────
  late final AnimationController _spinCtrl;
  late final Animation<double> _startAngle; // 0 → 2π, loops
  late final Animation<double> _sweepAngle; // breathes 0.4π ↔ 1.6π

  // ── Phase 2: success ────────────────────────────────────────────────────
  late final AnimationController _successCtrl;
  late final Animation<double> _arcOpacity;  // 1 → 0
  late final Animation<double> _checkScale;  // 0 → 1, easeOutBack

  bool _success = false;

  @override
  void initState() {
    super.initState();

    // ── Spin controller (loops forever in Phase 1) ──────────────────────
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _startAngle = Tween<double>(begin: -math.pi / 2, end: 3 * math.pi / 2)
        .animate(_spinCtrl); // full 360° rotation

    _sweepAngle = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.4 * math.pi, end: 1.6 * math.pi)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.6 * math.pi, end: 0.4 * math.pi)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 50,
      ),
    ]).animate(_spinCtrl);

    // ── Success controller ───────────────────────────────────────────────
    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _arcOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _successCtrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _checkScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _successCtrl,
        curve: const Interval(0.35, 1.0, curve: Curves.easeOutBack),
      ),
    );

    // Switch to Phase 2 after the auth call would finish (driven externally
    // by the parent replacing this widget, but we keep a local demo timer
    // so it works standalone too).
    Future.delayed(const Duration(seconds: 13), () {
      if (mounted) _triggerSuccess();
    });
  }

  void _triggerSuccess() {
    if (_success) return;
    setState(() => _success = true);
    _spinCtrl.stop();
    _successCtrl.forward();
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    _successCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final iconSize = s * 0.55;

    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── Static light-grey track ──────────────────────────────────
          CustomPaint(
            size: Size(s, s),
            painter: _TrackPainter(size: s),
          ),

          // ── Animated wavy arc ────────────────────────────────────────
          AnimatedBuilder(
            animation: Listenable.merge([_spinCtrl, _successCtrl]),
            builder: (_, __) {
              return Opacity(
                opacity: _success ? _arcOpacity.value : 1.0,
                child: CustomPaint(
                  size: Size(s, s),
                  painter: _WavyArcPainter(
                    startAngle: _startAngle.value,
                    sweepAngle: _sweepAngle.value,
                    size: s,
                  ),
                ),
              );
            },
          ),

          // ── Success checkmark ────────────────────────────────────────
          AnimatedBuilder(
            animation: _successCtrl,
            builder: (_, __) {
              if (_successCtrl.value == 0) return const SizedBox.shrink();
              return Transform.scale(
                scale: _checkScale.value,
                child: Icon(
                  Icons.check_rounded,
                  size: iconSize,
                  color: Colors.grey[800],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TRACK PAINTER  – static light-grey circle
// ─────────────────────────────────────────────────────────────────────────────
class _TrackPainter extends CustomPainter {
  final double size;
  _TrackPainter({required this.size});

  @override
  void paint(Canvas canvas, Size _) {
    final stroke = _strokeWidth(size);
    final radius = size / 2 - stroke / 2;
    final center = Offset(size / 2, size / 2);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.grey[300]!
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt,
    );
  }

  @override
  bool shouldRepaint(_TrackPainter old) => old.size != size;
}

// ─────────────────────────────────────────────────────────────────────────────
// WAVY ARC PAINTER  – smooth sine-wave segment that spins & breathes
// ─────────────────────────────────────────────────────────────────────────────
class _WavyArcPainter extends CustomPainter {
  final double startAngle;
  final double sweepAngle;
  final double size;

  _WavyArcPainter({
    required this.startAngle,
    required this.sweepAngle,
    required this.size,
  });

  @override
  void paint(Canvas canvas, Size _) {
    final stroke = _strokeWidth(size);
    final baseRadius = size / 2 - stroke / 2;

    // Wave parameters – scale with size so they look identical at any size.
    final amplitude = baseRadius * 0.14; // ≈14 % of radius
    const frequency = 9.0;              // nine sine cycles around the full circle

    // Enough steps so each segment is sub-pixel → perfectly smooth curve.
    final steps = (sweepAngle / (2 * math.pi) * 600).round().clamp(60, 600);
    final stepAngle = sweepAngle / steps;
    final center = Offset(size / 2, size / 2);

    final path = Path();
    for (int i = 0; i <= steps; i++) {
      final angle = startAngle + i * stepAngle;
      final r = baseRadius + amplitude * math.sin(frequency * angle);
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.grey[800]!
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_WavyArcPainter old) =>
      old.startAngle != startAngle ||
      old.sweepAngle != sweepAngle ||
      old.size != size;
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

/// Stroke width proportional to the indicator size.
double _strokeWidth(double size) => (size * 0.1).clamp(2.0, 7.0);
