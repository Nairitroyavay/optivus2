import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/providers/routine_provider.dart';

class FilterMeta {
  final String label, emoji;
  final Color color;
  const FilterMeta(this.label, this.emoji, this.color);
}

const filterMetaData = <RoutineFilter, FilterMeta>{
  RoutineFilter.all:           FilterMeta('All',            '🗓️', kInk),
  RoutineFilter.fixedSchedule: FilterMeta('Fixed Schedule', '📅', Color(0xFF8B5CF6)), // Purple
  RoutineFilter.skinCare:      FilterMeta('Skin Care',      '🌿', kMint),
  RoutineFilter.classes:       FilterMeta('Classes',        '🎓', kBlue),
  RoutineFilter.eating:        FilterMeta('Eating',         '🍽️', kRose),
};

class GlassFilterDropdown extends StatefulWidget {
  final RoutineFilter selected;
  final RoutineState routineState;
  final ValueChanged<RoutineFilter> onSelected;

  const GlassFilterDropdown({
    super.key,
    required this.selected,
    required this.routineState,
    required this.onSelected,
  });

  @override
  State<GlassFilterDropdown> createState() => _GlassFilterDropdownState();
}

class _GlassFilterDropdownState extends State<GlassFilterDropdown>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _overlay;
  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  final LayerLink _link = LayerLink();

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, -0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _closeDropdown();
    _anim.dispose();
    super.dispose();
  }

  void _openDropdown() {
    _overlay = OverlayEntry(builder: (_) {
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _closeDropdown,
        child: Stack(children: [
          CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomRight,
            followerAnchor: Alignment.topRight,
            offset: const Offset(0, 8), // 8px gap below filter pill
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: _buildSheet(),
              ),
            ),
          ),
        ]),
      );
    });

    Overlay.of(context).insert(_overlay!);
    _anim.forward();
  }

  void _closeDropdown() async {
    await _anim.reverse();
    _overlay?.remove();
    _overlay = null;
  }

  void _select(RoutineFilter f) {
    _closeDropdown();
    widget.onSelected(f);
  }

  // Width = AI(68) + gap(10) + Task(68) + gap(8) + Settings(36) = 190
  static const double _fixedWidth = 190.0;

  Widget _buildSheet() {
    const double outerR = 22.0;
    const double rim = 8.0;
    const double innerR = outerR - rim + 2;

    // Build rows first so the Stack is sized by the Column, not by Positioned children
    final rows = RoutineFilter.values.toList().asMap().entries.map((entry) {
      final idx = entry.key;
      final f = entry.value;
      final m = filterMetaData[f]!;
      final isSelected = widget.selected == f;
      final isLast = idx == RoutineFilter.values.length - 1;

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _select(f),
        child: Container(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.18)
              : Colors.transparent,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: Row(children: [
                  Text(m.emoji,
                      style: const TextStyle(
                          fontSize: 15, decoration: TextDecoration.none)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(m.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: kInk.withValues(
                              alpha: isSelected ? 1.0 : 0.80),
                          letterSpacing: -0.1,
                          height: 1.2,
                          decoration: TextDecoration.none,
                        )),
                  ),
                  if (isSelected)
                    Icon(Icons.check_rounded,
                        size: 14, color: kInk.withValues(alpha: 0.85)),
                ]),
              ),
              if (!isLast)
                Divider(
                  height: 0.5,
                  thickness: 0.5,
                  color: Colors.white.withValues(alpha: 0.30),
                  indent: 14,
                  endIndent: 14,
                ),
            ],
          ),
        ),
      );
    }).toList();

    return Material(
      color: Colors.transparent,
      child: Container(
        width: _fixedWidth,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(outerR),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(outerR),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            // Stack with passthrough: Column drives the height,
            // Positioned.fill overlays tint + painter on top
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                // ── Content column — THIS sizes the Stack ──────────────
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: rows,
                  ),
                ),

                // ── Transparent tint overlay ───────────────────────────
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(outerR),
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                ),

                // ── Glass rim highlights ───────────────────────────────
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: GlassHighlightPainter(
                          outerR: outerR, innerR: innerR, rim: rim),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: GestureDetector(
        onTap: () => _overlay == null ? _openDropdown() : _closeDropdown(),
        child: Container(
          color: Colors.transparent,
          child: const LiquidGlassPill(label: 'Filter', width: _fixedWidth),
        ),
      ),
    );
  }
}

