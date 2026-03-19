// lib/Routine Screen/routine_tab_impl.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'liquid_kit.dart';
import 'routine_provider.dart';
import 'skin_care_setup.dart';
import 'eating_setup.dart';
import 'fixed_schedule_setup.dart';
import 'add_task_sheet.dart';
import 'ai_routine_panel.dart';
import 'routine_settings_sheet.dart';
import 'routine_tab_v2.dart' show RoutineFilter;

enum RoutineFilter2 { all, skinCare, classes, eating }

class _FM {
  final String label, emoji; final Color color;
  const _FM(this.label, this.emoji, this.color);
}

const _filterMeta = <RoutineFilter, _FM>{
  RoutineFilter.all:      _FM('All',       '🗓️', kInk),
  RoutineFilter.skinCare: _FM('Skin Care', '🌿', kMint),
  RoutineFilter.classes:  _FM('Classes',   '🎓', kBlue),
  RoutineFilter.eating:   _FM('Eating',    '🍽️', kRose),
};

class DisplayBlock {
  final String time, title, subtitle, emoji;
  final Color accentColor;
  final RoutineFilter type;
  final List<String> subtasks;
  final bool isNow;
  const DisplayBlock({
    required this.time, required this.title, required this.subtitle,
    required this.accentColor, required this.emoji, required this.type,
    this.subtasks = const [], this.isNow = false,
  });
}

class RoutineTab extends ConsumerStatefulWidget {
  final RoutineFilter initialFilter;
  const RoutineTab({super.key, this.initialFilter = RoutineFilter.all});
  @override ConsumerState<RoutineTab> createState() => _RoutineTabState();
}

class _RoutineTabState extends ConsumerState<RoutineTab> {
  late RoutineFilter _filter;
  bool _aiOpen = false;

