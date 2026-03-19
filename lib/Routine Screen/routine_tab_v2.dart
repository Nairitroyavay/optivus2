import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'routine_provider.dart';
import 'routine_settings_sheet.dart';
import 'skin_care_setup_screen.dart';
import 'eating_setup_screen.dart';
import 'fixed_schedule_screen.dart';
import 'routine_fab_layer.dart';
import 'ai_routine_panel.dart';
import 'add_task_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PALETTE
// ─────────────────────────────────────────────────────────────────────────────

const _kInk   = Color(0xFF0F111A);
const _kAmber = Color(0xFFFFB830);
const _kSub   = Color(0xFF6B7280);
const _kBg    = Color(0xFFFAF7F0);
const _kCard  = Colors.white;
const _kShad  = Color(0x0D000000);

// ─────────────────────────────────────────────────────────────────────────────
// FILTER ENUM
// ─────────────────────────────────────────────────────────────────────────────

enum RoutineFilter { all, skinCare, classes, eating }

class _FilterMeta {
  final String label, emoji;
  final Color  color;
  const _FilterMeta(this.label, this.emoji, this.color);
}

const _meta = <RoutineFilter, _FilterMeta>{
  RoutineFilter.all:      _FilterMeta('All',       '🗓️', Color(0xFF0F111A)),
  RoutineFilter.skinCare: _FilterMeta('Skin Care', '🌿', Color(0xFF60D4A0)),
  RoutineFilter.classes:  _FilterMeta('Classes',   '🎓', Color(0xFF378ADD)),
  RoutineFilter.eating:   _FilterMeta('Eating',    '🍽️', Color(0xFFFF9560)),
};

// ─────────────────────────────────────────────────────────────────────────────
// DISPLAY BLOCK  (unified model for rendering — built at runtime from provider)
// ─────────────────────────────────────────────────────────────────────────────

class _DisplayBlock {
  final String time;      // "08:00"
  final String title;
  final String subtitle;
  final Color  accentColor;
  final String emoji;
  final RoutineFilter type;
  final List<String> subtasks;
  final bool isNow;

