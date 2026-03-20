// ─────────────────────────────────────────────────────────────────────────────
// lib/core/liquid_kit.dart
//
// Optivus Liquid Glass Design System
// Single import gives every screen access to all primitives.
//
// ARCHITECTURE RULES (enforced here):
//   • BackdropFilter always wrapped in ClipRRect — never naked
//   • sigmaX/Y capped at 12 to stay performant on Impeller/iOS
//   • No BackdropFilter inside ListView items — use simulated glass instead
//   • Colours via kXxx constants only — never raw hex outside this file
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// 1.  COLOUR PALETTE
// ═══════════════════════════════════════════════════════════════════════════════

const kInk     = Color(0xFF0F111A);   // primary text
const kSub     = Color(0xFF6B7280);   // secondary text
const kCream   = Color(0xFFF6E6B4);   // warm background top
const kBg      = Color(0xFFFCF8EE);   // warm background bottom
const kWhite   = Colors.white;
const kAmber   = Color(0xFFFFB830);   // primary CTA
const kPurple  = Color(0xFF9B8FFF);   // AI / premium accent
const kMint    = Color(0xFF60D4A0);   // skin care / success
const kBlue    = Color(0xFF60B8FF);   // class / info
const kCoral   = Color(0xFFFF6B6B);   // home accent
const kRose    = Color(0xFFFF9560);   // eating / warning

// Per-tab identity colours (index matches tab order)
const kTabAccents = <Color>[
  kCoral,           // 0 Home
  kMint,            // 1 Routine
  Color(0xFF78FDFF),// 2 Tracker
  kPurple,          // 3 Coach
  Color(0xFFFF8CC2),// 4 Goals
  kAmber,           // 5 Profile
];

// Glass surface colours
const _kGlassFill   = Color(0xB3FFFFFF); // 70 % white
const _kGlassBorder = Color(0xCCFFFFFF); // 80 % white
const _kGlassShad   = Color(0x14000000); // 8 % black
const _kInnerHi     = Color(0x66FFFFFF); // top specular highlight

// ═══════════════════════════════════════════════════════════════════════════════
// 2.  GLASS SCAFFOLD BACKGROUND
// ═══════════════════════════════════════════════════════════════════════════════

/// Warm-cream gradient used as the app background.
/// Wrap your Scaffold body with this.
class LiquidBg extends StatelessWidget {
  final Widget child;
  const LiquidBg({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [kCream, kBg],
          stops: [0.0, 0.55],
        ),
      ),
      child: child,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 3.  LIQUID CARD
//     The core frosted-glass container.
//     Uses BackdropFilter ONLY when [frosted] is true AND the card is
//     NOT inside a scroll view.  For list items, use [LiquidCard.solid].
// ═══════════════════════════════════════════════════════════════════════════════

class LiquidCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final bool frosted;       // true = blur backdrop (use sparingly)
  final Color? tint;        // custom glass tint
  final double elevation;   // shadow intensity multiplier

  const LiquidCard({
    super.key,
    required this.child,
    this.padding   = const EdgeInsets.all(20),
    this.radius    = 24,
    this.frosted   = false, // default: simulated glass (no blur, performant)
    this.tint,
    this.elevation = 1,
  });

  /// Non-blur variant — safe inside ListViews.
  const LiquidCard.solid({
    super.key,
    required this.child,
    this.padding   = const EdgeInsets.all(16),
    this.radius    = 20,
    this.tint,
    this.elevation = 1,
  }) : frosted = false;

  @override
  Widget build(BuildContext context) {
    final fill = tint ?? _kGlassFill;
    final decoration = BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _kGlassBorder, width: 1.5),
      boxShadow: [
        BoxShadow(
          color: _kGlassShad.withValues(alpha: 0.08 * elevation),
          blurRadius: 20 * elevation,
          offset: Offset(0, 6 * elevation),
        ),
        const BoxShadow(
          color: _kInnerHi,
          blurRadius: 0,
          offset: Offset(-1, -1),
        ),
      ],
    );

    if (!frosted) {
      return Container(
        padding: padding,
        decoration: decoration,
        child: child,
      );
    }

    // Frosted — only use for static hero cards (not list items)
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: decoration,
          child: child,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 4.  LIQUID BUTTON
//     Pill-shaped, tinted, with inner highlight and press animation.
// ═══════════════════════════════════════════════════════════════════════════════

class LiquidButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final double height;
  final Widget? leading;
  final bool outline;      // ghost variant

  const LiquidButton({
    super.key,
    required this.label,
    this.onTap,
    this.color  = kAmber,
    this.height = 56,
    this.leading,
    this.outline = false,
  });

  const LiquidButton.outline({
    super.key,
    required this.label,
    this.onTap,
    this.color  = kInk,
    this.height = 56,
    this.leading,
  }) : outline = true;

  @override
  State<LiquidButton> createState() => _LiquidButtonState();
}