  String get _todayKey {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2,'0')}-${n.day.toString().padLeft(2,'0')}';
  }

  @override void initState() { super.initState(); _filter = widget.initialFilter; }

  List<DisplayBlock> _buildBlocks(RoutineState s) {
    final today  = DateTime.now();
    final dayIdx = (today.weekday - 1).clamp(0, 6);
    final blocks = <DisplayBlock>[];

    if (_filter == RoutineFilter.all) {
      for (final fb in s.fixedBlocks) {
        blocks.add(DisplayBlock(time: _fmtMin(fb.startMinute), title: fb.title,
            subtitle: '${fb.startLabel} – ${fb.endLabel}',
            accentColor: _hexColor(fb.colorHex), emoji: fb.emoji, type: RoutineFilter.all));
      }
    }

    if (_filter == RoutineFilter.all || _filter == RoutineFilter.skinCare) {
      final p = s.skinPlanForDay(dayIdx);
      if (p.morning.isNotEmpty)   blocks.add(DisplayBlock(time:'07:30', title:'Morning Skin Care',
          subtitle: p.morning.map((x)=>x.name).join(' · '), accentColor:kMint, emoji:'🌿', type:RoutineFilter.skinCare));
      if (p.afternoon.isNotEmpty) blocks.add(DisplayBlock(time:'13:00', title:'Afternoon Skin Care',
          subtitle: p.afternoon.map((x)=>x.name).join(' · '), accentColor:kMint, emoji:'💧', type:RoutineFilter.skinCare));
      if (p.night.isNotEmpty)     blocks.add(DisplayBlock(time:'22:00', title:'Night Skin Care',
          subtitle: p.night.map((x)=>x.name).join(' · '), accentColor:kPurple, emoji:'🌙', type:RoutineFilter.skinCare));
    }

    if (_filter == RoutineFilter.all || _filter == RoutineFilter.classes) {
      for (final c in s.classesForDay(today.weekday)) {
        blocks.add(DisplayBlock(time:c.startTime, title:c.subject,
            subtitle:'${c.room} · ${c.professor}',
            accentColor:_hexColor(c.colorHex), emoji:'🎓', type:RoutineFilter.classes));
      }
    }

    if (_filter == RoutineFilter.all || _filter == RoutineFilter.eating) {
      for (final m in s.mealPlanForDay(dayIdx).all) {
        blocks.add(DisplayBlock(time:m.time, title:_mealLabel(m.time),
            subtitle:m.name, accentColor:kRose, emoji:m.emoji, type:RoutineFilter.eating));
      }
    }

    blocks.sort((a,b) => a.time.compareTo(b.time));

    final nowMin = today.hour * 60 + today.minute;
    for (int i = 0; i < blocks.length - 1; i++) {
      if (nowMin >= _parseMin(blocks[i].time) && nowMin < _parseMin(blocks[i+1].time)) {
        final b = blocks[i];
        blocks[i] = DisplayBlock(time:b.time, title:b.title, subtitle:b.subtitle,
            accentColor:b.accentColor, emoji:b.emoji, type:b.type,
            subtasks:b.subtasks, isNow:true);
        break;
      }
    }
    return blocks;
  }

  void _onFilter(RoutineFilter f, RoutineState s) {
    if (f == RoutineFilter.skinCare && !s.skinCareSetUp) { _doSetup(f); return; }
    if (f == RoutineFilter.eating   && !s.eatingSetUp)   { _doSetup(f); return; }
    if (f == RoutineFilter.classes  && !s.classesSetUp)  { _doSetup(f); return; }
    setState(() => _filter = f);
  }

  void _doSetup(RoutineFilter f) {
    if (f == RoutineFilter.skinCare) {
      Navigator.push(context, slideRoute(SkinCareSetup(onComplete: () {
        ref.read(routineProvider.notifier).markSkinCareSetUp();
        setState(() => _filter = RoutineFilter.skinCare);
      })));
    } else if (f == RoutineFilter.eating) {
      Navigator.push(context, slideRoute(EatingSetup(
          onComplete: () => setState(() => _filter = RoutineFilter.eating))));
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
        onSetup: (f) { Navigator.pop(context); _doSetup(f); },
      ),
    );
  }

  void _openAddTask() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTaskSheet(
        onAdd: (t) {
          final key = '${t.date.year}-${t.date.month.toString().padLeft(2,'0')}-${t.date.day.toString().padLeft(2,'0')}';
          final map = Map<String, List<CustomTask>>.from(ref.read(customTasksProvider));
          map[key] = [...(map[key] ?? []), t];
          ref.read(customTasksProvider.notifier).state = map;
        },
      ),
    );
  }

  void _toggleAi() {
    final isPremium = ref.read(isPremiumProvider);
    if (!isPremium) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => PremiumPaywallSheet(onUnlock: () {
          Navigator.pop(context);
          ref.read(isPremiumProvider.notifier).state = true;
          Future.delayed(const Duration(milliseconds: 300),
              () => setState(() => _aiOpen = true));
        }));
      return;
    }
    setState(() => _aiOpen = !_aiOpen);
  }

  @override
  Widget build(BuildContext context) {
    final s      = ref.watch(routineProvider);
    final blocks = _buildBlocks(s);
    final fm     = _filterMeta[_filter]!;

    return Scaffold(
      backgroundColor: kBg,
      body: Stack(children: [
        SafeArea(bottom: false, child: Column(children: [
          // Header
          Padding(padding: const EdgeInsets.fromLTRB(24,16,24,0), child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_filter == RoutineFilter.all ? "Today's Flow" : fm.label,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900,
                      color: kInk, letterSpacing: -0.5)),
              const SizedBox(height: 2),
              Text(_todayLabel(), style: TextStyle(fontSize: 13, color: kSub)),
            ])),
            LiquidIconBtn(icon: Icons.settings_outlined,
                onTap: () => _openSettings(s)),
          ])),
          const SizedBox(height: 14),

          // Filter chips
          SizedBox(height: 40, child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: RoutineFilter.values.map((f) {
              final m = _filterMeta[f]!;
              final notSetUp = f != RoutineFilter.all && (
                (f == RoutineFilter.skinCare && !s.skinCareSetUp) ||
                (f == RoutineFilter.eating   && !s.eatingSetUp) ||
                (f == RoutineFilter.classes  && !s.classesSetUp));
              return Padding(padding: const EdgeInsets.only(right: 8),
                child: LiquidChip(label: m.label, emoji: m.emoji,
                    selected: _filter == f, accentColor: m.color,
                    dot: notSetUp, onTap: () => _onFilter(f, s)));
            }).toList(),
          )),
          const SizedBox(height: 4),

          // Timeline
          Expanded(child: blocks.isEmpty
              ? _EmptyState(filter: _filter, onSetup: () => _doSetup(_filter))
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 160),
                  itemCount: blocks.length,
                  itemBuilder: (_, i) => _TimelineRow(
                    block: blocks[i],
                    showHourLabel: i == 0 ||
                        blocks[i].time.split(':')[0] != blocks[i-1].time.split(':')[0],
                    isLast: i == blocks.length - 1,
                  ),
                )),
        ])),

        // AI dim overlay
        if (_aiOpen) Positioned.fill(bottom: 340, child: GestureDetector(
          onTap: () => setState(() => _aiOpen = false),
          child: Container(color: Colors.black.withOpacity(0.18)))),

        // AI Panel
        if (_aiOpen) Positioned(left:0, right:0, bottom:0, child: AiRoutinePanel(
          routineState: s,
          todayTasks: (ref.read(customTasksProvider)[_todayKey] ?? []),
          onAddTask: (t) {
            final map = Map<String, List<CustomTask>>.from(ref.read(customTasksProvider));
            map[_todayKey] = [...(map[_todayKey] ?? []), t];
            ref.read(customTasksProvider.notifier).state = map;
          },
          onRemoveTask: (id) {
            final map = Map<String, List<CustomTask>>.from(ref.read(customTasksProvider));
            map[_todayKey] = (map[_todayKey] ?? []).where((t) => t.id != id).toList();
            ref.read(customTasksProvider.notifier).state = map;
          },
        )),

        // FABs
        Positioned(
          right: 20,
          bottom: _aiOpen ? 380 : 100,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                LiquidFab(icon: Icons.auto_awesome_rounded, color: kPurple,
                    active: _aiOpen, label: ref.watch(isPremiumProvider) ? 'AI Coach' : 'AI ✶ Premium',
                    onTap: _toggleAi),
                const SizedBox(height: 12),
                LiquidFab(icon: Icons.add_rounded, color: kAmber,
                    label: 'Add Task', onTap: _openAddTask),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

class _TimelineRow extends StatefulWidget {
  final DisplayBlock block;
  final bool showHourLabel, isLast;
  const _TimelineRow({required this.block, required this.showHourLabel, required this.isLast});
  @override State<_TimelineRow> createState() => _TRState();
}

class _TRState extends State<_TimelineRow> {
  final _checked = <int>{};
  @override
  Widget build(BuildContext context) {
    final b = widget.block;
    return IntrinsicHeight(child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 74, child: Padding(
          padding: const EdgeInsets.only(left: 20, top: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (widget.showHourLabel)
              Text(b.time, style: TextStyle(fontSize: 12,
                  fontWeight: FontWeight.w700, color: kSub)),
            if (b.isNow) ...[
              const SizedBox(height: 4),
              Row(children: [
                Container(width: 7, height: 7, decoration: const BoxDecoration(
                    color: Color(0xFFFF4444), shape: BoxShape.circle)),
                const SizedBox(width: 3),
                const Text('NOW', style: TextStyle(fontSize: 9,
                    fontWeight: FontWeight.w800, color: Color(0xFFFF4444), letterSpacing:.6)),
              ]),
            ],
          ]),
        )),
        Column(children: [
          const SizedBox(height: 18),
          Container(width: 10, height: 10, decoration: BoxDecoration(
            color: b.accentColor, shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: b.accentColor.withOpacity(0.45), blurRadius: 6)])),
          if (!widget.isLast) Expanded(child: Container(
              width: 1.5, color: kInk.withOpacity(0.07))),
        ]),
        const SizedBox(width: 10),
        Expanded(child: Padding(
          padding: const EdgeInsets.only(right: 20, top: 8, bottom: 8),
          child: LiquidCard.solid(padding: const EdgeInsets.all(14), radius: 18,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 3,
                  height: b.subtasks.isEmpty ? 38 : 38 + b.subtasks.length * 30.0,
                  margin: const EdgeInsets.only(right: 10, top: 2),
                  decoration: BoxDecoration(color: b.accentColor,
                      borderRadius: BorderRadius.circular(2))),
              Container(width: 38, height: 38,
                  decoration: BoxDecoration(color: b.accentColor.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(11)),
                  child: Center(child: Text(b.emoji,
                      style: const TextStyle(fontSize: 18)))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(b.title, style: const TextStyle(fontSize: 14,
                    fontWeight: FontWeight.w800, color: kInk)),
                const SizedBox(height: 2),
                Text(b.subtitle, style: TextStyle(fontSize: 12, color: kSub)),
                if (b.subtasks.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ...List.generate(b.subtasks.length, (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(children: [
                      LiquidCheckbox(value: _checked.contains(i),
                          activeColor: b.accentColor,
                          onChanged: (_) => setState(() {
                            _checked.contains(i)
                                ? _checked.remove(i) : _checked.add(i);
                          })),
                      const SizedBox(width: 8),
                      Text(b.subtasks[i], style: TextStyle(fontSize: 12,
                          color: _checked.contains(i) ? kSub : kInk,
                          decoration: _checked.contains(i)
                              ? TextDecoration.lineThrough : null)),
                    ]),
                  )),
                ],
              ])),
            ]),
          ),
        )),
      ],
    ));
  }
}

