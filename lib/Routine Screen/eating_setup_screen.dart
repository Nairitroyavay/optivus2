import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'routine_provider.dart';

const _kInk   = Color(0xFF0F111A);
const _kSub   = Color(0xFF6B7280);
const _kBg    = Color(0xFFFAF7F0);
const _kCard  = Colors.white;
const _kShad  = Color(0x0D000000);
const _kOrange = Color(0xFFFF9560);

// ─────────────────────────────────────────────────────────────────────────────
// EATING SETUP SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class EatingSetupScreen extends ConsumerStatefulWidget {
  final VoidCallback? onComplete;
  const EatingSetupScreen({super.key, this.onComplete});

  @override
  ConsumerState<EatingSetupScreen> createState() =>
      _EatingSetupScreenState();
}

class _EatingSetupScreenState
    extends ConsumerState<EatingSetupScreen> {
  int _day = 0; // 0=Mon
  static const _days  = ['MON','TUE','WED','THU','FRI','SAT','SUN'];
  static const _dayFull = [
    'Monday','Tuesday','Wednesday','Thursday',
    'Friday','Saturday','Sunday',
  ];

  // Per-day editable meal data (index 0=Mon … 6=Sun)
  final _breakfast = List.generate(7, (_) => TextEditingController());
  final _lunch     = List.generate(7, (_) => TextEditingController());
  final _snack     = List.generate(7, (_) => TextEditingController());
  final _dinner    = List.generate(7, (_) => TextEditingController());

  // Seed Monday defaults
  @override
  void initState() {
    super.initState();
    _breakfast[0].text = 'Oatmeal & Berries';
    _lunch[0].text     = 'Grilled Chicken Salad';
    _snack[0].text     = 'Green Apple & Walnuts';
    _dinner[0].text    = 'Salmon with Asparagus';
  }

  @override
  void dispose() {
    for (final c in [..._breakfast, ..._lunch, ..._snack, ..._dinner]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Copy from previous day ────────────────────────────────────────────

  void _copyFromPrev() {
    if (_day == 0) return;
    setState(() {
      _breakfast[_day].text = _breakfast[_day - 1].text;
      _lunch[_day].text     = _lunch[_day - 1].text;
      _snack[_day].text     = _snack[_day - 1].text;
      _dinner[_day].text    = _dinner[_day - 1].text;
    });
  }

  // ── Save ──────────────────────────────────────────────────────────────

  void _save() {
    final notifier = ref.read(routineProvider.notifier);
    for (int d = 0; d < 7; d++) {
      notifier.setMealPlan(d, DayMealPlan(
        breakfast: _breakfast[d].text.isNotEmpty
            ? MealItem(emoji: '🥣',
                name: _breakfast[d].text, time: '08:00 AM')
            : null,
        lunch: _lunch[d].text.isNotEmpty
            ? MealItem(emoji: '🥗',
                name: _lunch[d].text, time: '01:00 PM')
            : null,
        snack: _snack[d].text.isNotEmpty
            ? MealItem(emoji: '🍎',
                name: _snack[d].text, time: '05:00 PM')
            : null,
        dinner: _dinner[d].text.isNotEmpty
            ? MealItem(emoji: '🍽️',
                name: _dinner[d].text, time: '08:30 PM')
            : null,
      ));
    }
    widget.onComplete?.call();
    Navigator.pop(context);
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            // Nav bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
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
                      child: Text('Eating Routine',
                          style: TextStyle(fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _kInk)),
                    ),
                  ),
                  // Copy from prev
                  if (_day > 0)
                    GestureDetector(
                      onTap: _copyFromPrev,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _kOrange.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('Copy ${_days[_day - 1]}',
                            style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: _kOrange,
                            )),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w900,
                        color: _kInk, letterSpacing: -0.5,
                      ),
                      children: [
                        TextSpan(text: 'Weekly\n'),
                        TextSpan(
                          text: 'Meal Plan',
                          style: TextStyle(color: _kOrange),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Set meals for each day. Same day each week\nwill show this plan automatically.',
                    style: TextStyle(fontSize: 13, color: _kSub, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Day selector
            SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: 7,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final sel = i == _day;
                  final hasMeal = _breakfast[i].text.isNotEmpty ||
                      _lunch[i].text.isNotEmpty;
                  return GestureDetector(
                    onTap: () => setState(() => _day = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 52, height: 48,
                      decoration: BoxDecoration(
                        color: sel ? _kOrange : _kCard,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: sel
                            ? [BoxShadow(
                                color: _kOrange.withOpacity(0.32),
                                blurRadius: 12,
                                offset: const Offset(0, 4))]
                            : [const BoxShadow(
                                color: _kShad, blurRadius: 6,
                                offset: Offset(0, 2))],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_days[i],
                              style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w800,
                                color: sel ? Colors.white : _kSub,
                                letterSpacing: .3,
                              )),
                          if (hasMeal) ...[
                            const SizedBox(height: 3),
                            Container(
                              width: 5, height: 5,
                              decoration: BoxDecoration(
                                color: sel
                                    ? Colors.white.withOpacity(0.7)
                                    : _kOrange,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 6),

            // Day label
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_dayFull[_day]}\'s Meals',
                  style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800,
                    color: _kInk,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Meal slots
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                children: [
                  _MealSlot(
                    emoji: '🥣', label: 'Breakfast',
                    time: '08:00 AM', color: const Color(0xFFFFB830),
                    controller: _breakfast[_day],
                  ),
                  const SizedBox(height: 12),
                  _MealSlot(
                    emoji: '🥗', label: 'Lunch',
                    time: '01:00 PM', color: const Color(0xFF60D4A0),
                    controller: _lunch[_day],
                  ),
                  const SizedBox(height: 12),
                  _MealSlot(
                    emoji: '🍎', label: 'Snack',
                    time: '05:00 PM', color: _kOrange,
                    controller: _snack[_day],
                  ),
                  const SizedBox(height: 12),
                  _MealSlot(
                    emoji: '🍽️', label: 'Dinner',
                    time: '08:30 PM', color: const Color(0xFF9B8FFF),
                    controller: _dinner[_day],
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),

            // Save button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: GestureDetector(
                onTap: _save,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: _kOrange,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: _kOrange.withOpacity(0.35),
                        blurRadius: 16, offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('Save Meal Plan',
                        style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800,
                          color: Colors.white,
                        )),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MEAL SLOT WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class _MealSlot extends StatelessWidget {
  final String emoji, label, time;
  final Color color;
  final TextEditingController controller;

  const _MealSlot({
    required this.emoji, required this.label,
    required this.time, required this.color,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: _kShad, blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(emoji,
                  style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 12),
          // Text fields
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(label,
                        style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800,
                          color: _kInk,
                        )),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(time,
                          style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: color,
                          )),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: controller,
                  style: const TextStyle(
                      fontSize: 13, color: _kInk),
                  decoration: InputDecoration(
                    hintText: 'What\'s for $label?',
                    hintStyle: TextStyle(
                        color: _kSub.withOpacity(0.5),
                        fontSize: 13),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 9),
                    filled: true,
                    fillColor: const Color(0xFFF4F4F4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
