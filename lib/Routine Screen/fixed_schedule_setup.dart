// lib/Routine Screen/fixed_schedule_setup.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'liquid_kit.dart';
import 'routine_provider.dart';

const double _kHourH = 72.0;
const double _kTotal = _kHourH * 24;
const double _kTimeW = 72.0;

const _hours = [
  '12 AM','1 AM','2 AM','3 AM','4 AM','5 AM','6 AM','7 AM',
  '8 AM','9 AM','10 AM','11 AM','12 PM','1 PM','2 PM','3 PM',
  '4 PM','5 PM','6 PM','7 PM','8 PM','9 PM','10 PM','11 PM',
];

class _MBlock {
  final String id, title, emoji;
  final Color color;
  int startMin, endMin;

  _MBlock({required this.id, required this.title, required this.emoji,
      required this.color, required this.startMin, required this.endMin});

  double get top    => startMin / 60 * _kHourH;
  double get height => (endMin - startMin) / 60 * _kHourH;
  String get startLabel => _fmt(startMin);
  String get endLabel   => _fmt(endMin);

  static String _fmt(int m) {
    final h = m ~/ 60; final min = m % 60;
    final ap = h < 12 ? 'AM' : 'PM';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:${min.toString().padLeft(2,'0')} $ap';
  }

  static int snap15(int m) => ((m / 15).round() * 15).clamp(0, 1439);

  FixedBlock toFixed() => FixedBlock(
    id: id, title: title, emoji: emoji,
    startMinute: startMin, endMinute: endMin,
    colorHex: '#${color.value.toRadixString(16).substring(2).toUpperCase()}',
  );
}

class FixedScheduleSetup extends ConsumerStatefulWidget {
  final VoidCallback? onNext;
  const FixedScheduleSetup({super.key, this.onNext});
  @override ConsumerState<FixedScheduleSetup> createState() => _State();
}

class _State extends ConsumerState<FixedScheduleSetup> {
  late final ScrollController _scroll;
  final _blocks = <_MBlock>[
    _MBlock(id:'sleep',   title:'Sleep',   emoji:'🛏️',
        color: kPurple, startMin:   0, endMin: 390),
    _MBlock(id:'classes', title:'Classes', emoji:'🎓',
        color: kBlue,   startMin: 540, endMin: 720),
    _MBlock(id:'eating',  title:'Eating',  emoji:'🍽️',
        color: kRose,   startMin: 780, endMin:1020),
  ];