class _EmptyState extends StatelessWidget {
  final RoutineFilter filter; final VoidCallback onSetup;
  const _EmptyState({required this.filter, required this.onSetup});
  @override
  Widget build(BuildContext context) {
    final m = _filterMeta[filter]!;
    return Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(m.emoji, style: const TextStyle(fontSize: 52)),
        const SizedBox(height: 16),
        Text('No ${m.label.toLowerCase()} today',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kInk)),
        const SizedBox(height: 8),
        Text('Set up your ${m.label.toLowerCase()} routine\nand it will appear here automatically.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: kSub, height: 1.5)),
        const SizedBox(height: 24),
        LiquidButton(label: 'Set up ${m.label}', color: m.color, onTap: onSetup),
      ]),
    ));
  }
}

Color _hexColor(String hex) {
  try { return Color(int.parse('FF${hex.replaceAll('#','')}', radix: 16)); }
  catch (_) { return kPurple; }
}
String _fmtMin(int m) => '${(m~/60).toString().padLeft(2,'0')}:${(m%60).toString().padLeft(2,'0')}';
int _parseMin(String t) { final p = t.split(':'); return int.parse(p[0])*60+int.parse(p[1]); }
String _mealLabel(String t) { final h = int.tryParse(t.split(':')[0])??0; return h<10?'Breakfast':h<14?'Lunch':h<17?'Snack':'Dinner'; }
String _todayLabel() { final n=DateTime.now(); const m=['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec']; return '${m[n.month-1]} ${n.day}, ${n.year}'; }