class _LiquidButtonState extends State<LiquidButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.96)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isGhost = widget.outline;
    return GestureDetector(
      onTapDown:   (_) { _ctrl.forward();  HapticFeedback.lightImpact(); },
      onTapUp:     (_) { _ctrl.reverse();  widget.onTap?.call(); },
      onTapCancel: ()  { _ctrl.reverse(); },
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: isGhost ? Colors.transparent : widget.color,
            borderRadius: BorderRadius.circular(widget.height / 2),
            border: isGhost
                ? Border.all(color: widget.color.withValues(alpha: 0.6), width: 1.5)
                : null,
            boxShadow: isGhost
                ? null
                : [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.38),
                      blurRadius: 18,
                      offset: const Offset(0, 7),
                    ),
                  ],
            // Inner top highlight
            gradient: isGhost
                ? null
                : LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      widget.color.withValues(alpha: 0.0),
                      Colors.black.withValues(alpha: 0.08),
                    ],
                  ),
          ),
          child: Stack(
            children: [
              // Specular highlight stripe at top
              if (!isGhost)
                Positioned(
                  top: 4, left: 20, right: 20,
                  height: 6,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.leading != null) ...[
                      widget.leading!,
                      const SizedBox(width: 8),
                    ],
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isGhost ? widget.color : kWhite,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 5.  LIQUID TEXT FIELD
// ═══════════════════════════════════════════════════════════════════════════════

class LiquidTextField extends StatefulWidget {
  final String hint;
  final IconData? prefixIcon;
  final Widget? suffixWidget;
  final bool obscure;
  final TextInputType keyboardType;
  final TextEditingController? controller;
  final void Function(String)? onChanged;

  const LiquidTextField({
    super.key,
    required this.hint,
    this.prefixIcon,
    this.suffixWidget,
    this.obscure      = false,
    this.keyboardType = TextInputType.text,
    this.controller,
    this.onChanged,
  });

  @override
  State<LiquidTextField> createState() => _LiquidTextFieldState();
}

class _LiquidTextFieldState extends State<LiquidTextField> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() { _focus.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: kWhite.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _focused
              ? kAmber.withValues(alpha: 0.7)
              : kWhite.withValues(alpha: 0.9),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _focused
                ? kAmber.withValues(alpha: 0.15)
                : _kGlassShad,
            blurRadius: _focused ? 16 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        focusNode:    _focus,
        controller:   widget.controller,
        obscureText:  widget.obscure,
        keyboardType: widget.keyboardType,
        onChanged:    widget.onChanged,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: kInk,
        ),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: TextStyle(
            color: kSub.withValues(alpha: 0.55),
            fontWeight: FontWeight.w400,
            fontSize: 15,
          ),
          prefixIcon: widget.prefixIcon != null
              ? Icon(widget.prefixIcon,
                    size: 20, color: kSub.withValues(alpha: 0.7))
              : null,
          suffix: widget.suffixWidget,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 15),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 6.  LIQUID TOGGLE  (iOS-style switch with liquid orb)
// ═══════════════════════════════════════════════════════════════════════════════

class LiquidToggle extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;

  const LiquidToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor = kAmber,
  });

  @override
  State<LiquidToggle> createState() => _LiquidToggleState();
}