  const _DisplayBlock({
    required this.time, required this.title,
    required this.subtitle, required this.accentColor,
    required this.emoji, required this.type,
    this.subtasks = const [], this.isNow = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// ROUTINE TAB
// ─────────────────────────────────────────────────────────────────────────────

class RoutineTab extends ConsumerStatefulWidget {
  final RoutineFilter initialFilter;
  const RoutineTab({
    super.key,
    this.initialFilter = RoutineFilter.all,
  });

  @override
  ConsumerState<RoutineTab> createState() => _RoutineTabState();
}

class _RoutineTabState extends ConsumerState<RoutineTab> {
  late RoutineFilter _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
  }

  // ── Build visible blocks from provider state ─────────────────────────────

  List<_DisplayBlock> _buildBlocks(RoutineState s, Map<String, List<CustomTask>> customMap) {
    final today = DateTime.now();
    // weekday: 1=Mon…7=Sun → index 0=Mon…6=Sun
    final dayIdx = (today.weekday - 1).clamp(0, 6);

    final blocks = <_DisplayBlock>[];

    // 1. Fixed schedule blocks (always shown in "All")
    if (_filter == RoutineFilter.all) {
      for (final fb in s.fixedBlocks) {
        blocks.add(_DisplayBlock(
          time: _fmtMinutes(fb.startMinute),
          title: fb.title,
          subtitle: '${fb.startLabel} – ${fb.endLabel}',
          accentColor: _hexColor(fb.colorHex),
          emoji: fb.emoji,
          type: RoutineFilter.all,
        ));
      }
    }

    // 2. Skin care blocks
    if (_filter == RoutineFilter.all ||
        _filter == RoutineFilter.skinCare) {
      final plan = s.skinPlanForDay(dayIdx);
      if (plan.morning.isNotEmpty) {
        blocks.add(_DisplayBlock(
          time: '07:30',
          title: 'Morning Skin Care',
          subtitle: plan.morning.map((s) => s.name).join(' · '),
          accentColor: const Color(0xFF60D4A0),
          emoji: '🌿',
          type: RoutineFilter.skinCare,
        ));
      }
      if (plan.afternoon.isNotEmpty) {
        blocks.add(_DisplayBlock(
          time: '13:00',
          title: 'Afternoon Skin Care',
          subtitle: plan.afternoon.map((s) => s.name).join(' · '),
          accentColor: const Color(0xFF60D4A0),
          emoji: '💧',
          type: RoutineFilter.skinCare,
        ));
      }
      if (plan.night.isNotEmpty) {
        blocks.add(_DisplayBlock(
          time: '22:00',
          title: 'Night Skin Care',
          subtitle: plan.night.map((s) => s.name).join(' · '),
          accentColor: const Color(0xFF9B8FFF),
          emoji: '🌙',
          type: RoutineFilter.skinCare,
        ));
      }
    }

    // 3. Classes
    if (_filter == RoutineFilter.all ||
        _filter == RoutineFilter.classes) {
      final todayClasses = s.classesForDay(today.weekday);
      for (final c in todayClasses) {
        blocks.add(_DisplayBlock(
          time: c.startTime,
          title: c.subject,
          subtitle: '${c.room} · ${c.professor}',
          accentColor: _hexColor(c.colorHex),
          emoji: '🎓',
          type: RoutineFilter.classes,
        ));
      }
    }

    // 4. Meals
    if (_filter == RoutineFilter.all ||
        _filter == RoutineFilter.eating) {
      final meals = s.mealPlanForDay(dayIdx).all;
      for (final m in meals) {
        blocks.add(_DisplayBlock(
          time: _time12to24(m.time),
          title: _mealLabel(m.time),
          subtitle: m.name,
          accentColor: const Color(0xFFFF9560),
          emoji: m.emoji,
          type: RoutineFilter.eating,
        ));
      }
    }

    // 5. Custom tasks
    final todayKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final custom = customMap[todayKey] ?? [];
    for (final t in custom) {
      blocks.add(_DisplayBlock(
        time: t.time,
        title: t.title,
        subtitle: 'Custom task',
        accentColor: t.color,
        emoji: t.emoji,
        type: RoutineFilter.all,
      ));
    }

    // Sort by time
    blocks.sort((a, b) => a.time.compareTo(b.time));

    // Mark the current "now" block
    final nowMin = DateTime.now().hour * 60 + DateTime.now().minute;
    for (int i = 0; i < blocks.length - 1; i++) {
      final start = _parseTime(blocks[i].time);
      final end   = _parseTime(blocks[i + 1].time);
      if (nowMin >= start && nowMin < end) {
        blocks[i] = _DisplayBlock(
          time: blocks[i].time,
          title: blocks[i].title,
          subtitle: blocks[i].subtitle,
          accentColor: blocks[i].accentColor,
          emoji: blocks[i].emoji,
          type: blocks[i].type,
          subtasks: blocks[i].subtasks,
          isNow: true,
        );
        break;
      }
    }

    return blocks;
  }

  // ── Filter tap ────────────────────────────────────────────────────────────

  void _onFilterTap(RoutineFilter f, RoutineState s) {
    if (f == RoutineFilter.skinCare && !s.skinCareSetUp) {
      _openSetup(f);
      return;
    }
    if (f == RoutineFilter.eating && !s.eatingSetUp) {
      _openSetup(f);
      return;
    }
    if (f == RoutineFilter.classes && !s.classesSetUp) {
      _openSetup(f);
      return;
    }
    setState(() => _filter = f);
  }

  void _openSetup(RoutineFilter f) {
    switch (f) {
      case RoutineFilter.skinCare:
        Navigator.push(context, _slide(SkinCareSetupScreen(
          onComplete: () {
            ref.read(routineProvider.notifier).markSkinCareSetUp();
            setState(() => _filter = RoutineFilter.skinCare);
          },
        )));
        break;
      case RoutineFilter.eating:
        Navigator.push(context, _slide(EatingSetupScreen(
          onComplete: () =>
              setState(() => _filter = RoutineFilter.eating),
        )));
        break;
      default:
        break;
    }
  }

  void _openSettings(RoutineState s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RoutineSettingsSheet(
        setupDone: {
          RoutineFilter.skinCare: s.skinCareSetUp,
          RoutineFilter.classes:  s.classesSetUp,
          RoutineFilter.eating:   s.eatingSetUp,
        },
        onSetup: (f) {
          Navigator.pop(context);
          _openSetup(f);
        },
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s         = ref.watch(routineProvider);
    final customMap = ref.watch(customTasksProvider);
    final blocks    = _buildBlocks(s, customMap);
    final m         = _meta[_filter]!;

    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
            // ── Header ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _filter == RoutineFilter.all
                              ? "Today's Flow"
                              : m.label,
                          style: const TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w900,
                            color: _kInk, letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _todayLabel(),
                          style: const TextStyle(
                            fontSize: 13, color: _kSub,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _openSettings(s),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: _kCard, shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(color: _kShad, blurRadius: 12,
                              offset: Offset(0, 4)),
                        ],
                      ),
                      child: const Icon(Icons.settings_outlined,
                          size: 20, color: _kInk),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Filter pills ─────────────────────────────────────────────
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: RoutineFilter.values.map((f) {
                  final fm  = _meta[f]!;
                  final sel = _filter == f;
                  final notSetUp = f != RoutineFilter.all && (
                    (f == RoutineFilter.skinCare && !s.skinCareSetUp) ||
                    (f == RoutineFilter.eating   && !s.eatingSetUp)   ||
                    (f == RoutineFilter.classes  && !s.classesSetUp)
                  );
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => _onFilterTap(f, s),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14),
                        decoration: BoxDecoration(
                          color: sel ? _kInk : _kCard,
                          borderRadius: BorderRadius.circular(20),
                          border: sel
                              ? null
                              : Border.all(
                                  color: _kInk.withOpacity(0.08)),
                          boxShadow: const [
                            BoxShadow(color: _kShad, blurRadius: 8,
                                offset: Offset(0, 2)),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(fm.emoji,
                                style: const TextStyle(fontSize: 13)),
                            const SizedBox(width: 6),
                            Text(fm.label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: sel ? Colors.white : _kInk,
                                )),
                            if (notSetUp) ...[
                              const SizedBox(width: 5),
                              Container(
                                width: 6, height: 6,
                                decoration: BoxDecoration(
                                  color: sel
                                      ? Colors.white.withOpacity(0.7)
                                      : fm.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 4),

            // ── Timeline ─────────────────────────────────────────────────
            Expanded(
              child: blocks.isEmpty
                  ? _EmptyState(
                      filter: _filter,
                      onSetup: () => _openSetup(_filter),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding:
                          const EdgeInsets.fromLTRB(0, 8, 0, 140),
                      itemCount: blocks.length,
                      itemBuilder: (_, i) {
                        final b = blocks[i];
                        final prevHour = i > 0
                            ? blocks[i - 1].time.split(':')[0]
                            : null;
                        return _TimelineRow(
                          block: b,
                          showHourLabel:
                              prevHour != b.time.split(':')[0],
                          isLast: i == blocks.length - 1,
                        );
                      },
                    ),
              ),
            ],
          ),
        ),
        RoutineFabLayer(routineState: s),
      ],
    ),
  );
}
}

