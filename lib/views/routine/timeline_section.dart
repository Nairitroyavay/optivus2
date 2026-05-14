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

  final String? taskId;
  final TaskState? taskState;
  final DateTime? actualStart;
  final bool hasAlarm;
  final int durationMinutes;

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
    this.hasAlarm = false,
    this.durationMinutes = 60,
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

const double kTimelineTimeRailWidth = 64;
const double kTimelineHourHeight = 112.0;
const double kTimelinePixelsPerMinute = kTimelineHourHeight / 60.0;
const double _timelineRailDotColumnWidth = 12;
const double _timelineContentGap = 12;
const Key kTimelineTimeRailKey = ValueKey('timeline-time-rail');
const Key kTimelineDayScheduleKey = ValueKey('timeline-day-schedule');
const Key kTimelineCurrentTimeIndicatorKey =
    ValueKey('timeline-current-time-indicator');

Key timelineCardKey(DisplayBlock block) =>
    ValueKey('timeline-card-${block.taskId ?? block.title}-${block.time}');

String formatTimelineTime(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String formatTimelineDateTime(DateTime time) => formatTimelineTime(
      TimeOfDay(hour: time.hour, minute: time.minute),
    );

String formatTimelineMinute(int minuteOfDay) {
  final normalized = minuteOfDay.clamp(0, 1439).toInt();
  return formatTimelineTime(
    TimeOfDay(hour: normalized ~/ 60, minute: normalized % 60),
  );
}

String tlFmtMin(int m) => formatTimelineMinute(m);

int tlParseMin(String t) {
  final p = t.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

int parseTimelineMinute(String hhmm) => tlParseMin(tlNormalizeTime(hhmm));

double timelineYForMinute(
  int minute, {
  int timelineStartMinute = 0,
}) =>
    (minute - timelineStartMinute) * kTimelinePixelsPerMinute;

double timelineHeightForDuration(int durationMinutes) =>
    durationMinutes * kTimelinePixelsPerMinute;

int timelineDurationBetween(int startMinute, int endMinute) {
  var duration = endMinute - startMinute;
  if (duration <= 0) duration += 24 * 60;
  return duration;
}

int timelineDurationFromTimes(String startTime, String endTime) =>
    timelineDurationBetween(
      parseTimelineMinute(startTime),
      parseTimelineMinute(endTime),
    );

String tlMealLabel(String t) {
  final h = int.tryParse(t.split(':')[0]) ?? 0;
  return h < 10
      ? 'Breakfast'
      : h < 14
          ? 'Lunch'
          : h < 17
              ? 'Snack'
              : 'Dinner';
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
// DAY TIMELINE  (fixed 24-hour coordinate plane)
// ─────────────────────────────────────────────────────────────────────────────

class TimelineDaySchedule extends StatefulWidget {
  final List<DisplayBlock> blocks;
  final DateTime selectedDate;

  final ValueChanged<String>? onStart;
  final ValueChanged<String>? onPause;
  final ValueChanged<String>? onResume;
  final ValueChanged<String>? onComplete;
  final ValueChanged<String>? onSkip;
  final ValueChanged<String>? onAbandon;

  const TimelineDaySchedule({
    super.key,
    required this.blocks,
    required this.selectedDate,
    this.onStart,
    this.onPause,
    this.onResume,
    this.onComplete,
    this.onSkip,
    this.onAbandon,
  });

  @override
  State<TimelineDaySchedule> createState() => _TimelineDayScheduleState();
}

class _TimelineDayScheduleState extends State<TimelineDaySchedule> {
  final Map<String, Set<int>> _checkedByBlock = {};

  @override
  Widget build(BuildContext context) {
    final height = timelineHeightForDuration(24 * 60);
    final contentLeft = kTimelineTimeRailWidth +
        _timelineRailDotColumnWidth +
        _timelineContentGap;
    final visibleBlocks =
        widget.blocks.where((block) => !block.isEmptyPlaceholder).toList();

    return SizedBox(
      key: kTimelineDayScheduleKey,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            left:
                kTimelineTimeRailWidth + _timelineRailDotColumnWidth / 2 - 0.6,
            child: Align(
              alignment: Alignment.topLeft,
              child: Container(
                width: 1.2,
                height: height,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      kSub.withValues(alpha: 0.10),
                      kSub.withValues(alpha: 0.025),
                    ],
                  ),
                ),
              ),
            ),
          ),
          for (var hour = 0; hour < 24; hour++)
            _HourMarker(
              minute: hour * 60,
              isFirst: hour == 0,
            ),
          for (final block in visibleBlocks)
            _PositionedTimelineCard(
              block: block,
              contentLeft: contentLeft,
              checked: _checkedByBlock.putIfAbsent(
                block.taskId ?? '${block.time}_${block.title}',
                () => <int>{},
              ),
              onToggle: (index) {
                final key = block.taskId ?? '${block.time}_${block.title}';
                final checked = _checkedByBlock.putIfAbsent(key, () => <int>{});
                setState(() {
                  if (checked.contains(index)) {
                    checked.remove(index);
                  } else {
                    checked.add(index);
                  }
                });
              },
              onStart: widget.onStart,
              onPause: widget.onPause,
              onResume: widget.onResume,
              onComplete: widget.onComplete,
              onSkip: widget.onSkip,
              onAbandon: widget.onAbandon,
            ),
          Positioned.fill(
            child: TimelineCurrentTimeIndicator(
              selectedDate: widget.selectedDate,
              startMinute: 0,
              durationMinutes: 24 * 60,
              color: kRose,
            ),
          ),
        ],
      ),
    );
  }
}

