import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

class LiquidGlassTabBar extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;
  final Color activeColor;

  const LiquidGlassTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.activeColor,
  });

  @override
  State<LiquidGlassTabBar> createState() => _LiquidGlassTabBarState();
}

class _LiquidGlassTabBarState extends State<LiquidGlassTabBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _snapController;
  late Animation<double> _snapAnimation;

  // The rendered pill position (0.0 – 5.0 fractional index)
  double _pillPosition = 0;
  double _snapFrom = 0;

  // Drag state
  bool _isDragging = false;
  int _lastHapticIndex = -1;

  static const int _tabCount = 6;

  static final List<IconData> _icons = [
    CupertinoIcons.house_fill,
    CupertinoIcons.calendar,
    CupertinoIcons.chart_bar_fill,
    CupertinoIcons.book_fill,
    CupertinoIcons.flag_fill,
    CupertinoIcons.person_crop_circle_fill,
  ];

  @override
  void initState() {
    super.initState();
    _pillPosition = widget.currentIndex.toDouble();
    _lastHapticIndex = widget.currentIndex;

    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _snapAnimation = CurvedAnimation(
      parent: _snapController,
      curve: Curves.easeOutBack,
    );

    _snapController.addListener(() {
      setState(() {
        _pillPosition =
            _snapFrom + (_snapAnimation.value * (widget.currentIndex - _snapFrom));
      });
    });
  }

  @override
  void didUpdateWidget(covariant LiquidGlassTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Animate pill from wherever it is to the new target (only on external change, not drag)
    if (!_isDragging && oldWidget.currentIndex != widget.currentIndex) {
      _snapFrom = _pillPosition;
      _snapController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details, double tabSlotWidth) {
    _isDragging = true;
    _snapController.stop();
    _lastHapticIndex = _pillPosition.round().clamp(0, _tabCount - 1);
  }

  void _onPanUpdate(DragUpdateDetails details, double tabSlotWidth) {
    final double rawIndex =
        (details.localPosition.dx / tabSlotWidth).clamp(0.0, _tabCount - 1.0);

    setState(() {
      _pillPosition = rawIndex;
    });

    // Haptic tick each time we cross a tab boundary
    final int hoverIndex = rawIndex.round().clamp(0, _tabCount - 1);
    if (hoverIndex != _lastHapticIndex) {
      HapticFeedback.selectionClick();
      _lastHapticIndex = hoverIndex;
    }
  }

  void _onPanEnd(DragEndDetails details, double tabSlotWidth) {
    _isDragging = false;

    final int nearest = _pillPosition.round().clamp(0, _tabCount - 1);

    // Snap pill visually
    _snapFrom = _pillPosition;
    // Drive snap animation manually
    _snapController.duration = const Duration(milliseconds: 300);
    _snapController.forward(from: 0);

    // Notify parent last (triggers didUpdateWidget → we guard with _isDragging)
    if (nearest != widget.currentIndex) {
      widget.onTap(nearest);
    } else {
      // Still animate snap back to exact position
      setState(() {});
    }
  }

  void _onTap(int index) {
    if (index != widget.currentIndex) {
      HapticFeedback.selectionClick();
    }
    widget.onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(36),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.55),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double totalWidth = constraints.maxWidth;
                final double tabSlotWidth = totalWidth / _tabCount;

                return GestureDetector(
                  onPanStart: (d) => _onPanStart(d, tabSlotWidth),
                  onPanUpdate: (d) => _onPanUpdate(d, tabSlotWidth),
                  onPanEnd: (d) => _onPanEnd(d, tabSlotWidth),
                  child: Stack(
                    children: [
                      // Liquid pill indicator
                      _buildPill(tabSlotWidth),

                      // Icon row
                      Row(
                        children: List.generate(_tabCount, (index) {
                          final bool isSelected =
                              index == _pillPosition.round().clamp(0, _tabCount - 1);
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _onTap(index),
                            child: SizedBox(
                              width: tabSlotWidth,
                              height: 72,
                              child: Center(
                                child: AnimatedScale(
                                  duration: const Duration(milliseconds: 200),
                                  scale: isSelected ? 1.18 : 1.0,
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 150),
                                    opacity: isSelected ? 1.0 : 0.38,
                                    child: index == 3
                                        ? _AiBotIcon(
                                            isSelected: isSelected,
                                            color: isSelected
                                                ? widget.activeColor
                                                : Colors.black,
                                            size: 24,
                                          )
                                        : Icon(
                                            _icons[index],
                                            size: 24,
                                            color: isSelected
                                                ? widget.activeColor
                                                : Colors.black,
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPill(double tabSlotWidth) {
    // During drag, stretch pill as it moves fast
    const double pillBase = 46.0;
    const double maxStretch = 18.0;

    // Fractional part drives the stretch (peaks at .5 between tabs)
    final double frac = _pillPosition - _pillPosition.floor();
    final double stretch = (frac < 0.5
            ? frac * 2
            : (1 - frac) * 2)
        .clamp(0.0, 1.0) *
        maxStretch;

    final double pillWidth = pillBase + (_isDragging ? stretch : 0);
    final double centerX = _pillPosition * tabSlotWidth + tabSlotWidth / 2;
    final double left = centerX - pillWidth / 2;

    return Positioned(
      left: left,
      top: (72 - 44) / 2,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: pillWidth,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: Colors.white.withValues(alpha: 0.72),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.9),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.activeColor.withValues(alpha: 0.20),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Custom AI Bot icon for the Coach tab
// ─────────────────────────────────────────────────────────────

class _AiBotIcon extends StatelessWidget {
  final bool isSelected;
  final Color color;
  final double size;

  const _AiBotIcon({
    required this.isSelected,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, anim) =>
          ScaleTransition(scale: anim, child: child),
      child: CustomPaint(
        key: ValueKey(isSelected),
        size: Size(size, size),
        painter: _AiBotPainter(color: color, happy: isSelected),
      ),
    );
  }
}

class _AiBotPainter extends CustomPainter {
  final Color color;
  final bool happy;

  _AiBotPainter({required this.color, required this.happy});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.09
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    // ── Head (rounded rectangle) ──
    final headRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.12, h * 0.16, w * 0.76, h * 0.63),
      Radius.circular(w * 0.18),
    );
    canvas.drawRRect(headRect, paint);

    // ── Antenna ──
    final antennaPaint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(w * 0.5, h * 0.16),
      Offset(w * 0.5, h * 0.04),
      antennaPaint,
    );
    canvas.drawCircle(Offset(w * 0.5, h * 0.02), w * 0.06, paint);

    // ── Ears (small side nubs) ──
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.04, h * 0.32, w * 0.1, h * 0.22),
        Radius.circular(w * 0.05),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.86, h * 0.32, w * 0.1, h * 0.22),
        Radius.circular(w * 0.05),
      ),
      paint,
    );

    // ── Eyes (goggle style: white ring + inner square pupil) ──
    final eyeWhite = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..style = PaintingStyle.fill;
    final pupilPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Left goggle
    canvas.drawCircle(Offset(w * 0.34, h * 0.38), w * 0.13, eyeWhite);
    // Inner square pupil (rounded)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(w * 0.34, h * 0.39), width: w * 0.1, height: w * 0.1),
        Radius.circular(w * 0.025),
      ),
      pupilPaint,
    );

    // Right goggle
    canvas.drawCircle(Offset(w * 0.66, h * 0.38), w * 0.13, eyeWhite);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(w * 0.66, h * 0.39), width: w * 0.1, height: w * 0.1),
        Radius.circular(w * 0.025),
      ),
      pupilPaint,
    );

    // ── Mouth ──
    if (happy) {
      // Filled D-shaped smile matching reference: wide crescent, white fill
      final smilePath = Path()
        ..moveTo(w * 0.25, h * 0.60)
        // Bottom curve (the visible smile)
        ..quadraticBezierTo(w * 0.5, h * 0.82, w * 0.75, h * 0.60)
        // Top lip line (flatter curve closing the crescent)
        ..quadraticBezierTo(w * 0.5, h * 0.66, w * 0.25, h * 0.60)
        ..close();

      // White fill (teeth/interior)
      canvas.drawPath(
        smilePath,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.92)
          ..style = PaintingStyle.fill,
      );
      // Outline in bot color
      canvas.drawPath(smilePath, strokePaint..strokeWidth = w * 0.06);
    } else {
      // Stroke frown
      final frownPath = Path()
        ..moveTo(w * 0.28, h * 0.72)
        ..quadraticBezierTo(w * 0.5, h * 0.52, w * 0.72, h * 0.72);
      canvas.drawPath(frownPath, strokePaint..strokeWidth = w * 0.09);
    }
  }

  @override
  bool shouldRepaint(_AiBotPainter old) =>
      old.color != color || old.happy != happy;
}
