import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'add_task_sheet.dart';
import 'ai_routine_panel.dart';
import '../providers/routine_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PALETTE
// ─────────────────────────────────────────────────────────────────────────────

const _kInk    = Color(0xFF0F111A);
const _kAmber  = Color(0xFFFFB830);
const _kPurple = Color(0xFF9B8FFF);
const _kCard   = Colors.white;
const _kShad   = Color(0x14000000);

// ─────────────────────────────────────────────────────────────────────────────
// FAB LAYER WIDGET
//
// Drop this as a Stack child over your RoutineTab body. It handles:
//   • + Add Task FAB (amber, free)
//   • ✦ AI Toggle FAB (purple, premium)
//   • AI panel sliding up when toggled
//   • Paywall sheet for non-premium users
// ─────────────────────────────────────────────────────────────────────────────

class RoutineFabLayer extends ConsumerStatefulWidget {
  final RoutineState routineState;

  const RoutineFabLayer({super.key, required this.routineState});

  @override
  ConsumerState<RoutineFabLayer> createState() =>
      _RoutineFabLayerState();
}

class _RoutineFabLayerState extends ConsumerState<RoutineFabLayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _fabCtrl;
  late Animation<double>   _fabScale;

  bool _aiOpen = false;

  // Custom tasks for today
  String get _todayKey {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2,'0')}-${n.day.toString().padLeft(2,'0')}';
  }

  List<CustomTask> get _todayTasks {
    final map = ref.read(customTasksProvider);
    return map[_todayKey] ?? [];
  }

  @override
  void initState() {
    super.initState();
    _fabCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fabScale = CurvedAnimation(
        parent: _fabCtrl, curve: Curves.easeOutBack);
    _fabCtrl.forward();
  }

  @override
  void dispose() {
    _fabCtrl.dispose();
    super.dispose();
  }

  // ── Add task ──────────────────────────────────────────────────────────────

  void _openAddTask() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTaskSheet(
        onAdd: (task) {
          final key = '${task.date.year}-'
              '${task.date.month.toString().padLeft(2,'0')}-'
              '${task.date.day.toString().padLeft(2,'0')}';
          final map = Map<String, List<CustomTask>>.from(
              ref.read(customTasksProvider));
          map[key] = [...(map[key] ?? []), task];
          ref.read(customTasksProvider.notifier).state = map;
        },
      ),
    );
  }

  // ── AI toggle ─────────────────────────────────────────────────────────────

  void _toggleAi() {
    final isPremium = ref.read(isPremiumProvider);
    if (!isPremium) {
      _showPaywall();
      return;
    }
    setState(() => _aiOpen = !_aiOpen);
  }

  void _showPaywall() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PremiumPaywallSheet(
        onUnlock: () {
          Navigator.pop(context);
          // In production: launch in-app purchase flow
          // For demo: grant premium
          ref.read(isPremiumProvider.notifier).state = true;
          Future.delayed(
            const Duration(milliseconds: 300),
            () => setState(() => _aiOpen = true),
          );
        },
      ),
    );
  }

  // ── AI panel callbacks ────────────────────────────────────────────────────

  void _onAiAddTask(CustomTask task) {
    final map = Map<String, List<CustomTask>>.from(
        ref.read(customTasksProvider));
    map[_todayKey] = [...(map[_todayKey] ?? []), task];
    ref.read(customTasksProvider.notifier).state = map;
  }

  void _onAiRemoveTask(String taskId) {
    final map = Map<String, List<CustomTask>>.from(
        ref.read(customTasksProvider));
    map[_todayKey] =
        (map[_todayKey] ?? []).where((t) => t.id != taskId).toList();
    ref.read(customTasksProvider.notifier).state = map;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(isPremiumProvider);

    return Stack(
      children: [
        // ── AI panel (behind FABs) ────────────────────────────────────
        if (_aiOpen)
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: AiRoutinePanel(
              routineState: widget.routineState,
              todayTasks:   _todayTasks,
              onAddTask:    _onAiAddTask,
              onRemoveTask: _onAiRemoveTask,
            ),
          ),

        // ── Dim overlay when AI open ──────────────────────────────────
        if (_aiOpen)
          Positioned.fill(
            bottom: 340, // approx panel height
            child: GestureDetector(
              onTap: () => setState(() => _aiOpen = false),
              child: Container(color: Colors.black.withOpacity(0.18)),
            ),
          ),

        // ── FAB stack (bottom-right) ──────────────────────────────────
        Positioned(
          right: 20,
          bottom: _aiOpen ? 360 : 100,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [

                // ── ✦ AI FAB ──────────────────────────────────────────
                ScaleTransition(
                  scale: _fabScale,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Label tooltip
                      if (!_aiOpen)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _FabLabel(
                            text: isPremium
                                ? 'AI Coach'
                                : 'AI Coach ✦ Premium',
                            color: _kPurple,
                          ),
                        ),
                      GestureDetector(
                        onTap: _toggleAi,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 56, height: 56,
                          decoration: BoxDecoration(
                            gradient: _aiOpen
                                ? const LinearGradient(
                                    colors: [Color(0xFF9B8FFF),
                                        Color(0xFF78FDFF)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            color: _aiOpen ? null : _kCard,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _kPurple.withOpacity(
                                    _aiOpen ? 0.45 : 0.20),
                                blurRadius: _aiOpen ? 20 : 12,
                                offset: const Offset(0, 5),
                              ),
                            ],
                            border: _aiOpen
                                ? null
                                : Border.all(
                                    color: _kPurple.withOpacity(0.3),
                                    width: 1.5),
                          ),
                          child: Center(
                            child: Text(
                              '✦',
                              style: TextStyle(
                                fontSize: 20,
                                color: _aiOpen
                                    ? Colors.white
                                    : _kPurple,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── + Add FAB ─────────────────────────────────────────
                ScaleTransition(
                  scale: _fabScale,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _FabLabel(
                          text: 'Add Task',
                          color: _kAmber,
                        ),
                      ),
                      GestureDetector(
                        onTap: _openAddTask,
                        child: Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(
                            color: _kAmber,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _kAmber.withOpacity(0.40),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.add_rounded,
                              color: Colors.white, size: 28),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FAB LABEL TOOLTIP
// ─────────────────────────────────────────────────────────────────────────────

class _FabLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _FabLabel({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(color: _kShad, blurRadius: 8,
              offset: Offset(0, 2)),
        ],
      ),
      child: Text(text,
          style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700,
            color: color,
          )),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HOW TO USE IN RoutineTab
// ─────────────────────────────────────────────────────────────────────────────
//
// In your RoutineTab Scaffold, wrap the body in a Stack and add the layer:
//
//   @override
//   Widget build(BuildContext context) {
//     final s = ref.watch(routineProvider);
//     return Scaffold(
//       backgroundColor: _kBg,
//       body: Stack(
//         children: [
//           SafeArea(
//             child: Column(
//               children: [
//                 // ... header, filter pills, timeline ...
//               ],
//             ),
//           ),
//           RoutineFabLayer(routineState: s),
//         ],
//       ),
//     );
//   }
//
// Also update _buildBlocks() in RoutineTab to include custom tasks:
//
//   // Custom tasks (from + FAB or AI)
//   final customMap = ref.watch(customTasksProvider);
//   final todayKey  = '${today.year}-${today.month.toString().padLeft(2,'0')}-${today.day.toString().padLeft(2,'0')}';
//   final custom    = customMap[todayKey] ?? [];
//   for (final t in custom) {
//     blocks.add(_DisplayBlock(
//       time: t.time, title: t.title, subtitle: 'Custom task',
//       accentColor: t.color, emoji: t.emoji, type: RoutineFilter.all,
//     ));
//   }
