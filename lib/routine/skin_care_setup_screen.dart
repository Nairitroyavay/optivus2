import 'package:flutter/material.dart';

const _kInk  = Color(0xFF0F111A);
const _kSub  = Color(0xFF6B7280);
const _kBg   = Color(0xFFFAF7F0);
const _kCard = Colors.white;
const _kShad = Color(0x0D000000);
const _kBlue = Color(0xFF378ADD);

// ─────────────────────────────────────────────────────────────────────────────
// DATA
// ─────────────────────────────────────────────────────────────────────────────

class _Step {
  final String icon;
  final String name;
  final String time;
  final String tag;
  _Step({required this.icon, required this.name,
      required this.time, required this.tag});
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class SkinCareSetupScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const SkinCareSetupScreen({super.key, required this.onComplete});

  @override
  State<SkinCareSetupScreen> createState() => _SkinCareSetupScreenState();
}

class _SkinCareSetupScreenState extends State<SkinCareSetupScreen> {
  int _day = 0;
  static const _days  = ['MON','TUE','WED','THU','FRI','SAT','SUN'];

  // Starter steps per slot — mutable so user can add/remove
  final _morning   = <_Step>[
    _Step(icon:'🟡', name:'Vitamin C Serum', time:'07:30 AM', tag:'Brightening'),
    _Step(icon:'☀️', name:'Sunscreen',       time:'08:00 AM', tag:'SPF 50+'),
  ];
  final _afternoon = <_Step>[
    _Step(icon:'🫧', name:'Face Wash',       time:'01:00 PM', tag:'Gentle Refresh'),
  ];
  final _night     = <_Step>[
    _Step(icon:'🌙', name:'Night Cream',     time:'10:30 PM', tag:'Deep Repair'),
  ];

  // ── Add step bottom sheet ───────────────────────────────────────────────

  void _addStep(List<_Step> target) {
    final nameCtrl = TextEditingController();
    final tagCtrl  = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add Step',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                      color: _kInk)),
              const SizedBox(height: 16),
              _TF(ctrl: nameCtrl, hint: 'Step name (e.g. Toner)'),
              const SizedBox(height: 10),
              _TF(ctrl: tagCtrl,  hint: 'Tag (e.g. Hydrating)'),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  if (nameCtrl.text.trim().isNotEmpty) {
                    setState(() => target.add(_Step(
                      icon: '🔹',
                      name: nameCtrl.text.trim(),
                      time: '07:00 AM',
                      tag: tagCtrl.text.trim(),
                    )));
                    Navigator.pop(context);
                  }
                },
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: _kBlue,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Center(
                    child: Text('Add',
                        style: TextStyle(fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top nav bar
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
                      child: Text('Routine Setup',
                          style: TextStyle(fontSize: 15,
                              fontWeight: FontWeight.w700, color: _kInk)),
                    ),
                  ),
                  const Text('STEP 5 OF 8',
                      style: TextStyle(fontSize: 11,
                          fontWeight: FontWeight.w700, color: _kSub,
                          letterSpacing: .5)),
                ],
              ),
            ),

            // Scrollable body
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    const Text('Weekly\nRoutine',
                        style: TextStyle(
                          fontSize: 38, fontWeight: FontWeight.w900,
                          color: _kInk, height: 1.1, letterSpacing: -1,
                        )),
                    const SizedBox(height: 10),
                    const Text(
                      "Customize your daily skincare steps.\nYour skin's needs change throughout the week.",
                      style: TextStyle(fontSize: 14, color: _kSub, height: 1.55),
                    ),
                    const SizedBox(height: 22),

                    // Day selector strip
                    SizedBox(
                      height: 58,
                      child: ListView.separated(
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
                                color: sel ? _kBlue : _kCard,
                                shape: BoxShape.circle,
                                border: sel
                                    ? null
                                    : Border.all(
                                        color: _kInk.withValues(alpha: 0.1)),
                                boxShadow: sel
                                    ? [BoxShadow(
                                        color: _kBlue.withValues(alpha: 0.32),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4))]
                                    : [],
                              ),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Text(_days[i],
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: sel
                                            ? Colors.white
                                            : _kSub,
                                        letterSpacing: .3,
                                      )),
                                  // dot if day has steps (only day 0 seeded)
                                  if (_morning.isNotEmpty || _afternoon.isNotEmpty || _night.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Container(
                                      width: 5, height: 5,
                                      decoration: BoxDecoration(
                                        color: sel
                                            ? Colors.white.withValues(alpha: 0.7)
                                            : _kBlue,
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
                    const SizedBox(height: 22),

                    // Morning card
                    _SlotCard(
                      icon: '☀️', iconBg: const Color(0xFFFFF3CD),
                      label: 'Morning', steps: _morning,
                      onAdd: () => _addStep(_morning),
                      onRemove: (i) =>
                          setState(() => _morning.removeAt(i)),
                    ),
                    const SizedBox(height: 14),

                    // Afternoon card
                    _SlotCard(
                      icon: '🌤️', iconBg: const Color(0xFFD0F0FD),
                      label: 'Afternoon', steps: _afternoon,
                      onAdd: () => _addStep(_afternoon),
                      onRemove: (i) =>
                          setState(() => _afternoon.removeAt(i)),
                    ),
                    const SizedBox(height: 14),

                    // Night card
                    _SlotCard(
                      icon: '🌙', iconBg: const Color(0xFFE8E0FF),
                      label: 'Night', steps: _night,
                      onAdd: () => _addStep(_night),
                      onRemove: (i) =>
                          setState(() => _night.removeAt(i)),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),

            // Save & Continue
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: GestureDetector(
                onTap: () {
                  widget.onComplete();
                  Navigator.pop(context);
                },
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: _kBlue,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: _kBlue.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('Save & Continue',
                        style: TextStyle(fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
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
// SLOT CARD  (Morning / Afternoon / Night)
// ─────────────────────────────────────────────────────────────────────────────

class _SlotCard extends StatelessWidget {
  final String icon, label;
  final Color iconBg;
  final List<_Step> steps;
  final VoidCallback onAdd;
  final void Function(int) onRemove;

  const _SlotCard({
    required this.icon, required this.iconBg, required this.label,
    required this.steps, required this.onAdd, required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: _kShad, blurRadius: 12, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(icon,
                      style: const TextStyle(fontSize: 18))),
              ),
              const SizedBox(width: 10),
              Text(label,
                  style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800,
                    color: _kInk,
                  )),
              const Spacer(),
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: _kBlue, shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_rounded,
                      size: 18, color: Colors.white),
                ),
              ),
            ],
          ),
          if (steps.isNotEmpty) const SizedBox(height: 12),

          // Step rows
          ...List.generate(steps.length, (i) {
            final s = steps[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(s.icon,
                          style: const TextStyle(fontSize: 18))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _kInk,
                            )),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: _kBlue.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(s.time,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: _kBlue,
                                  )),
                            ),
                            const SizedBox(width: 5),
                            Text('· ${s.tag}',
                                style: const TextStyle(
                                    fontSize: 11, color: _kSub)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => onRemove(i),
                    child: const Icon(Icons.remove_rounded,
                        size: 20, color: _kSub),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TEXT FIELD HELPER
// ─────────────────────────────────────────────────────────────────────────────

class _TF extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  const _TF({required this.ctrl, required this.hint});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(fontSize: 15, color: _kInk),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            color: _kSub.withValues(alpha: 0.55), fontSize: 15),
        filled: true,
        fillColor: const Color(0xFFF2F2F2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 13),
      ),
    );
  }
}
