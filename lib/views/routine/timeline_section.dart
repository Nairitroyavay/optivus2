// lib/routine/timeline_section.dart
//
// Optivus – Redesigned Timeline Section
// A premium, animated vertical timeline for the Routine tab.
//
// Exports:
//   • TimelineSection          – full infinite-scroll sliver list
//   • TimelineRow              – single event card (public so other widgets can render one)
//   • timeline helpers         – _hexColor, _fmtMin, _parseMin, _mealLabel, _normalizeTime

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/models/task_model.dart';
import 'glass_filter_dropdown.dart';
import 'package:optivus2/providers/routine_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODEL
// ─────────────────────────────────────────────────────────────────────────────

class DisplayBlock {
  final String time, title, subtitle, emoji;
  final Color accentColor;
  final RoutineFilter type;
  final List<String> subtasks;
  final bool isNow;
  final bool isEmptyPlaceholder; // true when rendering an empty hour slot

  // ── Firestore task fields (null for legacy routine-only blocks) ──
  final String? taskId;
  final TaskState? taskState;
  final DateTime? actualStart;

  const DisplayBlock({
    required this.time,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.emoji,
    required this.type,
    this.subtasks = const [],
    this.isNow = false,
    this.isEmptyPlaceholder = false,
    this.taskId,
    this.taskState,
    this.actualStart,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS (top-level so routine_tab can access them)
// ─────────────────────────────────────────────────────────────────────────────

Color tlHexColor(String hex) {
  try {
    return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
  } catch (_) {
    return kPurple;
  }
}

String tlFmtMin(int m) =>
    '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

int tlParseMin(String t) {
  final p = t.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

String tlMealLabel(String t) {
  final h = int.tryParse(t.split(':')[0]) ?? 0;
  return h < 10 ? 'Breakfast' : h < 14 ? 'Lunch' : h < 17 ? 'Snack' : 'Dinner';
}

String tlNormalizeTime(String t) {
  final upper = t.trim().toUpperCase();
  final isPm = upper.endsWith('PM');
  final isAm = upper.endsWith('AM');
  if (!isPm && !isAm) return t;
  final parts = upper.replaceAll(RegExp(r'[AP]M'), '').trim().split(':');
  int hour = int.tryParse(parts[0]) ?? 0;
  final int minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
  if (isPm && hour != 12) hour += 12;
  if (isAm && hour == 12) hour = 0;
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

// Converts HH:MM 24h → "09:00 AM" style for display inside cards
String _to12h(String t) {
  final parts = t.split(':');
  if (parts.length < 2) return t;
  int h = int.tryParse(parts[0]) ?? 0;
  final int m = int.tryParse(parts[1]) ?? 0;
  final suffix = h < 12 ? 'AM' : 'PM';
  if (h == 0) h = 12;
  if (h > 12) h -= 12;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $suffix';
}

// ─────────────────────────────────────────────────────────────────────────────
// TIMELINE ROW  (single animated event)
// ─────────────────────────────────────────────────────────────────────────────

class TimelineRow extends StatefulWidget {
  final DisplayBlock block;
  final bool showHourLabel;
  final bool isLast;
  final int index; // used for staggered entrance

  // ── Task action callbacks (null when block has no taskId) ──
  final ValueChanged<String>? onStart;
  final ValueChanged<String>? onComplete;

  const TimelineRow({
    super.key,
    required this.block,
    required this.showHourLabel,
    required this.isLast,
    this.index = 0,
    this.onStart,
    this.onComplete,
  });

  @override
  State<TimelineRow> createState() => _TimelineRowState();
}

class _TimelineRowState extends State<TimelineRow>
    with SingleTickerProviderStateMixin {
  final _checked = <int>{};

  // --- entrance animation ---
  late AnimationController _entryCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    // stagger by index
    Future.delayed(Duration(milliseconds: 40 * widget.index), () {
      if (mounted) _entryCtrl.forward();
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.block;
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: _buildRow(b),
      ),
    );
  }

  Widget _buildRow(DisplayBlock b) {
    if (b.isEmptyPlaceholder) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Time column ─────────────────────────────────────────────────
            SizedBox(
              width: 70,
              child: Padding(
                padding: const EdgeInsets.only(left: 16, top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.showHourLabel)
                      Text(
                        b.time,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: kSub.withValues(alpha: 0.5),
                          letterSpacing: 0.4,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // ── Rail ────────────────────────────────────────────────────────
            _Rail(
              accentColor: kSub.withValues(alpha: 0.2), // Dim dot
              isNow: false,
              isLast: widget.isLast,
              isEmptyPlaceholder: true,
            ),
            const SizedBox(width: 10),
            // ── Empty Space ─────────────────────────────────────────────────
            Expanded(
              child: SizedBox(height: 60), // Fixed height to maintain scroll proportion
            ),
          ],
        ),
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Time column ─────────────────────────────────────────────────
          SizedBox(
            width: 70,
            child: Padding(
              padding: const EdgeInsets.only(left: 16, top: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.showHourLabel)
                    Text(
                      b.time,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: kSub,
                        letterSpacing: 0.4,
                      ),
                    ),
                  if (b.isNow) ...[
                    const SizedBox(height: 5),
                    _NowBadge(),
                  ],
                ],
              ),
            ),
          ),

          // ── Rail ────────────────────────────────────────────────────────
          _Rail(
            accentColor: b.accentColor,
            isNow: b.isNow,
            isLast: widget.isLast,
          ),

          const SizedBox(width: 10),

          // ── Card ────────────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
              child: _EventCard(
                block: b,
                checked: _checked,
                onToggle: (i) => setState(() {
                  _checked.contains(i) ? _checked.remove(i) : _checked.add(i);
                }),
                onStart: widget.onStart,
                onComplete: widget.onComplete,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NOW BADGE  — pulsing red pill
// ─────────────────────────────────────────────────────────────────────────────

class _NowBadge extends StatefulWidget {
  @override
  State<_NowBadge> createState() => _NowBadgeState();
}

class _NowBadgeState extends State<_NowBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.85, end: 1.15)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
    _opacity = Tween<double>(begin: 0.6, end: 1.0)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        return Row(
          children: [
            Transform.scale(
              scale: _scale.value,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF3B30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF3B30)
                          .withValues(alpha: 0.55 * _opacity.value),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            Opacity(
              opacity: _opacity.value,
              child: const Text(
                'NOW',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFF3B30),
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RAIL  — dot + vertical line connector
// ─────────────────────────────────────────────────────────────────────────────

class _Rail extends StatelessWidget {
  final Color accentColor;
  final bool isNow;
  final bool isLast;
  final bool isEmptyPlaceholder;

  const _Rail({
    required this.accentColor,
    required this.isNow,
    required this.isLast,
    this.isEmptyPlaceholder = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        // Dot
        Container(
          width: isEmptyPlaceholder ? 8 : 12, // Smaller dot for empty placeholder
          height: isEmptyPlaceholder ? 8 : 12,
          margin: isEmptyPlaceholder ? const EdgeInsets.only(left: 2, right: 2) : EdgeInsets.zero,
          decoration: BoxDecoration(
            color: isEmptyPlaceholder ? kSub.withValues(alpha: 0.15) : accentColor,
            shape: BoxShape.circle,
            border: isEmptyPlaceholder ? null : Border.all(
              color: Colors.white.withValues(alpha: 0.85),
              width: isNow ? 2.5 : 2.0,
            ),
            boxShadow: isEmptyPlaceholder ? null : [
              BoxShadow(
                color: accentColor.withValues(alpha: isNow ? 0.6 : 0.35),
                blurRadius: isNow ? 10 : 6,
                spreadRadius: isNow ? 2 : 0,
              ),
            ],
          ),
        ),
        // Line
        if (!isLast)
          Expanded(
            child: Container(
              width: 1.5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    isEmptyPlaceholder ? kSub.withValues(alpha: 0.1) : accentColor.withValues(alpha: 0.30),
                    kSub.withValues(alpha: 0.08),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EVENT CARD  — frosted glass card with accent bar, emoji icon, subtasks
// ─────────────────────────────────────────────────────────────────────────────

class _EventCard extends StatefulWidget {
  final DisplayBlock block;
  final Set<int> checked;
  final ValueChanged<int> onToggle;
  final ValueChanged<String>? onStart;
  final ValueChanged<String>? onComplete;

  const _EventCard({
    required this.block,
    required this.checked,
    required this.onToggle,
    this.onStart,
    this.onComplete,
  });

  @override
  State<_EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<_EventCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.block;
    final isNow = b.isNow;

    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        _pressCtrl.forward();
      },
      onTapUp: (_) => _pressCtrl.reverse(),
      onTapCancel: () => _pressCtrl.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: isNow
                ? b.accentColor.withValues(alpha: 0.10)
                : Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isNow
                  ? b.accentColor.withValues(alpha: 0.45)
                  : Colors.white.withValues(alpha: 0.80),
              width: isNow ? 1.5 : 1.2,
            ),
            boxShadow: [
              if (isNow)
                BoxShadow(
                  color: b.accentColor.withValues(alpha: 0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                )
              else
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.55),
                blurRadius: 0,
                offset: const Offset(-1, -1),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Accent bar
                Container(
                  width: 3.5,
                  height: b.subtasks.isEmpty
                      ? 42
                      : 42 + b.subtasks.length * 32.0,
                  margin: const EdgeInsets.only(right: 10, top: 2),
                  decoration: BoxDecoration(
                    color: b.accentColor,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: b.accentColor.withValues(alpha: 0.45),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                // Emoji icon box
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        b.accentColor.withValues(alpha: 0.22),
                        b.accentColor.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: b.accentColor.withValues(alpha: 0.18),
                      width: 1.2,
                    ),
                  ),
                  child: Center(
                    child: Text(b.emoji,
                        style: const TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 11),
                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category chip (when not "all")
                      if (b.type != RoutineFilter.all) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: b.accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            filterMetaData[b.type]?.label.toUpperCase() ?? '',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              color: b.accentColor,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                      ],
                      Text(
                        b.title,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: kInk,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _to12h(b.time) == b.subtitle
                            ? b.subtitle
                            : b.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: kSub,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      // ── Task action row ──────────────────────────────
                      if (b.taskId != null) ...[
                        const SizedBox(height: 10),
                        _TaskActionRow(
                          block: b,
                          onStart: widget.onStart,
                          onComplete: widget.onComplete,
                        ),
                      ],
                      // Subtasks
                      if (b.subtasks.isNotEmpty) ...[
                        const SizedBox(height: 11),
                        ...List.generate(b.subtasks.length, (i) {
                          final done = widget.checked.contains(i);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 7),
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                widget.onToggle(i);
                              },
                              child: Row(children: [
                                _MiniCheckbox(
                                    value: done, color: b.accentColor),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: AnimatedDefaultTextStyle(
                                    duration:
                                        const Duration(milliseconds: 200),
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                      color: done ? kSub : kInk,
                                      decoration: done
                                          ? TextDecoration.lineThrough
                                          : TextDecoration.none,
                                      decorationColor: kSub,
                                    ),
                                    child: Text(b.subtasks[i]),
                                  ),
                                ),
                              ]),
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MINI CHECKBOX  — compact animated checkbox for subtasks
// ─────────────────────────────────────────────────────────────────────────────

class _MiniCheckbox extends StatefulWidget {
  final bool value;
  final Color color;
  const _MiniCheckbox({required this.value, required this.color});

  @override
  State<_MiniCheckbox> createState() => _MiniCheckboxState();
}

class _MiniCheckboxState extends State<_MiniCheckbox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

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
  void didUpdateWidget(_MiniCheckbox old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      widget.value ? _ctrl.forward() : _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Color.lerp(
              Colors.white.withValues(alpha: 0.75),
              widget.color,
              t,
            ),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: Color.lerp(
                kSub.withValues(alpha: 0.30),
                widget.color,
                t,
              )!,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.25 * t),
                blurRadius: 6,
              ),
            ],
          ),
          child: t > 0.5
              ? Center(
                  child: Icon(
                    Icons.check_rounded,
                    size: 12,
                    color: Colors.white.withValues(alpha: t),
                  ),
                )
              : null,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DIVIDER HEADER  — date separator for multi-day scroll
// ─────────────────────────────────────────────────────────────────────────────

class TimelineDayHeader extends StatelessWidget {
  final String label;
  const TimelineDayHeader({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(children: [
        Container(
          height: 1,
          width: 16,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              Colors.transparent,
              kSub.withValues(alpha: 0.18),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: kSub.withValues(alpha: 0.75),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                kSub.withValues(alpha: 0.18),
                Colors.transparent,
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE  — shown when no tasks for filter
// ─────────────────────────────────────────────────────────────────────────────

class TimelineEmptyState extends StatelessWidget {
  final RoutineFilter filter;
  final VoidCallback onSetup;
  const TimelineEmptyState(
      {super.key, required this.filter, required this.onSetup});

  @override
  Widget build(BuildContext context) {
    final m = filterMetaData[filter]!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon in glass pill
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: m.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: m.color.withValues(alpha: 0.22),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(m.emoji,
                    style: const TextStyle(fontSize: 38)),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No ${m.label.toLowerCase()} today',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: kInk),
            ),
            const SizedBox(height: 8),
            Text(
              'Set up your ${m.label.toLowerCase()} routine\nand it will appear here automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13.5, color: kSub, height: 1.55),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: 200,
              child: LiquidButton(
                  label: 'Set up ${m.label}',
                  color: m.color,
                  onTap: onSetup),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TASK ACTION ROW — Start / Complete buttons + state badges
// ─────────────────────────────────────────────────────────────────────────────

class _TaskActionRow extends StatelessWidget {
  final DisplayBlock block;
  final ValueChanged<String>? onStart;
  final ValueChanged<String>? onComplete;

  const _TaskActionRow({
    required this.block,
    this.onStart,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final state = block.taskState ?? TaskState.scheduled;
    final taskId = block.taskId!;

    switch (state) {
      case TaskState.scheduled:
        return _ActionPill(
          label: '▶  Start',
          colors: [const Color(0xFF60D4A0), const Color(0xFF4EC890)],
          textColor: Colors.white,
          onTap: () {
            HapticFeedback.mediumImpact();
            onStart?.call(taskId);
          },
        );
      case TaskState.started:
        return Row(
          children: [
            _ElapsedTimerChip(startedAt: block.actualStart ?? DateTime.now()),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionPill(
                label: '✓  Done',
                colors: [const Color(0xFF34D399), const Color(0xFF10B981)],
                textColor: Colors.white,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  onComplete?.call(taskId);
                },
              ),
            ),
          ],
        );
      case TaskState.completed:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF34D399).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded,
                  size: 14, color: Color(0xFF10B981)),
              const SizedBox(width: 5),
              Text(
                'Completed',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF10B981),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        );
      case TaskState.abandoned:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: kSub.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.close_rounded, size: 13, color: kSub),
              const SizedBox(width: 4),
              Text(
                'Skipped',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: kSub,
                ),
              ),
            ],
          ),
        );
      case TaskState.paused:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFFBBF24).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.pause_circle_filled_rounded,
                  size: 14, color: Color(0xFFF59E0B)),
              const SizedBox(width: 5),
              Text(
                'Paused',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFF59E0B),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTION PILL — glass-style tap button for Start / Complete
// ─────────────────────────────────────────────────────────────────────────────

class _ActionPill extends StatefulWidget {
  final String label;
  final List<Color> colors;
  final Color textColor;
  final VoidCallback onTap;

  const _ActionPill({
    required this.label,
    required this.colors,
    required this.textColor,
    required this.onTap,
  });

  @override
  State<_ActionPill> createState() => _ActionPillState();
}

class _ActionPillState extends State<_ActionPill>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.94)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            gradient: LinearGradient(
              colors: widget.colors,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.colors.first.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: widget.textColor,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ELAPSED TIMER CHIP — live elapsed-time display for active tasks
// ─────────────────────────────────────────────────────────────────────────────

class _ElapsedTimerChip extends StatefulWidget {
  final DateTime startedAt;
  const _ElapsedTimerChip({required this.startedAt});

  @override
  State<_ElapsedTimerChip> createState() => _ElapsedTimerChipState();
}

class _ElapsedTimerChipState extends State<_ElapsedTimerChip>
    with SingleTickerProviderStateMixin {
  late Timer _timer;
  Duration _elapsed = Duration.zero;

  late AnimationController _pulse;
  late Animation<double> _glowOpacity;

  @override
  void initState() {
    super.initState();
    _elapsed = DateTime.now().difference(widget.startedAt);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _elapsed = DateTime.now().difference(widget.startedAt);
        });
      }
    });

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _glowOpacity = Tween<double>(begin: 0.3, end: 0.8)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _timer.cancel();
    _pulse.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowOpacity,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF34D399).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Color(0xFF34D399)
                .withValues(alpha: _glowOpacity.value * 0.5),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF34D399)
                  .withValues(alpha: _glowOpacity.value * 0.20),
              blurRadius: 8,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_rounded,
                size: 13,
                color: const Color(0xFF10B981)
                    .withValues(alpha: 0.5 + _glowOpacity.value * 0.5)),
            const SizedBox(width: 4),
            Text(
              _fmt(_elapsed),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF10B981),
                fontFeatures: [FontFeature.tabularFigures()],
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
