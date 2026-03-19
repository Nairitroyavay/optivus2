import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/routine_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────

const _kInk   = Color(0xFF0F111A);
const _kSub   = Color(0xFF6B7280);
const _kBg    = Color(0xFFFAF7F0);
const _kCard  = Colors.white;
const _kShad  = Color(0x0D000000);

// 1 hour = 72px on the timeline
const double _kHourH = 72.0;
// Total scrollable height = 24 hours
const double _kTotalH = _kHourH * 24;
// Left column width for time labels
const double _kTimeW  = 72.0;

const _kHours = [
  '12 AM','1 AM','2 AM','3 AM','4 AM','5 AM','6 AM','7 AM',
  '8 AM','9 AM','10 AM','11 AM','12 PM','1 PM','2 PM','3 PM',
  '4 PM','5 PM','6 PM','7 PM','8 PM','9 PM','10 PM','11 PM',
];

// Pre-defined block types
class _BlockTemplate {
  final String id;
  final String title;
  final String emoji;
  final Color  color;
  final int    defaultStart; // minutes from midnight
  final int    defaultEnd;
  const _BlockTemplate({
    required this.id, required this.title,
    required this.emoji, required this.color,
    required this.defaultStart, required this.defaultEnd,
  });
}

const _templates = [
  _BlockTemplate(id:'sleep',   title:'Sleep',    emoji:'🛏️',
      color: Color(0xFFC084FC), defaultStart:   0, defaultEnd: 390),
  _BlockTemplate(id:'classes', title:'Classes',  emoji:'🎓',
      color: Color(0xFF378ADD), defaultStart: 540, defaultEnd: 720),
  _BlockTemplate(id:'eating',  title:'Eating',   emoji:'🍽️',
      color: Color(0xFFFF9560), defaultStart: 780, defaultEnd:1020),
  _BlockTemplate(id:'workout', title:'Workout',  emoji:'🏋️',
      color: Color(0xFFFF6B6B), defaultStart:1080, defaultEnd:1140),
  _BlockTemplate(id:'study',   title:'Study',    emoji:'📚',
      color: Color(0xFF60D4A0), defaultStart: 840, defaultEnd: 960),
];

// ─────────────────────────────────────────────────────────────────────────────
// MUTABLE BLOCK (local state while editing)
// ─────────────────────────────────────────────────────────────────────────────

class _MutableBlock {
  final String id;
  final String title;
  final String emoji;
  final Color  color;
  int startMinute;
  int endMinute;

  _MutableBlock({
    required this.id, required this.title,
    required this.emoji, required this.color,
    required this.startMinute, required this.endMinute,
  });

  double get top    => startMinute / 60 * _kHourH;
  double get height => (endMinute - startMinute) / 60 * _kHourH;

  String get startLabel => _fmtMin(startMinute);
  String get endLabel   => _fmtMin(endMinute);

  static String _fmtMin(int m) {
    final h   = m ~/ 60;
    final min = m % 60;
    final ap  = h < 12 ? 'AM' : 'PM';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:${min.toString().padLeft(2,'0')} $ap';
  }

  // Snap to nearest 15 minutes
  static int snapTo15(int m) => ((m / 15).round() * 15).clamp(0, 1439);