class _HourMarker extends StatelessWidget {
  final int minute;
  final bool isFirst;

  const _HourMarker({
    required this.minute,
    required this.isFirst,
  });

  @override
  Widget build(BuildContext context) {
    final top = timelineYForMinute(minute);
    const dotSize = 8.0;

    return Positioned(
      top: top - dotSize / 2,
      left: 0,
      right: 0,
      height: 18,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            key: isFirst ? kTimelineTimeRailKey : null,
            width: kTimelineTimeRailWidth,
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text(
                formatTimelineMinute(minute),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.visible,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: kSub.withValues(alpha: 0.62),
                ),
              ),
            ),
          ),
          Container(
            width: dotSize,
            height: dotSize,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: kSub.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: _timelineContentGap),
          Expanded(
            child: Container(
              height: 1,
              color: kSub.withValues(alpha: 0.055),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}

class _PositionedTimelineCard extends StatelessWidget {
  final DisplayBlock block;
  final double contentLeft;
  final Set<int> checked;
  final ValueChanged<int> onToggle;
  final ValueChanged<String>? onStart;
  final ValueChanged<String>? onPause;
  final ValueChanged<String>? onResume;
  final ValueChanged<String>? onComplete;
  final ValueChanged<String>? onSkip;
  final ValueChanged<String>? onAbandon;

  const _PositionedTimelineCard({
    required this.block,
    required this.contentLeft,
    required this.checked,
    required this.onToggle,
    this.onStart,
    this.onPause,
    this.onResume,
    this.onComplete,
    this.onSkip,
    this.onAbandon,
  });

  @override
  Widget build(BuildContext context) {
    final startMinute = parseTimelineMinute(block.time).clamp(0, 1439).toInt();
    final durationMinutes = block.durationMinutes.clamp(1, 24 * 60).toInt();
    final top = timelineYForMinute(startMinute);
    final actualHeight = timelineHeightForDuration(durationMinutes);
    final visualHeight =
        durationMinutes < 30 && actualHeight < 44 ? 44.0 : actualHeight;

    assert(() {
      final bottom = top + actualHeight;
      return bottom == timelineYForMinute(startMinute + durationMinutes);
    }());

    return Positioned(
      top: top,
      left: contentLeft,
      right: 16,
      height: visualHeight,
      child: SizedBox.expand(
        key: timelineCardKey(block),
        child: _EventCard(
          block: block,
          checked: checked,
          onToggle: onToggle,
          onStart: onStart,
          onPause: onPause,
          onResume: onResume,
          onComplete: onComplete,
          onSkip: onSkip,
          onAbandon: onAbandon,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TIMELINE ROW  (single animated event)
// ─────────────────────────────────────────────────────────────────────────────

class TimelineRow extends StatefulWidget {
  final DisplayBlock block;
  final bool showHourLabel;
  final bool isLast;
  final int index; // used for staggered entrance
  final DateTime? selectedDate;

  // ── Task action callbacks (null when block has no taskId) ──
  final ValueChanged<String>? onStart;
  final ValueChanged<String>? onPause;
  final ValueChanged<String>? onResume;
  final ValueChanged<String>? onComplete;
  final ValueChanged<String>? onSkip;
  final ValueChanged<String>? onAbandon;

  const TimelineRow({
    super.key,
    required this.block,
    required this.showHourLabel,
    required this.isLast,
    this.index = 0,
    this.selectedDate,
    this.onStart,
    this.onPause,
    this.onResume,
    this.onComplete,
    this.onSkip,
    this.onAbandon,
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
    if (widget.index == 0) {
      _entryCtrl.forward();
    } else {
      Future.delayed(Duration(milliseconds: 40 * widget.index), () {
        if (mounted) _entryCtrl.forward();
      });
    }
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
    final rowContent = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Time column ─────────────────────────────────────────────────
          SizedBox(
            key: kTimelineTimeRailKey,
            width: kTimelineTimeRailWidth,
            child: Padding(
              padding: const EdgeInsets.only(right: 10, top: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (widget.showHourLabel)
                    Text(
                      tlFmtMin(tlParseMin(b.time)),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: kSub.withValues(alpha: 0.62),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // ── Rail ────────────────────────────────────────────────────────
          _Rail(
            accentColor: b.accentColor == Colors.transparent
                ? kSub.withValues(alpha: 0.18)
                : b.accentColor,
            isNow: b.isNow,
            isLast: widget.isLast,
            isEmptyPlaceholder: b.isEmptyPlaceholder,
          ),
          const SizedBox(width: _timelineContentGap),
          // ── Timeline content ────────────────────────────────────────────
          Expanded(
            child: b.isEmptyPlaceholder
                ? const SizedBox(height: 60)
                : Padding(
                    padding: const EdgeInsets.only(right: 16, bottom: 14),
                    child: _EventCard(
                      block: b,
                      checked: _checked,
                      onToggle: (i) {
                        setState(() {
                          if (_checked.contains(i)) {
                            _checked.remove(i);
                          } else {
                            _checked.add(i);
                          }
                        });
                      },
                      onStart: widget.onStart,
                      onPause: widget.onPause,
                      onResume: widget.onResume,
                      onComplete: widget.onComplete,
                      onSkip: widget.onSkip,
                      onAbandon: widget.onAbandon,
                    ),
                  ),
          ),
        ],
      ),
    );

    if (b.isNow) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          rowContent,
          Positioned.fill(
            child: TimelineCurrentTimeIndicator(
              selectedDate: widget.selectedDate ?? DateTime.now(),
              startMinute: tlParseMin(b.time),
              durationMinutes: b.durationMinutes,
              color:
                  b.accentColor == Colors.transparent ? kRose : b.accentColor,
            ),
          ),
        ],
      );
    }
    return rowContent;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CURRENT TIME INDICATOR OVERLAY
// ─────────────────────────────────────────────────────────────────────────────

class TimelineCurrentTimeIndicator extends StatelessWidget {
  final DateTime selectedDate;
  final int startMinute;
  final int durationMinutes;
  final Color color;

  const TimelineCurrentTimeIndicator({
    super.key,
    required this.selectedDate,
    required this.startMinute,
    required this.durationMinutes,
    required this.color,
  });

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isToday(selectedDate)) return const SizedBox.shrink();

    return IgnorePointer(
      child: CurrentTimeIndicatorOverlay(
        key: kTimelineCurrentTimeIndicatorKey,
        startMinute: startMinute,
        durationMinutes: durationMinutes,
        color: color,
      ),
    );
  }
}

class CurrentTimeIndicatorOverlay extends StatefulWidget {
  final int startMinute;
  final int durationMinutes;
  final Color color;

  const CurrentTimeIndicatorOverlay({
    super.key,
    required this.startMinute,
    required this.durationMinutes,
    required this.color,
  });

  @override
  State<CurrentTimeIndicatorOverlay> createState() =>
      _CurrentTimeIndicatorOverlayState();
}

class _CurrentTimeIndicatorOverlayState
    extends State<CurrentTimeIndicatorOverlay> {
  Timer? _timer;
  int _currentMinute = 0;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) _updateTime();
    });
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _currentMinute = now.hour * 60 + now.minute;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine the vertical fraction within this row's duration.
    double fraction = 0;
    if (widget.durationMinutes > 0) {
      fraction = (_currentMinute - widget.startMinute) / widget.durationMinutes;
      fraction = fraction.clamp(0.0, 1.0);
    }

    final displayTimeStr = tlFmtMin(_currentMinute);

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final topOffset = height * fraction;
        final dotSize = 8.0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: topOffset - dotSize / 2,
              left: 0,
              right: 0,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Time Label
                  SizedBox(
                    width: kTimelineTimeRailWidth,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: Text(
                        displayTimeStr,
                        key: const ValueKey('timeline-current-time-label'),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          color: widget.color,
                        ),
                      ),
                    ),
                  ),
                  // Dot on rail
                  Container(
                    width: dotSize,
                    height: dotSize,
                    margin: EdgeInsets.only(
                      left: (_timelineRailDotColumnWidth - dotSize) / 2,
                      right: _timelineContentGap,
                    ),
                    decoration: BoxDecoration(
                      color: widget.color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: widget.color.withValues(alpha: 0.5),
                          blurRadius: 6,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  // Dotted Line
                  Expanded(
                    child: CustomPaint(
                      painter: _DottedLinePainter(color: widget.color),
                      size: const Size.fromHeight(1),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DottedLinePainter extends CustomPainter {
  final Color color;
  _DottedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.52)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    const dashWidth = 3.5;
    const dashSpace = 5.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + dashWidth, 0),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DottedLinePainter oldDelegate) {
    return oldDelegate.color != color;
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
          width:
              isEmptyPlaceholder ? 8 : 12, // Smaller dot for empty placeholder
          height: isEmptyPlaceholder ? 8 : 12,
          margin: isEmptyPlaceholder
              ? const EdgeInsets.only(left: 2, right: 2)
              : EdgeInsets.zero,
          decoration: BoxDecoration(
            color:
                isEmptyPlaceholder ? kSub.withValues(alpha: 0.15) : accentColor,
            shape: BoxShape.circle,
            border: isEmptyPlaceholder
                ? null
                : Border.all(
                    color: Colors.white.withValues(alpha: 0.85),
                    width: isNow ? 2.5 : 2.0,
                  ),
            boxShadow: isEmptyPlaceholder
                ? null
                : [
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
              width: 1.2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    isEmptyPlaceholder
                        ? kSub.withValues(alpha: 0.055)
                        : accentColor.withValues(alpha: 0.18),
                    kSub.withValues(alpha: 0.025),
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
  final ValueChanged<String>? onPause;
  final ValueChanged<String>? onResume;
  final ValueChanged<String>? onComplete;
  final ValueChanged<String>? onSkip;
  final ValueChanged<String>? onAbandon;

  const _EventCard({
    required this.block,
    required this.checked,
    required this.onToggle,
    this.onStart,
    this.onPause,
    this.onResume,
    this.onComplete,
    this.onSkip,
    this.onAbandon,
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.hasBoundedHeight &&
                  constraints.maxHeight <= kTimelineHourHeight;
              final padding = isCompact ? 10.0 : 14.0;
              final iconSize = isCompact ? 34.0 : 42.0;
              final titleSize = isCompact ? 13.5 : 14.5;
              final subtitleSize = isCompact ? 11.5 : 12.0;
              final iconRadius = isCompact ? 10.0 : 13.0;
              final emojiSize = isCompact ? 17.0 : 20.0;
              final contentGap = isCompact ? 8.0 : 11.0;
              final actionGap = isCompact ? 6.0 : 10.0;
              final showCategory = b.type != RoutineFilter.all && !isCompact;

              return Padding(
                padding: EdgeInsets.all(padding),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Accent bar
                    Container(
                      width: 3.5,
                      height: b.subtasks.isEmpty
                          ? iconSize
                          : iconSize + b.subtasks.length * 32.0,
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
                      width: iconSize,
                      height: iconSize,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            b.accentColor.withValues(alpha: 0.22),
                            b.accentColor.withValues(alpha: 0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(iconRadius),
                        border: Border.all(
                          color: b.accentColor.withValues(alpha: 0.18),
                          width: 1.2,
                        ),
                      ),
                      child: Center(
                        child: Text(b.emoji,
                            style: TextStyle(fontSize: emojiSize)),
                      ),
                    ),
                    SizedBox(width: contentGap),
                    // Text content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category chip (when not "all")
                          if (showCategory) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: b.accentColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                filterMetaData[b.type]?.label.toUpperCase() ??
                                    '',
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
                            style: TextStyle(
                              fontSize: titleSize,
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
                              fontSize: subtitleSize,
                              color: kSub,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (b.hasAlarm &&
                              b.taskId != null &&
                              (b.taskState ?? TaskState.scheduled) ==
                                  TaskState.scheduled) ...[
                            const SizedBox(height: 7),
                            _AlarmChip(color: b.accentColor),
                          ],
                          // ── Task action row ──────────────────────────────
                          if (b.taskId != null) ...[
                            SizedBox(height: actionGap),
                            _TaskActionRow(
                              block: b,
                              onStart: widget.onStart,
                              onPause: widget.onPause,
                              onResume: widget.onResume,
                              onComplete: widget.onComplete,
                              onSkip: widget.onSkip,
                              onAbandon: widget.onAbandon,
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
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AlarmChip extends StatelessWidget {
  final Color color;

  const _AlarmChip({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.alarm_rounded, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            'Alarm',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
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
                child: Text(m.emoji, style: const TextStyle(fontSize: 38)),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No ${m.label.toLowerCase()} today',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: kInk),
            ),
            const SizedBox(height: 8),
            Text(
              'Set up your ${m.label.toLowerCase()} routine\nand it will appear here automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: kSub, height: 1.55),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: 200,
              child: LiquidButton(
                  label: 'Set up ${m.label}', color: m.color, onTap: onSetup),
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
  final ValueChanged<String>? onPause;
  final ValueChanged<String>? onResume;
  final ValueChanged<String>? onComplete;
  final ValueChanged<String>? onSkip;
  final ValueChanged<String>? onAbandon;

  const _TaskActionRow({
    required this.block,
    this.onStart,
    this.onPause,
    this.onResume,
    this.onComplete,
    this.onSkip,
    this.onAbandon,
  });

  @override
  Widget build(BuildContext context) {
    final state = block.taskState ?? TaskState.scheduled;
    final taskId = block.taskId!;

    switch (state) {
      case TaskState.scheduled:
        // When callbacks are null, the task is from a past date — show
        // a read-only badge instead of action buttons.
        if (onStart == null) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: kSub.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history_rounded, size: 14, color: kSub),
                const SizedBox(width: 5),
                Text(
                  'Past',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: kSub,
                  ),
                ),
              ],
            ),
          );
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ActionPill(
              label: 'Start',
              icon: Icons.play_arrow_rounded,
              colors: const [Color(0xFF60D4A0), Color(0xFF4EC890)],
              textColor: Colors.white,
              onTap: () {
                HapticFeedback.mediumImpact();
                onStart?.call(taskId);
              },
            ),
            _ActionPill(
              label: 'Skip',
              icon: Icons.skip_next_rounded,
              colors: [
                kSub.withValues(alpha: 0.18),
                kSub.withValues(alpha: 0.10)
              ],
              textColor: kSub,
              onTap: () {
                HapticFeedback.mediumImpact();
                onSkip?.call(taskId);
              },
            ),
          ],
        );
      case TaskState.started:
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _ElapsedTimerChip(startedAt: block.actualStart ?? DateTime.now()),
            _ActionPill(
              label: 'Pause',
              icon: Icons.pause_rounded,
              colors: const [Color(0xFFFBBF24), Color(0xFFF59E0B)],
              textColor: Colors.white,
              onTap: () {
                HapticFeedback.mediumImpact();
                onPause?.call(taskId);
              },
            ),
            _ActionPill(
              label: 'Complete',
              icon: Icons.check_rounded,
              colors: const [Color(0xFF34D399), Color(0xFF10B981)],
              textColor: Colors.white,
              onTap: () {
                HapticFeedback.mediumImpact();
                onComplete?.call(taskId);
              },
            ),
            _ActionPill(
              label: 'Abandon',
              icon: Icons.close_rounded,
              colors: const [Color(0xFFFB7185), Color(0xFFE11D48)],
              textColor: Colors.white,
              onTap: () {
                HapticFeedback.mediumImpact();
                onAbandon?.call(taskId);
              },
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
            color: const Color(0xFFFB7185).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cancel_rounded,
                  size: 13, color: Color(0xFFE11D48)),
              const SizedBox(width: 4),
              Text(
                'Abandoned',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFE11D48),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        );
      case TaskState.skipped:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: kSub.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.skip_next_rounded, size: 14, color: kSub),
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
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ActionPill(
              label: 'Resume',
              icon: Icons.play_arrow_rounded,
              colors: const [Color(0xFF60D4A0), Color(0xFF4EC890)],
              textColor: Colors.white,
              onTap: () {
                HapticFeedback.mediumImpact();
                onResume?.call(taskId);
              },
            ),
            _ActionPill(
              label: 'Complete',
              icon: Icons.check_rounded,
              colors: const [Color(0xFF34D399), Color(0xFF10B981)],
              textColor: Colors.white,
              onTap: () {
                HapticFeedback.mediumImpact();
                onComplete?.call(taskId);
              },
            ),
            _ActionPill(
              label: 'Abandon',
              icon: Icons.close_rounded,
              colors: const [Color(0xFFFB7185), Color(0xFFE11D48)],
              textColor: Colors.white,
              onTap: () {
                HapticFeedback.mediumImpact();
                onAbandon?.call(taskId);
              },
            ),
          ],
        );
    }
  }
}

class TimelineStatusState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const TimelineStatusState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 44, 28, 80),
      child: Column(
        children: [
          Icon(icon, size: 30, color: kSub),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: kInk,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: kSub.withValues(alpha: 0.82)),
          ),
        ],
      ),
    );
  }
}

class TimelineDayEmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const TimelineDayEmptyState({super.key, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 36, 28, 80),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: kPurple.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.add_task_rounded, color: kPurple, size: 34),
          ),
          const SizedBox(height: 16),
          const Text(
            'No tasks scheduled',
            style: TextStyle(
              color: kInk,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add a one-off task or create a repeating template for this day.',
            textAlign: TextAlign.center,
            style: TextStyle(color: kSub.withValues(alpha: 0.82), height: 1.4),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Task'),
            style: FilledButton.styleFrom(
              backgroundColor: kPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTION PILL — glass-style tap button for Start / Complete
// ─────────────────────────────────────────────────────────────────────────────

class _ActionPill extends StatefulWidget {
  final String label;
  final IconData icon;
  final List<Color> colors;
  final Color textColor;
  final VoidCallback onTap;

  const _ActionPill({
    required this.label,
    required this.icon,
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
          padding: const EdgeInsets.symmetric(horizontal: 12),
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 15, color: widget.textColor),
              const SizedBox(width: 4),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: widget.textColor,
                  letterSpacing: 0.3,
                ),
              ),
            ],
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
            color:
                Color(0xFF34D399).withValues(alpha: _glowOpacity.value * 0.5),
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