class _LiquidToggleState extends State<LiquidToggle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _pos;   // 0 = off, 1 = on
  late final Animation<double>   _squish;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: widget.value ? 1.0 : 0.0,
    );
    _pos   = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic);
    _squish = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.18), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.18, end: 1.0), weight: 70),
    ]).animate(_ctrl);
  }

  @override
  void didUpdateWidget(LiquidToggle old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      widget.value ? _ctrl.forward() : _ctrl.reverse();
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    const trackW = 52.0;
    const trackH = 30.0;
    const orbD   = 24.0;
    const travel = trackW - orbD - 6; // horizontal travel

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onChanged(!widget.value);
      },
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final t = _pos.value;
          final trackColor = Color.lerp(
            const Color(0xFFDDDDDD),
            widget.activeColor,
            t,
          )!;

          return Container(
            width: trackW, height: trackH,
            decoration: BoxDecoration(
              color: trackColor,
              borderRadius: BorderRadius.circular(trackH / 2),
              boxShadow: [
                BoxShadow(
                  color: widget.activeColor.withValues(alpha: 0.25 * t),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Orb
                Transform.translate(
                  offset: Offset(3 + travel * t, 0),
                  child: Transform.scale(
                    scaleX: _squish.value,
                    child: Container(
                      width: orbD, height: orbD,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: kWhite,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 10, height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color.lerp(
                              const Color(0xFFDDDDDD),
                              widget.activeColor,
                              t,
                            )!.withValues(alpha: 0.5),
                          ),
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
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 7.  LIQUID CHIP  (filter pill)
// ═══════════════════════════════════════════════════════════════════════════════

class LiquidChip extends StatefulWidget {
  final String label;
  final String? emoji;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;
  final bool dot; // show unseen dot

  const LiquidChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.emoji,
    this.accentColor = kInk,
    this.dot = false,
  });

  @override
  State<LiquidChip> createState() => _LiquidChipState();
}

class _LiquidChipState extends State<LiquidChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: widget.selected ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(LiquidChip old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) {
      widget.selected ? _ctrl.forward() : _ctrl.reverse();
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); widget.onTap(); },
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final t = _ctrl.value;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Color.lerp(
                kWhite.withValues(alpha: 0.72),
                widget.accentColor,
                t,
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Color.lerp(
                  kWhite.withValues(alpha: 0.9),
                  widget.accentColor.withValues(alpha: 0.6),
                  t,
                )!,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.accentColor.withValues(alpha: 0.18 * t),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
                const BoxShadow(
                  color: _kInnerHi,
                  blurRadius: 0,
                  offset: Offset(-1, -1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.emoji != null) ...[
                  Text(widget.emoji!,
                      style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 5),
                ],
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color.lerp(kInk, kWhite, t),
                  ),
                ),
                if (widget.dot) ...[
                  const SizedBox(width: 5),
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color.lerp(
                        widget.accentColor,
                        kWhite.withValues(alpha: 0.7),
                        t,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 8.  LIQUID CHECKBOX
// ═══════════════════════════════════════════════════════════════════════════════

class LiquidCheckbox extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;

  const LiquidCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor = kAmber,
  });

  @override
  State<LiquidCheckbox> createState() => _LiquidCheckboxState();
}

class _LiquidCheckboxState extends State<LiquidCheckbox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: widget.value ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(LiquidCheckbox old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      widget.value ? _ctrl.forward() : _ctrl.reverse();
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onChanged(!widget.value);
      },
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final t = _ctrl.value;
          return Container(
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: Color.lerp(
                kWhite.withValues(alpha: 0.7),
                widget.activeColor,
                t,
              ),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Color.lerp(
                  kSub.withValues(alpha: 0.35),
                  widget.activeColor,
                  t,
                )!,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.activeColor.withValues(alpha: 0.25 * t),
                  blurRadius: 6,
                ),
              ],
            ),
            child: t > 0.5
                ? Center(
                    child: Icon(Icons.check_rounded,
                        size: 13,
                        color: kWhite.withValues(alpha: t)),
                  )
                : null,
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 9.  LIQUID ICON BUTTON  (circle, used for nav back / settings)
// ═══════════════════════════════════════════════════════════════════════════════

class LiquidIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color? color;

  const LiquidIconBtn({
    super.key,
    required this.icon,
    this.onTap,
    this.size  = 40,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color: _kGlassFill,
          shape: BoxShape.circle,
          border: Border.all(color: _kGlassBorder, width: 1.5),
          boxShadow: const [
            BoxShadow(color: _kGlassShad, blurRadius: 10,
                offset: Offset(0, 3)),
          ],
        ),
        child: Icon(icon, size: size * 0.45,
            color: color ?? kInk),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 10.  LIQUID FAB  (floating action button with press animation)
// ═══════════════════════════════════════════════════════════════════════════════

class LiquidFab extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? label;
  final bool active; // for toggle state

  const LiquidFab({
    super.key,
    required this.icon,
    required this.onTap,
    this.color  = kAmber,
    this.label,
    this.active = false,
  });

  @override
  State<LiquidFab> createState() => _LiquidFabState();
}

class _LiquidFabState extends State<LiquidFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 90));
    _scale = Tween<double>(begin: 1.0, end: 0.92)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: _kGlassFill,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kGlassBorder, width: 1.5),
              boxShadow: const [
                BoxShadow(color: _kGlassShad, blurRadius: 8,
                    offset: Offset(0, 2)),
              ],
            ),
            child: Text(widget.label!,
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: widget.color,
                )),
          ),
        ],
        GestureDetector(
          onTapDown:   (_) { _ctrl.forward(); HapticFeedback.lightImpact(); },
          onTapUp:     (_) { _ctrl.reverse(); widget.onTap(); },
          onTapCancel: ()  { _ctrl.reverse(); },
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: widget.active
                    ? widget.color
                    : _kGlassFill,
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.active
                      ? widget.color.withValues(alpha: 0.6)
                      : _kGlassBorder,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 
                        widget.active ? 0.40 : 0.18),
                    blurRadius: widget.active ? 18 : 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(widget.icon,
                  color: widget.active ? kWhite : widget.color,
                  size: 24),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 11.  LIQUID TAB BAR  (bottom navigation)
// ═══════════════════════════════════════════════════════════════════════════════

