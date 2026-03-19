// lib/Routine Screen/eating_setup.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'liquid_kit.dart';
import 'routine_provider.dart';

class EatingSetup extends ConsumerStatefulWidget {
  final VoidCallback? onComplete;
  const EatingSetup({super.key, this.onComplete});
  @override ConsumerState<EatingSetup> createState() => _State();
}

class _State extends ConsumerState<EatingSetup> {
  int _day = 0;
  static const _days     = ['MON','TUE','WED','THU','FRI','SAT','SUN'];
  static const _daysFull = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];

  final _bf  = List.generate(7, (_) => TextEditingController());
  final _lu  = List.generate(7, (_) => TextEditingController());
  final _sn  = List.generate(7, (_) => TextEditingController());
  final _di  = List.generate(7, (_) => TextEditingController());

  @override
  void initState() {
    super.initState();
    _bf[0].text = 'Oatmeal & Berries';
    _lu[0].text = 'Grilled Chicken Salad';
    _sn[0].text = 'Green Apple & Walnuts';
    _di[0].text = 'Salmon with Asparagus';
  }

  @override
  void dispose() {
    for (final c in [..._bf,..._lu,..._sn,..._di]) c.dispose();
    super.dispose();
  }

  void _copyPrev() {
    if (_day == 0) return;
    setState(() {
      _bf[_day].text = _bf[_day-1].text;
      _lu[_day].text = _lu[_day-1].text;
      _sn[_day].text = _sn[_day-1].text;
      _di[_day].text = _di[_day-1].text;
    });
  }

  void _save() {
    final n = ref.read(routineProvider.notifier);
    for (int d = 0; d < 7; d++) {
      n.setMealPlan(d, DayMealPlan(
        breakfast: _bf[d].text.isNotEmpty ? MealItem(emoji:'🥣', name:_bf[d].text, time:'08:00') : null,
        lunch:     _lu[d].text.isNotEmpty ? MealItem(emoji:'🥗', name:_lu[d].text, time:'13:00') : null,
        snack:     _sn[d].text.isNotEmpty ? MealItem(emoji:'🍎', name:_sn[d].text, time:'17:00') : null,
        dinner:    _di[d].text.isNotEmpty ? MealItem(emoji:'🍽️', name:_di[d].text, time:'20:30') : null,
      ));
    }
    widget.onComplete?.call();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: kBg,
    body: SafeArea(child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16,12,20,0), child: Row(children: [
        LiquidIconBtn(icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.pop(context)),
        const Expanded(child: Center(child: Text('Eating Routine',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kInk)))),
        if (_day > 0)
          GestureDetector(onTap: _copyPrev, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: kRose.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10)),
            child: Text('Copy ${_days[_day-1]}',
                style: const TextStyle(fontSize: 11,
                    fontWeight: FontWeight.w700, color: kRose)),
          )),
      ])),
      const SizedBox(height: 16),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          RichText(text: const TextSpan(
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
                color: kInk, letterSpacing: -0.5),
            children: [
              TextSpan(text: 'Weekly\n'),
              TextSpan(text: 'Meal Plan',
                  style: TextStyle(color: kRose)),
            ],
          )),
          const SizedBox(height: 6),
          Text('Same day each week shows this plan automatically.',
              style: TextStyle(fontSize: 13, color: kSub, height: 1.5)),
        ]),
      ),
      const SizedBox(height: 16),

      // Day selector
      SizedBox(height: 50, child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: 7,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final sel = i == _day;
          final hasMeal = _bf[i].text.isNotEmpty || _lu[i].text.isNotEmpty;
          return GestureDetector(
            onTap: () => setState(() => _day = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 52, height: 46,
              decoration: BoxDecoration(
                color: sel ? kRose : Colors.white.withOpacity(0.72),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: sel ? kRose.withOpacity(0.6)
                        : Colors.white.withOpacity(0.9), width: 1.5),
                boxShadow: sel ? [BoxShadow(color: kRose.withOpacity(0.32),
                    blurRadius: 12, offset: const Offset(0,4))] : [],
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(_days[i], style: TextStyle(fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: sel ? Colors.white : kSub, letterSpacing: .3)),
                if (hasMeal) ...[
                  const SizedBox(height: 3),
                  Container(width: 5, height: 5, decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: sel ? Colors.white.withOpacity(0.7) : kRose,
                  )),
                ],
              ]),
            ),
          );
        },
      )),
      const SizedBox(height: 12),

      Padding(padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Align(alignment: Alignment.centerLeft,
          child: Text("${_daysFull[_day]}'s Meals",
              style: const TextStyle(fontSize: 16,
                  fontWeight: FontWeight.w800, color: kInk)))),
      const SizedBox(height: 10),

      Expanded(child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24,0,24,20),
        children: [
          _MealSlot(emoji:'🥣', label:'Breakfast', time:'08:00 AM',
              color: kAmber, ctrl: _bf[_day]),
          const SizedBox(height: 12),
          _MealSlot(emoji:'🥗', label:'Lunch', time:'01:00 PM',
              color: kMint, ctrl: _lu[_day]),
          const SizedBox(height: 12),
          _MealSlot(emoji:'🍎', label:'Snack', time:'05:00 PM',
              color: kRose, ctrl: _sn[_day]),
          const SizedBox(height: 12),
          _MealSlot(emoji:'🍽️', label:'Dinner', time:'08:30 PM',
              color: kPurple, ctrl: _di[_day]),
          const SizedBox(height: 80),
        ],
      )),
      Padding(padding: const EdgeInsets.fromLTRB(24,0,24,24),
          child: LiquidButton(label:'Save Meal Plan', color: kRose, onTap: _save)),
    ])),
  );
}

class _MealSlot extends StatelessWidget {
  final String emoji, label, time;
  final Color color;
  final TextEditingController ctrl;
  const _MealSlot({required this.emoji, required this.label,
      required this.time, required this.color, required this.ctrl});

  @override
  Widget build(BuildContext context) => LiquidCard.solid(
    padding: const EdgeInsets.all(14), radius: 18,
    child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Container(width: 44, height: 44,
          decoration: BoxDecoration(color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12)),
          child: Center(child: Text(emoji,
              style: const TextStyle(fontSize: 22)))),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(label, style: const TextStyle(fontSize: 13,
                fontWeight: FontWeight.w800, color: kInk)),
            const SizedBox(width: 8),
            Container(padding: const EdgeInsets.symmetric(
                horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(6)),
              child: Text(time, style: TextStyle(fontSize: 10,
                  fontWeight: FontWeight.w700, color: color)),
            ),
          ]),
          const SizedBox(height: 6),
          LiquidTextField(hint:"What's for $label?", controller: ctrl),
        ],
      )),
    ]),
  );
}
