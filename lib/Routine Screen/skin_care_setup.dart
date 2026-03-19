// lib/Routine Screen/skin_care_setup.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'liquid_kit.dart';
import 'routine_provider.dart';

class SkinCareSetup extends ConsumerStatefulWidget {
  final VoidCallback onComplete;
  const SkinCareSetup({super.key, required this.onComplete});
  @override ConsumerState<SkinCareSetup> createState() => _State();
}

class _State extends ConsumerState<SkinCareSetup> {
  int _day = 0;
  static const _days = ['MON','TUE','WED','THU','FRI','SAT','SUN'];

  final _morning   = <SkinStep>[
    const SkinStep(emoji:'🟡', name:'Vitamin C Serum', tag:'Brightening'),
    const SkinStep(emoji:'☀️', name:'SPF 50 Sunscreen', tag:'UV Protection'),
  ];
  final _afternoon = <SkinStep>[
    const SkinStep(emoji:'🫧', name:'Face Wash', tag:'Gentle Cleanser'),
  ];
  final _night     = <SkinStep>[
    const SkinStep(emoji:'🌙', name:'Night Cream', tag:'Deep Repair'),
  ];

  void _addStep(List<SkinStep> target) {
    final nc = TextEditingController(), tc = TextEditingController();
    showLiquidSheet(context: context, child: _AddStepSheet(
      nameCtrl: nc, tagCtrl: tc,
      onAdd: (name, tag) {
        setState(() => target.add(
            SkinStep(emoji:'🔹', name: name, tag: tag)));
      },
    ));
  }

  void _save() {
    final n = ref.read(routineProvider.notifier);
    final plan = DaySkinPlan(
        morning: List.from(_morning),
        afternoon: List.from(_afternoon),
        night: List.from(_night));
    for (int i = 0; i < 7; i++) { n.setSkinCarePlan(i, plan); }
    widget.onComplete();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: kBg,
    body: SafeArea(child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16,12,20,0), child: Row(children: [
        LiquidIconBtn(icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.pop(context)),
        const Expanded(child: Center(child: Text('Routine Setup',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kInk)))),
        const Text('STEP 5 OF 8',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: kSub, letterSpacing: .5)),
      ])),
      Expanded(child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24,20,24,20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          RichText(text: const TextSpan(
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900,
                color: kInk, height: 1.1, letterSpacing: -1),
            children: [
              TextSpan(text: 'Weekly\n'),
              TextSpan(text: 'Routine',
                  style: TextStyle(color: kMint)),
            ],
          )),
          const SizedBox(height: 10),
          Text("Customize daily skincare steps.\nYour skin's needs change throughout the week.",
              style: TextStyle(fontSize: 14, color: kSub, height: 1.5)),
          const SizedBox(height: 22),

          // Day selector
          SizedBox(height: 58, child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: 7,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final sel = i == _day;
              return GestureDetector(
                onTap: () => setState(() => _day = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 54, height: 54,
                  decoration: BoxDecoration(
                    color: sel ? kBlue : Colors.white.withOpacity(0.72),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: sel ? kBlue.withOpacity(0.6)
                            : Colors.white.withOpacity(0.9), width: 1.5),
                    boxShadow: sel ? [BoxShadow(color: kBlue.withOpacity(0.32),
                        blurRadius: 12, offset: const Offset(0,4))] : [],
                  ),
                  child: Center(child: Text(_days[i], style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: sel ? Colors.white : kSub, letterSpacing: .3,
                  ))),
                ),
              );
            },
          )),
          const SizedBox(height: 22),

          _SlotCard(emoji:'☀️', iconBg: const Color(0xFFFFF3CD),
              label:'Morning', steps: _morning,
              onAdd: () => _addStep(_morning),
              onRemove: (i) => setState(() => _morning.removeAt(i))),
          const SizedBox(height: 14),
          _SlotCard(emoji:'🌤️', iconBg: const Color(0xFFD0F0FD),
              label:'Afternoon', steps: _afternoon,
              onAdd: () => _addStep(_afternoon),
              onRemove: (i) => setState(() => _afternoon.removeAt(i))),
          const SizedBox(height: 14),
          _SlotCard(emoji:'🌙', iconBg: const Color(0xFFE8E0FF),
              label:'Night', steps: _night,
              onAdd: () => _addStep(_night),
              onRemove: (i) => setState(() => _night.removeAt(i))),
          const SizedBox(height: 80),
        ]),
      )),
      Padding(padding: const EdgeInsets.fromLTRB(24,0,24,24),
          child: LiquidButton(label:'Save & Continue',
              color: kBlue, onTap: _save)),
    ])),
  );
}

class _SlotCard extends StatelessWidget {
  final String emoji, label;
  final Color iconBg;
  final List<SkinStep> steps;
  final VoidCallback onAdd;
  final void Function(int) onRemove;
  const _SlotCard({required this.emoji, required this.iconBg,
      required this.label, required this.steps,
      required this.onAdd, required this.onRemove});

  @override
  Widget build(BuildContext context) => LiquidCard.solid(
    padding: const EdgeInsets.all(16), radius: 20,
    child: Column(children: [
      Row(children: [
        Container(width: 36, height: 36,
            decoration: BoxDecoration(color: iconBg,
                borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text(emoji,
                style: const TextStyle(fontSize: 18)))),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 15,
            fontWeight: FontWeight.w800, color: kInk)),
        const Spacer(),
        GestureDetector(onTap: onAdd, child: Container(
          width: 28, height: 28,
          decoration: BoxDecoration(color: kBlue, shape: BoxShape.circle),
          child: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
        )),
      ]),
      if (steps.isNotEmpty) const SizedBox(height: 12),
      ...List.generate(steps.length, (i) {
        final s = steps[i];
        return Padding(padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Container(width: 36, height: 36,
                decoration: BoxDecoration(color: iconBg,
                    borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text(s.emoji,
                    style: const TextStyle(fontSize: 18)))),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name, style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: kInk)),
                const SizedBox(height: 3),
                Container(padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: kBlue.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(s.tag, style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700, color: kBlue)),
                ),
              ],
            )),
            GestureDetector(onTap: () => onRemove(i),
                child: Icon(Icons.remove_rounded, size: 20, color: kSub)),
          ]),
        );
      }),
    ]),
  );
}

class _AddStepSheet extends StatelessWidget {
  final TextEditingController nameCtrl, tagCtrl;
  final void Function(String name, String tag) onAdd;
  const _AddStepSheet({required this.nameCtrl, required this.tagCtrl,
      required this.onAdd});

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    child: Padding(padding: const EdgeInsets.fromLTRB(24,0,24,24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const LiquidSheetHandle(),
        const SizedBox(height: 16),
        const Text('Add Step', style: TextStyle(fontSize: 20,
            fontWeight: FontWeight.w800, color: kInk)),
        const SizedBox(height: 16),
        LiquidTextField(hint:'Step name (e.g. Toner)', controller: nameCtrl),
        const SizedBox(height: 10),
        LiquidTextField(hint:'Tag (e.g. Hydrating)', controller: tagCtrl),
        const SizedBox(height: 20),
        LiquidButton(label: 'Add', color: kBlue, onTap: () {
          if (nameCtrl.text.trim().isNotEmpty) {
            onAdd(nameCtrl.text.trim(), tagCtrl.text.trim());
            Navigator.pop(context);
          }
        }),
      ]),
    ),
  );
}
