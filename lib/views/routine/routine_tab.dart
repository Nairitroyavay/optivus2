// lib/Routine Screen/routine_tab_impl.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/providers/routine_provider.dart';
import 'skin_care_setup_screen.dart';
import 'eating_setup_screen.dart';
import 'class_setup_screen.dart';


import 'fixed_schedule_setup_screen.dart';

import 'ai_routine_panel.dart';
import 'routine_settings_sheet.dart';
import 'glass_filter_dropdown.dart';
export 'glass_filter_dropdown.dart';
export 'package:optivus2/providers/routine_provider.dart' show RoutineFilter;
import 'timeline_section.dart';
import 'timeline_zoom_views.dart';

enum TimelineZoomLevel { day, week, month, year }

// DisplayBlock is now defined in timeline_section.dart

class RoutineTab extends ConsumerStatefulWidget {
  final RoutineFilter initialFilter;
  const RoutineTab({super.key, this.initialFilter = RoutineFilter.all});
  @override ConsumerState<RoutineTab> createState() => _RoutineTabState();
}

class _RoutineTabState extends ConsumerState<RoutineTab> {
  late RoutineFilter _filter;
  bool _aiOpen = false;
  bool _aiToggle = false;
  bool _taskToggle = false;

  TimelineZoomLevel _zoomLevel = TimelineZoomLevel.day;
  bool _isZooming = false;

  DateTime? _activeDate;
  final Map<DateTime, GlobalKey> _dayKeys = {};