  String? _dragging;
  double _dragStartY = 0;
  int _dragStartMin = 0, _dragEndMin = 0;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController(initialScrollOffset: _kHourH * 5);
  }
  @override void dispose() { _scroll.dispose(); super.dispose(); }

  _MBlock? _block(String id) {
    try { return _blocks.firstWhere((b) => b.id == id); }
    catch (_) { return null; }
  }

  void _save() {
    ref.read(routineProvider.notifier)
        .setFixedBlocks(_blocks.map((b) => b.toFixed()).toList());
    widget.onNext?.call();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: kBg,
    body: SafeArea(child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16,12,20,0), child: Row(children: [
        LiquidIconBtn(icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.maybePop(context)),
        const Expanded(child: Center(child: Text('Fixed Schedule',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kInk)))),
        const Text('STEP 8 OF 8',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: kSub, letterSpacing: .5)),
      ])),
      Padding(padding: const EdgeInsets.fromLTRB(24,16,24,0),
        child: RichText(text: const TextSpan(
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: kInk, letterSpacing:-0.5),
          children: [
            TextSpan(text: 'Set Your '),
            TextSpan(text: 'Fixed Schedule',
                style: TextStyle(color: kBlue)),
          ],
        )),
      ),
      const Padding(padding: EdgeInsets.fromLTRB(24,4,24,12),
        child: Align(alignment: Alignment.centerLeft,
          child: Text('Align your daily routine with your goals.',
              style: TextStyle(fontSize: 13, color: kSub)))),

      Expanded(child: SingleChildScrollView(
        controller: _scroll,
        physics: _dragging != null
            ? const NeverScrollableScrollPhysics()
            : const BouncingScrollPhysics(),
        child: SizedBox(height: _kTotal, child: Stack(children: [
          // Hour grid
          ...List.generate(24, (h) => Positioned(
            top: h * _kHourH, left: 0, right: 0, height: _kHourH,
            child: Row(children: [
              SizedBox(width: _kTimeW, child: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Text(_hours[h], style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: kSub)),
              )),
              Expanded(child: Container(decoration: BoxDecoration(
                border: Border(top: BorderSide(
                    color: kInk.withOpacity(0.06), width: 1))))),
            ]),
          )),
          // Blocks
          ..._blocks.map((b) => _buildBlock(b)),
        ])),
      )),

      Padding(padding: const EdgeInsets.fromLTRB(24,8,24,24),
        child: LiquidButton(
          label: 'Next',
          color: kAmber,
          leading: const Icon(Icons.arrow_forward_rounded,
              color: Colors.white, size: 20),
          onTap: _save,
        )),
    ])),
  );

  Widget _buildBlock(_MBlock b) {
    final isDragging = _dragging == b.id;
    return Positioned(
      top: b.top, left: _kTimeW + 8, right: 16,
      height: b.height.clamp(48.0, _kTotal),
      child: GestureDetector(
        onVerticalDragStart: (d) {
          HapticFeedback.lightImpact();
          setState(() {
            _dragging    = b.id;
            _dragStartY  = d.globalPosition.dy;
            _dragStartMin = b.startMin;
            _dragEndMin  = b.endMin;
          });
        },
        onVerticalDragUpdate: (d) {
          final delta = d.globalPosition.dy - _dragStartY;
          final dur   = _dragEndMin - _dragStartMin;
          final newS  = _MBlock.snap15(
              (_dragStartMin + (delta / _kHourH * 60).round()).clamp(0, 1440 - dur));
          setState(() { b.startMin = newS; b.endMin = newS + dur; });
        },
        onVerticalDragEnd: (_) {
          HapticFeedback.mediumImpact();
          setState(() => _dragging = null);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          decoration: BoxDecoration(
            color: b.color.withOpacity(isDragging ? 0.30 : 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: b.color.withOpacity(0.5), width: 1.5),
            boxShadow: isDragging ? [BoxShadow(
                color: b.color.withOpacity(0.3),
                blurRadius: 16, offset: const Offset(0,6))] : [],
          ),
          child: Column(children: [
            // Top handle
            _Handle(onStart: (y) => setState(() {
              _dragging = '${b.id}_t';
              _dragStartY = y; _dragStartMin = b.startMin;
            }), onUpdate: (dy) {
              final newS = _MBlock.snap15(
                  (_dragStartMin + (dy / _kHourH * 60).round()).clamp(0, b.endMin - 30));
              setState(() => b.startMin = newS);
            }, onEnd: () => setState(() => _dragging = null)),

            // Content
            Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Row(children: [
                Text(b.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.title, style: TextStyle(fontSize: 15,
                        fontWeight: FontWeight.w900, color: b.color)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white,
                          borderRadius: BorderRadius.circular(20)),
                      child: Text('${b.startLabel}  |  ${b.endLabel}',
                          style: TextStyle(fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: kInk.withOpacity(0.7))),
                    ),
                  ],
                )),
              ]),
            )),

            // Bottom handle
            _Handle(onStart: (y) => setState(() {
              _dragging = '${b.id}_b';
              _dragStartY = y; _dragEndMin = b.endMin;
            }), onUpdate: (dy) {
              final newE = _MBlock.snap15(
                  (_dragEndMin + (dy / _kHourH * 60).round()).clamp(b.startMin + 30, 1440));
              setState(() => b.endMin = newE);
            }, onEnd: () => setState(() => _dragging = null)),
          ]),
        ),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  final void Function(double) onStart;
  final void Function(double) onUpdate;
  final VoidCallback onEnd;
  const _Handle({required this.onStart, required this.onUpdate, required this.onEnd});

  @override
  Widget build(BuildContext context) {
    double? sy;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (d) { sy = d.globalPosition.dy; onStart(d.globalPosition.dy); },
      onVerticalDragUpdate: (d) { if (sy != null) onUpdate(d.globalPosition.dy - sy!); },
      onVerticalDragEnd: (_) { HapticFeedback.selectionClick(); onEnd(); },
      child: Container(height: 20, alignment: Alignment.center,
        child: Container(width: 36, height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(2)))),
    );
  }
}