  FixedBlock toFixed() => FixedBlock(
    id: id, title: title, emoji: emoji,
    startMinute: startMinute, endMinute: endMinute,
    colorHex: '#${color.value.toRadixString(16).substring(2).toUpperCase()}',
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class FixedScheduleScreen extends ConsumerStatefulWidget {
  final VoidCallback? onNext;
  const FixedScheduleScreen({super.key, this.onNext});

  @override
  ConsumerState<FixedScheduleScreen> createState() =>
      _FixedScheduleScreenState();
}

class _FixedScheduleScreenState
    extends ConsumerState<FixedScheduleScreen> {
  late final ScrollController _scroll;

  // Active blocks on the timeline
  final List<_MutableBlock> _blocks = [
    _MutableBlock(id:'sleep',   title:'Sleep',   emoji:'🛏️',
        color: const Color(0xFFC084FC), startMinute:   0, endMinute: 390),
    _MutableBlock(id:'classes', title:'Classes', emoji:'🎓',
        color: const Color(0xFF378ADD), startMinute: 540, endMinute: 720),
    _MutableBlock(id:'eating',  title:'Eating',  emoji:'🍽️',
        color: const Color(0xFFFF9560), startMinute: 780, endMinute:1020),
  ];

  // Drag state
  String? _draggingId;
  String? _resizingId;    // "top" or "bottom" handle
  double  _dragStartY  = 0;
  int     _dragStartMin = 0;
  int     _dragEndMin   = 0;

  @override
  void initState() {
    super.initState();
    // Scroll to 6 AM so Sleep block is partially visible
    _scroll = ScrollController(
        initialScrollOffset: _kHourH * 5);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  _MutableBlock? _blockById(String id) =>
      _blocks.firstWhere((b) => b.id == id,
          orElse: () => _blocks.first);

  void _addBlock(_BlockTemplate tpl) {
    if (_blocks.any((b) => b.id == tpl.id)) return;
    setState(() => _blocks.add(_MutableBlock(
      id: tpl.id, title: tpl.title, emoji: tpl.emoji,
      color: tpl.color,
      startMinute: tpl.defaultStart, endMinute: tpl.defaultEnd,
    )));
  }

  void _removeBlock(String id) =>
      setState(() => _blocks.removeWhere((b) => b.id == id));

  void _saveAndContinue() {
    ref.read(routineProvider.notifier)
        .setFixedBlocks(_blocks.map((b) => b.toFixed()).toList());
    widget.onNext?.call();
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            const SizedBox(height: 12),
            _buildTitle(),
            const SizedBox(height: 6),
            _buildAddChips(),
            const SizedBox(height: 10),
            Expanded(child: _buildTimeline()),
            _buildNextButton(),
          ],
        ),
      ),
    );
  }

  // ── Top bar ──────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 36, height: 36,
              decoration: const BoxDecoration(
                  color: _kCard, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 15, color: _kInk),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text('Fixed Schedule',
                  style: TextStyle(fontSize: 15,
                      fontWeight: FontWeight.w700, color: _kInk)),
            ),
          ),
          const Text('STEP 8 OF 8',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: _kSub, letterSpacing: .5)),
        ],
      ),
    );
  }

  // ── Title ────────────────────────────────────────────────────────────────
  Widget _buildTitle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: const TextSpan(
              style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.w900,
                color: _kInk, letterSpacing: -0.5,
              ),
              children: [
                TextSpan(text: 'Set Your '),
                TextSpan(
                  text: 'Fixed Schedule',
                  style: TextStyle(color: Color(0xFF378ADD)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Text('Align your daily routine with your goals.',
              style: TextStyle(fontSize: 13, color: _kSub)),
        ],
      ),
    );
  }

  // ── Add chips (templates not yet on timeline) ────────────────────────────
  Widget _buildAddChips() {
    final existing = _blocks.map((b) => b.id).toSet();
    final available = _templates.where(
        (t) => !existing.contains(t.id)).toList();
    if (available.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: available.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final t = available[i];
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _addBlock(t);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 0),
              decoration: BoxDecoration(
                color: t.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: t.color.withOpacity(0.4), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t.emoji,
                      style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 5),
                  const Icon(Icons.add_rounded, size: 14),
                  const SizedBox(width: 3),
                  Text(t.title,
                      style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: t.color,
                      )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Timeline ─────────────────────────────────────────────────────────────
  Widget _buildTimeline() {
    return SingleChildScrollView(
      controller: _scroll,
      physics: _draggingId != null || _resizingId != null
          ? const NeverScrollableScrollPhysics()
          : const BouncingScrollPhysics(),
      child: SizedBox(
        height: _kTotalH,
        child: Stack(
          children: [
            // Hour lines + labels
            ..._buildHourGrid(),

            // Blocks
            ..._blocks.map((b) => _buildBlock(b)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildHourGrid() {
    return List.generate(24, (h) => Positioned(
      top: h * _kHourH,
      left: 0, right: 0,
      height: _kHourH,
      child: Row(
        children: [
          SizedBox(
            width: _kTimeW,
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(_kHours[h],
                  style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: _kSub,
                  )),
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: _kInk.withOpacity(0.06),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildBlock(_MutableBlock b) {
    final blockColor = b.color;
    final isDragging = _draggingId == b.id;

    return Positioned(
      top:   b.top,
      left:  _kTimeW + 8,
      right: 16,
      height: b.height.clamp(48.0, _kTotalH),
      child: GestureDetector(
        // Drag entire block (move)
        onVerticalDragStart: (d) {
          HapticFeedback.lightImpact();
          setState(() {
            _draggingId   = b.id;
            _dragStartY   = d.globalPosition.dy;
            _dragStartMin = b.startMinute;
            _dragEndMin   = b.endMinute;
          });
        },
        onVerticalDragUpdate: (d) {
          final delta = d.globalPosition.dy - _dragStartY;
          final minDelta =
              _MutableBlock.snapTo15((delta / _kHourH * 60).round());
          final dur = _dragEndMin - _dragStartMin;
          int newStart =
              (_dragStartMin + minDelta).clamp(0, 1440 - dur);
          int newEnd = newStart + dur;
          setState(() {
            b.startMinute = _MutableBlock.snapTo15(newStart);
            b.endMinute   = b.startMinute + dur;
          });
        },
        onVerticalDragEnd: (_) {
          HapticFeedback.mediumImpact();
          setState(() => _draggingId = null);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          decoration: BoxDecoration(
            color: blockColor.withOpacity(isDragging ? 0.35 : 0.18),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: blockColor.withOpacity(0.5), width: 1.5),
            boxShadow: isDragging
                ? [BoxShadow(
                    color: blockColor.withOpacity(0.3),
                    blurRadius: 16, offset: const Offset(0, 6))]
                : [],
          ),
          child: Column(
            children: [
              // Top resize handle
              _ResizeHandle(
                onDragStart: (y) => setState(() {
                  _resizingId  = '${b.id}_top';
                  _dragStartY  = y;
                  _dragStartMin = b.startMinute;
                }),
                onDragUpdate: (dy) {
                  final minDelta = _MutableBlock.snapTo15(
                      (dy / _kHourH * 60).round());
                  final newStart = (_dragStartMin + minDelta)
                      .clamp(0, b.endMinute - 30);
                  setState(() =>
                      b.startMinute = newStart);
                },
                onDragEnd: () =>
                    setState(() => _resizingId = null),
              ),

              // Block content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 4),
                  child: Row(
                    children: [
                      Text(b.emoji,
                          style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(b.title,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: blockColor,
                                )),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _kCard,
                                borderRadius:
                                    BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${b.startLabel}  |  ${b.endLabel}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _kInk.withOpacity(0.7),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Options menu
                      GestureDetector(
                        onTap: () => _showBlockMenu(b),
                        child: Icon(Icons.more_vert_rounded,
                            color: blockColor, size: 20),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom resize handle
              _ResizeHandle(
                onDragStart: (y) => setState(() {
                  _resizingId  = '${b.id}_bot';
                  _dragStartY  = y;
                  _dragEndMin  = b.endMinute;
                }),
                onDragUpdate: (dy) {
                  final minDelta = _MutableBlock.snapTo15(
                      (dy / _kHourH * 60).round());
                  final newEnd = (_dragEndMin + minDelta)
                      .clamp(b.startMinute + 30, 1440);
                  setState(() => b.endMinute = newEnd);
                },
                onDragEnd: () =>
                    setState(() => _resizingId = null),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBlockMenu(_MutableBlock b) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: _kCard,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(b.title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800,
                    color: _kInk)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: Colors.red),
              title: const Text('Remove block'),
              onTap: () {
                Navigator.pop(context);
                _removeBlock(b.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Next button ──────────────────────────────────────────────────────────
  Widget _buildNextButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: GestureDetector(
        onTap: _saveAndContinue,
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFC084FC), Color(0xFF78FDFF)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFC084FC).withOpacity(0.35),
                blurRadius: 20, offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(
            child: Text('Next',
                style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w900,
                  color: _kInk,
                )),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RESIZE HANDLE WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class _ResizeHandle extends StatelessWidget {
  final void Function(double startY) onDragStart;
  final void Function(double deltaY) onDragUpdate;
  final VoidCallback onDragEnd;

  const _ResizeHandle({
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    double? _startY;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (d) {
        _startY = d.globalPosition.dy;
        onDragStart(d.globalPosition.dy);
      },
      onVerticalDragUpdate: (d) {
        if (_startY != null) {
          onDragUpdate(d.globalPosition.dy - _startY!);
        }
      },
      onVerticalDragEnd: (_) {
        HapticFeedback.selectionClick();
        onDragEnd();
      },
      child: Container(
        height: 20,
        alignment: Alignment.center,
        child: Container(
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