const _kTabIcons = [
  Icons.home_rounded,
  Icons.calendar_month_rounded,
  Icons.bar_chart_rounded,
  Icons.smart_toy_outlined,
  Icons.flag_rounded,
  Icons.person_rounded,
];
const _kTabLabels = ['Home','Routine','Tracker','Coach','Goals','Profile'];

class LiquidTabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const LiquidTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.only(
              top: 10, left: 8, right: 8, bottom: bottom + 6),
          decoration: const BoxDecoration(
            color: _kGlassFill,
            border: Border(
              top: BorderSide(color: _kGlassBorder, width: 1.5),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(6, (i) => _TabItem(
              icon:     _kTabIcons[i],
              label:    _kTabLabels[i],
              active:   i == currentIndex,
              accent:   kTabAccents[i],
              onTap:    () { HapticFeedback.selectionClick(); onTap(i); },
            )),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color accent;
  final VoidCallback onTap;

  const _TabItem({
    required this.icon, required this.label,
    required this.active, required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: active
            ? BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              child: Icon(
                icon,
                size: 22,
                color: active ? accent : kSub.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? accent : kSub.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 12.  LIQUID SECTION HEADER  (label + optional action)
// ═══════════════════════════════════════════════════════════════════════════════

class LiquidSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const LiquidSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w900,
                color: kInk, letterSpacing: -0.3,
              )),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(actionLabel!,
                  style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: kAmber,
                  )),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 13.  LIQUID MODAL SHEET HANDLE
// ═══════════════════════════════════════════════════════════════════════════════

class LiquidSheetHandle extends StatelessWidget {
  const LiquidSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36, height: 4,
        margin: const EdgeInsets.only(top: 12, bottom: 4),
        decoration: BoxDecoration(
          color: kInk.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 14.  ANIMATED PROGRESS RING  (canvas-drawn, no third-party dep)
// ═══════════════════════════════════════════════════════════════════════════════

class LiquidProgressRing extends StatelessWidget {
  final double progress;   // 0.0 – 1.0
  final double size;
  final double stroke;
  final Color  trackColor;
  final Color  fillColor;
  final Widget? center;

  const LiquidProgressRing({
    super.key,
    required this.progress,
    this.size       = 160,
    this.stroke     = 14,
    this.trackColor = const Color(0xFFEEEEEE),
    this.fillColor  = kInk,
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size, height: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress:   progress,
          stroke:     stroke,
          trackColor: trackColor,
          fillColor:  fillColor,
        ),
        child: center != null ? Center(child: center!) : null,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final double stroke;
  final Color  trackColor;
  final Color  fillColor;

  const _RingPainter({
    required this.progress,
    required this.stroke,
    required this.trackColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c    = Offset(size.width / 2, size.height / 2);
    final r    = size.width / 2 - stroke / 2;
    final rect = Rect.fromCircle(center: c, radius: r);

    // Track
    canvas.drawCircle(c, r, Paint()
      ..color       = trackColor
      ..style       = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap   = StrokeCap.round);

    // Fill
    if (progress > 0) {
      canvas.drawArc(rect, -math.pi / 2,
          2 * math.pi * progress.clamp(0, 1), false,
          Paint()
            ..color       = fillColor
            ..style       = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap   = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.fillColor != fillColor;
}

// ═══════════════════════════════════════════════════════════════════════════════
// 15.  ROUTE HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

Route<T> slideRoute<T>(Widget page) => PageRouteBuilder<T>(
  pageBuilder:      (_, __, ___) => page,
  transitionDuration: const Duration(milliseconds: 360),
  transitionsBuilder: (_, anim, __, child) => SlideTransition(
    position: Tween<Offset>(
      begin: const Offset(1, 0),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
    child: child,
  ),
);

Route<T> fadeRoute<T>(Widget page) => PageRouteBuilder<T>(
  pageBuilder:      (_, __, ___) => page,
  transitionDuration: const Duration(milliseconds: 300),
  transitionsBuilder: (_, anim, __, child) =>
      FadeTransition(opacity: anim, child: child),
);

// ═══════════════════════════════════════════════════════════════════════════════
// 16.  BOTTOM SHEET HELPER  (standard glass sheet)
// ═══════════════════════════════════════════════════════════════════════════════

Future<T?> showLiquidSheet<T>({
  required BuildContext context,
  required Widget child,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context:             context,
    isScrollControlled:  isScrollControlled,
    backgroundColor:     Colors.transparent,
    barrierColor:        Colors.black.withValues(alpha: 0.25),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: const BoxDecoration(
            color: _kGlassFill,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top:   BorderSide(color: _kGlassBorder, width: 1.5),
              left:  BorderSide(color: _kGlassBorder, width: 1),
              right: BorderSide(color: _kGlassBorder, width: 1),
            ),
          ),
          child: child,
        ),
      ),
    ),
  );
}