class LiquidGlassPill extends StatelessWidget {
  final String label;
  final double width;
  const LiquidGlassPill({super.key, required this.label, required this.width});

  // Tuned to match reference: thicker rim, rounded corners
  static const double outerR = 20.0;
  static const double rim    = 7.0;
  static const double innerR = outerR - rim + 2; // 15

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 40,                            // ← shorter pill height
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(outerR),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(outerR),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Stack(
            children: [
              // ── Inner transparent face ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(rim),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15), // Clear frosted glass
                    borderRadius: BorderRadius.circular(innerR),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.6), // matching _buildSheet
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 14, // smaller text
                          fontWeight: FontWeight.w500, // lighter weight
                          color: Color(0xFF1C1C2E),
                          letterSpacing: -0.2,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      // Proper chevron icon
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: Color(0xFF1C1C2E),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Glass highlight overlay ────────────────────────────────
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: GlassHighlightPainter(
                        outerR: outerR, innerR: innerR, rim: rim),
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

class GlassHighlightPainter extends CustomPainter {
  final double outerR;
  final double innerR;
  final double rim;

  const GlassHighlightPainter({required this.outerR, required this.innerR, required this.rim});

  @override
  void paint(Canvas canvas, Size size) {
    final outerRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final outerRRect = RRect.fromRectAndRadius(outerRect, Radius.circular(outerR));
    
    final innerRect = Rect.fromLTWH(rim, rim, size.width - rim * 2, size.height - rim * 2);
    final innerRRect = RRect.fromRectAndRadius(innerRect, Radius.circular(innerR));

    // Outer Edge White Sweep (Top left)
    final outerSweepPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..shader = const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Colors.white, Colors.transparent, Colors.white24],
        stops: [0.0, 0.4, 1.0],
      ).createShader(outerRect);
    canvas.drawRRect(outerRRect, outerSweepPaint);

    // Inner Edge Sweep
    final innerSweepPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Colors.white.withValues(alpha: 0.9), Colors.white.withValues(alpha: 0.1)],
      ).createShader(innerRect);
    canvas.drawRRect(innerRRect, innerSweepPaint);

    // Thick Glare inside the rim (top-left)
    final glarePath = Path()
      ..addArc(Rect.fromLTWH(rim * 0.4, rim * 0.4, outerR * 2.5, outerR * 2.5), 3.14, 1.57);
    canvas.drawPath(glarePath, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = rim * 0.7
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));

    // The amazing rainbow prism base at the bottom right corner of the rim
    final donut = Path.combine(PathOperation.difference, Path()..addRRect(outerRRect), Path()..addRRect(innerRRect));
    canvas.save();
    canvas.clipPath(donut);

    // Vivid prism bursts mapped to the donut space
    canvas.drawCircle(Offset(size.width - rim * 1.5, size.height - rim * 1.5), 25, Paint()..color = Colors.white.withValues(alpha: 0.9)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    canvas.drawCircle(Offset(size.width - 5, size.height - 15), 20, Paint()..color = const Color(0xFF60A5FA).withValues(alpha: 0.8)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
    canvas.drawCircle(Offset(size.width - 25, size.height - 5), 20, Paint()..color = const Color(0xFFFBBF24).withValues(alpha: 0.8)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
    canvas.drawCircle(Offset(size.width - 15, size.height - 30), 20, Paint()..color = const Color(0xFFF472B6).withValues(alpha: 0.6)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));

    // Blackish inner shadow inside the bottom-right rim to create refraction depth
    canvas.drawRRect(
      outerRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = rim * 1.8
        ..shader = LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.35)],
          stops: const [0.6, 1.0]
        ).createShader(outerRect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GlassHighlightPainter oldDelegate) {
    return outerR != oldDelegate.outerR || rim != oldDelegate.rim;
  }
}