  String get _todayKey {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2,'0')}-${n.day.toString().padLeft(2,'0')}';
  }

  @override void initState() { super.initState(); _filter = widget.initialFilter; }

  GlobalKey _getKeyFor(DateTime d) {
    return _dayKeys.putIfAbsent(d, () => GlobalKey());
  }

  void _updateActiveDayFromScroll() {
    DateTime? newActiveDate = _activeDate;
    
    // Sort keys to evaluate top-to-bottom
    final sortedKeys = _dayKeys.keys.toList()..sort();
    
    for (final d in sortedKeys) {
       final ctx = _dayKeys[d]?.currentContext;
       if (ctx == null) {
         continue;
       }
       final box = ctx.findRenderObject() as RenderBox?;
       if (box == null) {
         continue;
       }
       final y = box.localToGlobal(Offset.zero).dy;
       // 260px corresponds roughly to the area just below the filters
       if (y <= 270) { 
         newActiveDate = d;
       }
    }
    
    if (newActiveDate != null && newActiveDate != _activeDate) {
      Future.microtask(() {
        if (mounted) setState(() => _activeDate = newActiveDate);
      });
    }
  }

  Map<DateTime, List<DisplayBlock>> _buildAllBlocks(RoutineState s) {
    Map<DateTime, List<DisplayBlock>> days = {};
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    
    // Build blocks for the next 14 days
    for (int i = 0; i < 14; i++) {
       DateTime d = today.add(Duration(days: i));
       List<DisplayBlock> b = _buildBlocksForDay(s, d);
       if (b.isNotEmpty || i == 0) { // always include today even if empty
           days[d] = b;
       }
    }
    return days;
  }

  List<DisplayBlock> _buildBlocksForDay(RoutineState s, DateTime date) {
    final dayIdx = (date.weekday - 1).clamp(0, 6);
    final blocks = <DisplayBlock>[];

    // 1) First generate a flat list of actual scheduled events
    final scheduled = <DisplayBlock>[];

    // Fixed blocks repeat every day — include them for all days in the list
    if (_filter == RoutineFilter.all) {
      for (final fb in s.fixedBlocks) {
        scheduled.add(DisplayBlock(time: tlFmtMin(fb.startMinute), title: fb.title,
            subtitle: '${fb.startLabel} – ${fb.endLabel}',
            accentColor: tlHexColor(fb.colorHex), emoji: fb.emoji, type: RoutineFilter.all));
      }
    }

    if (_filter == RoutineFilter.all || _filter == RoutineFilter.skinCare) {
      final p = s.skinPlanForDay(dayIdx);
      if (p.morning.isNotEmpty) {
        scheduled.add(DisplayBlock(time:'07:30', title:'Morning Skin Care',
            subtitle: p.morning.map((x)=>x.name).join(' · '), accentColor:kMint, emoji:'🌿', type:RoutineFilter.skinCare,
            subtasks: p.morning.map((x) => x.name).toList()));
      }
      if (p.afternoon.isNotEmpty) {
        scheduled.add(DisplayBlock(time:'13:00', title:'Afternoon Skin Care',
            subtitle: p.afternoon.map((x)=>x.name).join(' · '), accentColor:kMint, emoji:'💧', type:RoutineFilter.skinCare,
            subtasks: p.afternoon.map((x) => x.name).toList()));
      }
      if (p.night.isNotEmpty) {
        scheduled.add(DisplayBlock(time:'22:00', title:'Night Skin Care',
            subtitle: p.night.map((x)=>x.name).join(' · '), accentColor:kPurple, emoji:'🌙', type:RoutineFilter.skinCare,
            subtasks: p.night.map((x) => x.name).toList()));
      }
    }

    if (_filter == RoutineFilter.all || _filter == RoutineFilter.classes) {
      for (final c in s.classesForDay(date.weekday)) {
        scheduled.add(DisplayBlock(time:c.startTime, title:c.subject,
            subtitle:'${c.room} · ${c.professor}',
            accentColor:tlHexColor(c.colorHex), emoji:'🎓', type:RoutineFilter.classes));
      }
    }

    if (_filter == RoutineFilter.all || _filter == RoutineFilter.eating) {
      for (final m in s.mealPlanForDay(dayIdx).all) {
        // Normalize time to HH:MM 24h for consistent display and sorting
        final normalizedTime = tlNormalizeTime(m.time);
        scheduled.add(DisplayBlock(time: normalizedTime, title:tlMealLabel(normalizedTime),
            subtitle:m.name, accentColor:kRose, emoji:m.emoji, type:RoutineFilter.eating));
      }
    }

    // Long-Term Goals
    if (_filter == RoutineFilter.all) {
      final targetDate = DateTime(date.year, date.month, date.day);
      for (final g in s.longTermGoals) {
        final start = DateTime(g.startDate.year, g.startDate.month, g.startDate.day);
        final end = DateTime(g.endDate.year, g.endDate.month, g.endDate.day);
        
        // If the date is within the goal's duration
        if (!targetDate.isBefore(start) && !targetDate.isAfter(end)) {
           final timeStr = g.dailyTaskTime ?? '00:00';
           scheduled.add(DisplayBlock(
             time: timeStr,
             title: g.title,
             subtitle: 'Long-Term Goal',
             accentColor: tlHexColor(g.colorHex),
             emoji: g.emoji,
             type: RoutineFilter.all,
           ));
        }
      }
    }

    scheduled.sort((a,b) => a.time.compareTo(b.time));

    // 2) Create the full 24-hour structure.
    for (int hour = 0; hour < 24; hour++) {
      final timeStr = '${hour.toString().padLeft(2, '0')}:00';
      
      // Find all scheduled tasks for this exact hour
      final tasksForHour = scheduled.where((b) {
        final bHour = int.tryParse(b.time.split(':')[0]) ?? 0;
        return bHour == hour;
      }).toList();

      if (tasksForHour.isEmpty) {
        // If hour is completely empty, add our empty placeholder
        blocks.add(DisplayBlock(
          time: timeStr, title: '', subtitle: '',
          accentColor: Colors.transparent, emoji: '', type: RoutineFilter.all,
          isEmptyPlaceholder: true,
        ));
      } else {
        // Otherwise, add all tasks that happen within this hour in order
        blocks.addAll(tasksForHour);
      }
    }

    // We don't sort here anymore, the list is already constructed in 00:00 - 23:59 order

    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      final nowMin = now.hour * 60 + now.minute;
      for (int i = 0; i < blocks.length - 1; i++) {
        if (nowMin >= tlParseMin(blocks[i].time) && nowMin < tlParseMin(blocks[i+1].time)) {
          final b = blocks[i];
          blocks[i] = DisplayBlock(time:b.time, title:b.title, subtitle:b.subtitle,
              accentColor:b.accentColor, emoji:b.emoji, type:b.type,
              subtasks:b.subtasks, isNow:true);
          break;
        }
      }
    }
    return blocks;
  }

  void _onFilter(RoutineFilter f, RoutineState s) {
    setState(() => _filter = f);
  }

  void _doSetup(RoutineFilter f) {
    if (f == RoutineFilter.skinCare) {
      Navigator.push(context, slideRoute(SkinCareSetupScreen(onComplete: () {
        ref.read(routineProvider.notifier).markSkinCareSetUp();
        setState(() => _filter = RoutineFilter.skinCare);
      })));
    } else if (f == RoutineFilter.eating) {
      Navigator.push(context, slideRoute(EatingSetupScreen(
          onComplete: () => setState(() => _filter = RoutineFilter.eating))));
    } else if (f == RoutineFilter.classes) {
      Navigator.push(context, slideRoute(ClassSetupScreen(onComplete: () {
        ref.read(routineProvider.notifier).setClasses(kDefaultClasses); // sets classesSetUp true, demo purposes
        setState(() => _filter = RoutineFilter.classes);
      })));
    } else if (f == RoutineFilter.fixedSchedule) {
      Navigator.push(context, slideRoute(FixedScheduleSetupScreen(onComplete: () {
        setState(() => _filter = RoutineFilter.fixedSchedule);
      })));
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final isTomorrow = date.year == now.year && date.month == now.month && date.day == now.day + 1;
    
    const daysStr = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const mos = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    
    final dayStr = daysStr[date.weekday - 1];
    final moStr = mos[date.month - 1];
    final dateStr = '$dayStr, $moStr ${date.day}, ${date.year}';
    
    if (isToday) return 'TODAY: $dateStr';
    if (isTomorrow) return 'TOMORROW: $dateStr';
    return dateStr.toUpperCase();
  }

  String _formatFlow(DateTime date) {
    if (_filter != RoutineFilter.all) return filterMetaData[_filter]!.label;

    switch (_zoomLevel) {
      case TimelineZoomLevel.week:
        return "This Week's Flow";
      case TimelineZoomLevel.month:
        return "This Month's Flow";
      case TimelineZoomLevel.year:
        return "This Year's Flow";
      case TimelineZoomLevel.day:
        final now = DateTime.now();
        final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
        final isTomorrow = date.year == now.year && date.month == now.month && date.day == now.day + 1;
        
        if (isToday) {
          return "Today's Flow";
        }
        if (isTomorrow) {
          return "Tomorrow's Flow";
        }
        
        const daysStr = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        const mos = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        return '${daysStr[date.weekday - 1]}, ${mos[date.month - 1]} ${date.day} Flow';
    }
  }

  void _zoomOut() {
    if (_isZooming) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _isZooming = true;
      if (_zoomLevel == TimelineZoomLevel.day) {
        _zoomLevel = TimelineZoomLevel.week;
      } else if (_zoomLevel == TimelineZoomLevel.week) {
        _zoomLevel = TimelineZoomLevel.month;
      } else if (_zoomLevel == TimelineZoomLevel.month) {
        _zoomLevel = TimelineZoomLevel.year;
      }
    });
  }

  void _zoomIn() {
    if (_isZooming) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _isZooming = true;
      if (_zoomLevel == TimelineZoomLevel.year) {
        _zoomLevel = TimelineZoomLevel.month;
      } else if (_zoomLevel == TimelineZoomLevel.month) {
        _zoomLevel = TimelineZoomLevel.week;
      } else if (_zoomLevel == TimelineZoomLevel.week) {
        _zoomLevel = TimelineZoomLevel.day;
      }
    });
  }

  Widget _buildDayHeaderSliver(DateTime date) {
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    // Today's header is shown in the main section header, skip it
    if (isToday) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: TimelineDayHeader(label: _formatDate(date).toUpperCase()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(routineProvider);
    final days = _buildAllBlocks(s);
    
    final displayDate = (_activeDate != null && days.containsKey(_activeDate)) 
        ? _activeDate! 
        : (days.isNotEmpty ? days.keys.first : DateTime.now());

    return LiquidBg(
      colors: const [Color(0xFFA3FF91), Color(0xFFEFFEEC)],
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(children: [
          SafeArea(bottom: false, child: Column(children: [
            // ─── Header: Info (Left) & Glass Action Island (Right) ───────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(_formatDate(displayDate).toUpperCase(),
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                                color: kInk.withValues(alpha: 0.8), letterSpacing: 1.2)),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _GlassToggle(
                            active: _aiToggle,
                            baseColor: const Color(0xFF86EFAC),
                            onChanged: (v) => setState(() {
                              _aiToggle = v;
                              _aiOpen = v;
                            }),
                            knobIcon: Icons.hub_rounded,
                            label: 'AI',
                          ),
                          const SizedBox(width: 10),
                          _GlassToggle(
                            active: _taskToggle,
                            baseColor: const Color(0xFFD8B4FE),
                            onChanged: (v) => setState(() => _taskToggle = v),
                            knobIcon: Icons.playlist_add_rounded,
                            label: null,
                          ),
                          const SizedBox(width: 8),
                          _SettingsPill(onTap: () => _openSettings(s)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(_formatFlow(displayDate),
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900,
                                color: kInk, letterSpacing: -1.0),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1),
                      ),
                      const SizedBox(width: 12),
                      GlassFilterDropdown(
                        selected: _filter,
                        routineState: s,
                        onSelected: (f) => _onFilter(f, s),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ─── Infinite Timeline Scroll ─────────────────────────────────
            Expanded(
              child: GestureDetector(
                onScaleUpdate: (details) {
                  if (details.scale < 0.75) {
                    _zoomOut();
                  } else if (details.scale > 1.3) {
                    _zoomIn();
                  }
                },
                onScaleEnd: (_) => setState(() => _isZooming = false),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: ScaleTransition(scale: animation, child: child)),
                  child: _zoomLevel == TimelineZoomLevel.week
                      ? TimelineWeekView(activeDate: displayDate, routineState: s, filter: _filter)
                      : _zoomLevel == TimelineZoomLevel.month
                          ? TimelineMonthView(activeDate: displayDate, routineState: s, filter: _filter)
                          : _zoomLevel == TimelineZoomLevel.year
                              ? TimelineYearView(activeDate: displayDate, routineState: s, filter: _filter)
                              // Default Day View
                              : NotificationListener<ScrollNotification>(
                                  onNotification: (notif) {
                                    _updateActiveDayFromScroll();
                                    return false;
                                  },
                                  child: CustomScrollView(
                                      physics: const BouncingScrollPhysics(),
                                      slivers: [
                                        for (final entry in days.entries) ...[
                                          // Day anchor (used for scroll detection)
                                          SliverToBoxAdapter(
                                             // Add key to SizedBox so it provides a RenderBox instead of RenderSliver
                                             child: SizedBox(key: _getKeyFor(entry.key), height: 1),
                                          ),
                                          // Day header — skip for today (already shown in main header)
                                          _buildDayHeaderSliver(entry.key),
                                          // Only show empty state for filters when there's actually nothing scheduled
                                          // (Filtering still drops blocks if they don't match, so if scheduled is empty we show 24 nulls)
                                          if (entry.value.every((b) => b.isEmptyPlaceholder) && _filter != RoutineFilter.all)
                                             SliverToBoxAdapter(
                                               child: Padding(
                                                 padding: const EdgeInsets.only(top: 20, bottom: 60),
                                                 child: TimelineEmptyState(filter: _filter, onSetup: () => _doSetup(_filter)),
                                               ),
                                             )
                                          else
                                             SliverPadding(
                                               padding: const EdgeInsets.only(bottom: 24),
                                               sliver: SliverList(
                                                 delegate: SliverChildBuilderDelegate(
                                                   (_, i) => TimelineRow(
                                                     block: entry.value[i],
                                                     index: i,
                                                     showHourLabel: i == 0 || entry.value[i].time.split(':')[0] != entry.value[i-1].time.split(':')[0],
                                                     isLast: i == entry.value.length - 1,
                                                   ),
                                                   childCount: entry.value.length,
                                                 ),
                                               ),
                                             ),
                                        ],
                                        const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
                                      ],
                                    ),
                                ),
                ),
              ),
            ),
          ])),

          // ─── AI dim overlay ───────────────────────────────────────────
          if (_aiOpen) Positioned.fill(
            bottom: 340,
            child: GestureDetector(
              onTap: () => setState(() => _aiOpen = false),
              child: Container(color: Colors.black.withValues(alpha: 0.18)),
            ),
          ),

          // ─── AI Panel ────────────────────────────────────────────────
          if (_aiOpen) Positioned(left: 0, right: 0, bottom: 0, child: AiRoutinePanel(
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

          // ─── Setup Popup Overlays ──────────────────────────────────
          if (!s.skinCareSetUp && _filter == RoutineFilter.skinCare)
            Positioned.fill(
              child: _buildSetupPopup(
                emoji: '🌿',
                title: 'No skin care today',
                subtitle: 'Set up your skin care routine\nand it will appear here automatically',
                buttonText: 'Set up Skin Care',
                filter: RoutineFilter.skinCare,
                buttonColors: [const Color(0xFFC4F6BB), const Color(0xFFA1F094)],
                shadowColor: const Color(0xFFA1F094).withValues(alpha: 0.4),
                glassColor: const Color(0xFF051105).withValues(alpha: 0.20), // Slight deep green tint
              ),
            ),
          
          if (!s.classesSetUp && _filter == RoutineFilter.classes)
            Positioned.fill(
              child: _buildSetupPopup(
                emoji: '🎓',
                title: 'No classes today',
                subtitle: 'Set up your class schedule\nand it will appear here automatically',
                buttonText: 'Set up Classes',
                filter: RoutineFilter.classes,
                buttonColors: [const Color(0xFF90C2F9), const Color(0xFF60B8FF)],
                shadowColor: const Color(0xFF60B8FF).withValues(alpha: 0.4),
                glassColor: const Color(0xFF050811).withValues(alpha: 0.20), // Slight deep blue tint
              ),
            ),

          if (!s.eatingSetUp && _filter == RoutineFilter.eating)
            Positioned.fill(
              child: _buildSetupPopup(
                emoji: '🍽️',
                title: 'No meals today',
                subtitle: 'Set up your eating routine\nand it will appear here automatically',
                buttonText: 'Set up Eating Routine',
                filter: RoutineFilter.eating,
                buttonColors: [const Color(0xFFFFD480), const Color(0xFFFFB830)],
                shadowColor: const Color(0xFFFFB830).withValues(alpha: 0.4),
                glassColor: const Color(0xFF110800).withValues(alpha: 0.20), // Slight deep amber/brown tint
              ),
            ),
        ]),
      ),
    );
  }

  Widget _buildSetupPopup({
    required String emoji,
    required String title,
    required String subtitle,
    required String buttonText,
    required RoutineFilter filter,
    required List<Color> buttonColors,
    required Color shadowColor,
    required Color glassColor,
  }) {
    return GestureDetector(
      onTap: () => _onFilter(RoutineFilter.all, ref.read(routineProvider)),
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.transparent, // Floating popup, no dimming
        child: Center(
          child: GestureDetector(
            onTap: () {}, // Absorb taps on the card itself
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1), // Softer glass shadow
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              // Stack to separate BackdropFilter from content
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 1. The Blur Layer
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30), // Match reference
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28), // Smooth creamy glass blur
                        child: Container(
                          color: glassColor, // Deep tinted ultra-transparent base
                        ),
                      ),
                    ),
                  ),
                  // 2. The Content Layer
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25), // Soft white rim
                        width: 1.0,
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.15), // Faint frost reflection at the edge
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 48, height: 1.0)),
                        const SizedBox(height: 16),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white, // White text on dark glass
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.7), // Slightly dimmed white text
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        GestureDetector(
                          onTap: () => _doSetup(filter),
                          child: Container(
                            width: double.infinity,
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(26),
                              boxShadow: [
                                BoxShadow(
                                  color: shadowColor, // Glowing specific color shadow
                                  blurRadius: 15,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.95),
                                  Colors.white.withValues(alpha: 0.2),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(1.5),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24.5),
                                  gradient: LinearGradient(
                                    colors: buttonColors,
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    Positioned(
                                      top: 0, left: 16, right: 16,
                                      child: Container(
                                        height: 12,
                                        decoration: BoxDecoration(
                                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.white.withValues(alpha: 0.9),
                                              Colors.white.withValues(alpha: 0.0),
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Center(
                                      child: Text(
                                        buttonText,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                          letterSpacing: 0.1,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// _TimelineRow, _EmptyState → now TimelineRow, TimelineEmptyState in timeline_section.dart

// ─────────────────────────────────────────────────────────────────────────────
// SETTINGS PILL  — transparent liquid-drop glass bubble
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsPill extends StatelessWidget {
  final VoidCallback onTap;
  const _SettingsPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // Almost fully transparent — just a whisper of fill
          color: Colors.white.withValues(alpha: 0.08),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.55),
            width: 1.5,
          ),
          boxShadow: [
            // Soft ambient glow underneath (liquid drop shadow)
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.60),
              blurRadius: 8,
              spreadRadius: 0,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 10,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Top-left specular gloss arc (the "liquid drop" shine)
            Align(
              alignment: const Alignment(-0.3, -0.5),
              child: Container(
                width: 16,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.90),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            // Settings icon
            const Center(
              child: Icon(
                Icons.settings_rounded,
                size: 17,
                color: Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GLASS TOGGLE  — iOS-style glassmorphic toggle with stretch animation
// ─────────────────────────────────────────────────────────────────────────────

class _GlassToggle extends StatefulWidget {
  final bool active;
  final Color baseColor;
  final ValueChanged<bool> onChanged;
  final IconData knobIcon;
  final String? label; // shown inside knob when off if non-null

  const _GlassToggle({
    required this.active,
    required this.baseColor,
    required this.onChanged,
    required this.knobIcon,
    this.label,
  });

  @override
  State<_GlassToggle> createState() => _GlassToggleState();
}

class _GlassToggleState extends State<_GlassToggle>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _slideAnim;
  late Animation<double> _squishAnim;

  // pill dimensions
  static const double _trackW = 68.0;
  static const double _trackH = 36.0;
  static const double _knobSize = 30.0;
  static const double _pad = 3.0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slideAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic);
    _squishAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.18), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.18, end: 1.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

    if (widget.active) _ctrl.value = 1.0;
  }

  @override
  void didUpdateWidget(_GlassToggle old) {
    super.didUpdateWidget(old);
    if (widget.active != old.active) {
      widget.active ? _ctrl.forward() : _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTap() => widget.onChanged(!widget.active);

  @override
  Widget build(BuildContext context) {
    final color = widget.baseColor;
    final darkColor = HSLColor.fromColor(color)
        .withLightness(
            (HSLColor.fromColor(color).lightness - 0.10).clamp(0.0, 1.0))
        .toColor();

    return GestureDetector(
      onTap: _onTap,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = _slideAnim.value;
          final squish = _squishAnim.value;

          // Max travel distance for knob
          final maxTravel = _trackW - _knobSize - _pad * 2;
          final knobX = _pad + t * maxTravel;

          return SizedBox(
            width: _trackW,
            height: _trackH,
            child: Stack(
              children: [
                // ── Track / pill body ───────────────────────────────────
                Positioned.fill(
                  child: Transform.scale(
                    scaleX: squish,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(_trackH / 2),
                        // Glassy fill: color at full opacity when on, muted when off
                        color: Color.lerp(
                          color.withValues(alpha: 0.45),
                          color.withValues(alpha: 0.90),
                          t,
                        ),
                        border: Border.all(
                          color: Color.lerp(
                            Colors.white.withValues(alpha: 0.60),
                            Colors.white.withValues(alpha: 0.85),
                            t,
                          )!,
                          width: 1.8,
                        ),
                        boxShadow: [
                          // Outer glow (colour-tinted when on)
                          BoxShadow(
                            color: Color.lerp(
                              Colors.black.withValues(alpha: 0.08),
                              darkColor.withValues(alpha: 0.38),
                              t,
                            )!,
                            blurRadius: 12,
                            spreadRadius: 0,
                            offset: const Offset(0, 4),
                          ),
                          // Inner top-edge highlight (glass rim)
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.55),
                            blurRadius: 0,
                            spreadRadius: -1,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      // Inner gloss layer
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Container(
                          height: _trackH * 0.45,
                          margin: const EdgeInsets.only(top: 2, left: 6, right: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.50),
                                Colors.white.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Knob ────────────────────────────────────────────────
                Positioned(
                  left: knobX,
                  top: (_trackH - _knobSize) / 2,
                  child: Container(
                    width: _knobSize,
                    height: _knobSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.9),
                          blurRadius: 0,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Center(
                      child: widget.label != null
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(widget.knobIcon,
                                    size: 10,
                                    color: const Color(0xFF475569)),
                                Text(
                                  widget.label!,
                                  style: const TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1E293B),
                                    height: 1.0,
                                  ),
                                ),
                              ],
                            )
                          : Icon(widget.knobIcon,
                              size: 16,
                              color: const Color(0xFF475569)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}



// All timeline helper functions (hexColor, fmtMin, parseMin, mealLabel, normalizeTime)
// are now exported from timeline_section.dart as tl-prefixed functions.