// ─────────────────────────────────────────────────────────────────────────────
// TIMELINE ROW
// ─────────────────────────────────────────────────────────────────────────────

class _TimelineRow extends StatefulWidget {
  final _DisplayBlock block;
  final bool showHourLabel;
  final bool isLast;
  const _TimelineRow({
    required this.block,
    required this.showHourLabel,
    required this.isLast,
  });

  @override
  State<_TimelineRow> createState() => _TimelineRowState();
}

class _TimelineRowState extends State<_TimelineRow> {
  final _checked = <int>{};

  @override
  Widget build(BuildContext context) {
    final b = widget.block;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time column
          SizedBox(
            width: 72,
            child: Padding(
              padding: const EdgeInsets.only(left: 20, top: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.showHourLabel)
                    Text(b.time,
                        style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: _kSub,
                        )),
                  if (b.isNow) ...[
                    const SizedBox(height: 5),
                    Row(children: [
                      Container(
                        width: 7, height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF4444),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Text('NOW',
                          style: TextStyle(
                            fontSize: 9, fontWeight: FontWeight.w800,
                            color: Color(0xFFFF4444),
                            letterSpacing: .6,
                          )),
                    ]),
                  ],
                ],
              ),
            ),
          ),

          // Dot + line
          Column(children: [
            const SizedBox(height: 18),
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                color: b.accentColor, shape: BoxShape.circle,
                boxShadow: [BoxShadow(
                  color: b.accentColor.withOpacity(0.45),
                  blurRadius: 6,
                )],
              ),
            ),
            if (!widget.isLast)
              Expanded(child: Container(
                width: 1.5,
                color: _kInk.withOpacity(0.07),
              )),
          ]),

          const SizedBox(width: 10),

          // Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(
                  right: 20, top: 8, bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(18),
                  border: b.isNow
                      ? Border.all(
                          color: b.accentColor.withOpacity(0.3),
                          width: 1.5)
                      : null,
                  boxShadow: const [
                    BoxShadow(color: _kShad, blurRadius: 14,
                        offset: Offset(0, 4)),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 3,
                      height: b.subtasks.isEmpty
                          ? 38
                          : 38 + b.subtasks.length * 30.0,
                      margin: const EdgeInsets.only(right: 10, top: 2),
                      decoration: BoxDecoration(
                        color: b.accentColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: b.accentColor.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Center(
                        child: Text(b.emoji,
                            style: const TextStyle(fontSize: 18))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: _kInk,
                              )),
                          const SizedBox(height: 2),
                          Text(b.subtitle,
                              style: const TextStyle(
                                fontSize: 12, color: _kSub,
                              )),
                          if (b.subtasks.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            ...List.generate(
                              b.subtasks.length,
                              (i) => GestureDetector(
                                onTap: () => setState(() {
                                  _checked.contains(i)
                                      ? _checked.remove(i)
                                      : _checked.add(i);
                                }),
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 7),
                                  child: Row(children: [
                                    AnimatedContainer(
                                      duration: const Duration(
                                          milliseconds: 150),
                                      width: 18, height: 18,
                                      decoration: BoxDecoration(
                                        color: _checked.contains(i)
                                            ? b.accentColor
                                            : Colors.transparent,
                                        border: Border.all(
                                          color: _checked.contains(i)
                                              ? b.accentColor
                                              : _kSub.withOpacity(0.35),
                                          width: 1.5,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                      child: _checked.contains(i)
                                          ? const Icon(
                                              Icons.check_rounded,
                                              size: 11,
                                              color: Colors.white)
                                          : null,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(b.subtasks[i],
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _checked.contains(i)
                                              ? _kSub
                                              : _kInk,
                                          decoration: _checked.contains(i)
                                              ? TextDecoration.lineThrough
                                              : null,
                                        )),
                                  ]),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final RoutineFilter filter;
  final VoidCallback onSetup;
  const _EmptyState({required this.filter, required this.onSetup});

  @override
  Widget build(BuildContext context) {
    final m = _meta[filter]!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(m.emoji,
                style: const TextStyle(fontSize: 52)),
            const SizedBox(height: 16),
            Text('No ${m.label.toLowerCase()} for today',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800,
                  color: _kInk,
                )),
            const SizedBox(height: 8),
            Text(
              'Set up your ${m.label.toLowerCase()} routine\nand it will appear here every day.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: _kSub,
                  height: 1.5),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onSetup,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  color: _kInk,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Text('Set up ${m.label}',
                    style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: Colors.white,
                    )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

Color _hexColor(String hex) {
  try {
    return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
  } catch (_) {
    return const Color(0xFF9B8FFF);
  }
}

String _fmtMinutes(int m) {
  final h   = (m ~/ 60).toString().padLeft(2, '0');
  final min = (m % 60).toString().padLeft(2, '0');
  return '$h:$min';
}

/// "08:00 AM" → "08:00"
String _time12to24(String t) {
  try {
    final parts = t.split(' ');
    final hm    = parts[0].split(':');
    int h       = int.parse(hm[0]);
    final min   = hm[1];
    if (parts[1] == 'PM' && h != 12) h += 12;
    if (parts[1] == 'AM' && h == 12) h = 0;
    return '${h.toString().padLeft(2,'0')}:$min';
  } catch (_) {
    return '00:00';
  }
}

String _mealLabel(String time) {
  final hour = int.tryParse(time.split(':')[0]) ?? 0;
  if (hour < 10) return 'Breakfast';
  if (hour < 14) return 'Lunch';
  if (hour < 17) return 'Snack';
  return 'Dinner';
}

int _parseTime(String t) {
  final p = t.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

String _todayLabel() {
  final now = DateTime.now();
  const months = ['Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${months[now.month - 1]} ${now.day}, ${now.year}';
}

Route _slide(Widget page) => PageRouteBuilder(
  pageBuilder: (_, __, ___) => page,
  transitionsBuilder: (_, anim, __, child) => SlideTransition(
    position: Tween<Offset>(
      begin: const Offset(1, 0), end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: anim, curve: Curves.easeOutCubic)),
    child: child,
  ),
);
