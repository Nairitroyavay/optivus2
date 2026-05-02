import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/views/habits/log_habit_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/models/task_model.dart';
import 'package:optivus2/models/habit_model.dart';
import 'package:optivus2/models/streak_model.dart';
import 'package:optivus2/providers/identity_provider.dart';
// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────

const _kInk = Color(0xFF0F111A);
const _kAmber = Color(0xFFFFB830);
const _kSubtext = Color(0xFF6B7280);
const _kRingDark = Color(0xFF1A1F3C); // deep navy for ring arc

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const _weekDays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

// ─────────────────────────────────────────────────────────────────────────────
// HOME TAB
// ─────────────────────────────────────────────────────────────────────────────

class HomeTab extends ConsumerStatefulWidget {
  final VoidCallback? onSkinCareTapped;
  final VoidCallback? onClassesTapped;
  final VoidCallback? onEatingTapped;
  const HomeTab({
    super.key,
    this.onSkinCareTapped,
    this.onClassesTapped,
    this.onEatingTapped,
  });

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ringCtrl;
  late final Animation<double> _ringAnim;

  DateTime _focusMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ringCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    _ringAnim = CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOutCubic);
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _ringCtrl.forward();
    });
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Measure the header height: top padding 16 + card vertical padding ~30 +
    // text lines. Add SafeArea top via MediaQuery.
    final double topPad = MediaQuery.of(context).padding.top;
    final double headerH = topPad + 140;

    return Stack(
      children: [
        // ── Scrollable content with fade-out mask at the top ──────────────
        Positioned.fill(
          child: ShaderMask(
            shaderCallback: (Rect bounds) {
              // Fade from transparent to solid white right underneath the header
              final fadeStart = headerH / bounds.height;
              final fadeEnd = (headerH + 24) / bounds.height;
              return LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: const [Colors.transparent, Colors.white],
                stops: [fadeStart.clamp(0.0, 1.0), fadeEnd.clamp(0.0, 1.0)],
              ).createShader(bounds);
            },
            blendMode: BlendMode.dstIn,
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(top: headerH, bottom: 120),
              children: [
                _missionCard(),
                _endOfDayPrompt(),
                _habitSection(),
                _streakSection(),
                _routinesSection(),
              ],
            ),
          ),
        ),

        // ── Fixed Good Morning header ─────────────────────────────────────
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _header(topPad: topPad),
        ),

        // ── Floating Action Button ────────────────────────────────────────
        Positioned(
          bottom: 24,
          right: 24,
          child: SafeArea(
            child: FloatingActionButton(
              heroTag: 'logHabitFab',
              backgroundColor: _kInk,
              foregroundColor: Colors.white,
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const LogHabitSheet(),
                );
              },
              child: const Icon(Icons.add, size: 28),
            ),
          ),
        ),
      ],
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  String get _dynamicGreeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  String get _dynamicDateLabel {
    const days = [
      'MONDAY',
      'TUESDAY',
      'WEDNESDAY',
      'THURSDAY',
      'FRIDAY',
      'SATURDAY',
      'SUNDAY'
    ];
    const mos = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC'
    ];
    final now = DateTime.now();
    return '${days[now.weekday - 1]}, ${mos[now.month - 1]} ${now.day}';
  }

  String get _userName {
    return FirebaseAuth.instance.currentUser?.displayName ?? 'User';
  }

  Widget _header({double topPad = 0}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16 + topPad, 20, 12),
      child: LiquidCard(
        padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
        radius: 22,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _dynamicDateLabel,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _kSubtext,
                        letterSpacing: .8),
                  ),
                  const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: _kInk,
                          letterSpacing: -0.5,
                          height: 1.15),
                      children: [
                        TextSpan(text: '$_dynamicGreeting\n'),
                        TextSpan(
                            text: _userName,
                            style: const TextStyle(color: _kInk)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // 3D glass notification orb
            _GlassOrb(
              size: 46,
              colors: [const Color(0xFFD0D8E8), const Color(0xFFB8C4D8)],
              child: Stack(
                children: [
                  const Center(
                      child: Icon(Icons.notifications_outlined,
                          size: 20, color: _kInk)),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: _kAmber,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Today's Mission ────────────────────────────────────────────────────────
  Widget _missionCard() {
    final tasksAsync = ref.watch(todayTasksProvider);
    final identity = ref.watch(identityProvider).valueOrNull;
    final tasks = tasksAsync.valueOrNull ?? [];
    final identities = identity?.identities
            .map((item) => item.trim().toLowerCase())
            .where((item) => item.isNotEmpty)
            .toSet() ??
        const <String>{};
    final scoredTasks =
        tasks.where((task) => !_isValidReasonSkip(task)).toList();
    final totalTasks = scoredTasks.length;
    final completedTasks =
        scoredTasks.where((t) => t.state == TaskState.completed).length;
    final plannedMinutes =
        scoredTasks.fold<int>(0, (sum, task) => sum + task.plannedDurationMin);
    final completedMinutes = scoredTasks.fold<int>(
      0,
      (sum, task) => sum + (task.actualDurationMin ?? 0),
    );
    var completedValue = 0.0;
    var maxValue = 0.0;
    for (final task in scoredTasks) {
      final aligned = task.identityTags
          .map((tag) => tag.trim().toLowerCase())
          .any(identities.contains);
      final weight = aligned ? 1.0 : 0.5;
      maxValue += weight;
      if (task.state == TaskState.completed) completedValue += weight;
    }
    final progress = maxValue > 0 ? completedValue / maxValue : 0.0;
    final isLoading = tasksAsync.isLoading && tasks.isEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: LiquidCard(
        radius: 28,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Today's Mission",
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _kInk)),
                _GlassOrb(
                  size: 34,
                  colors: [const Color(0xFFD0D8E8), const Color(0xFFB0B8CC)],
                  child: const Icon(Icons.track_changes_outlined,
                      size: 16, color: _kInk),
                ),
              ],
            ),
            const SizedBox(height: 20),
            AnimatedBuilder(
              animation: _ringAnim,
              builder: (context, child) => _MissionRing(
                progress: progress * _ringAnim.value,
                isLoading: isLoading,
              ),
            ),
            const SizedBox(height: 20),
            if (isLoading)
              const Text('Loading today...',
                  style: TextStyle(fontSize: 13, color: _kSubtext))
            else if (totalTasks == 0)
              const Text('No mission tasks scheduled yet',
                  style: TextStyle(fontSize: 13, color: _kSubtext))
            else
              Text(
                maxValue == 0
                    ? 'No identity-linked tasks yet'
                    : 'Identity-weighted progress',
                style: const TextStyle(fontSize: 13, color: _kSubtext),
              ),
            const SizedBox(height: 14),
            // Stat pills
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _statPill('Tasks', '$completedTasks/$totalTasks'),
                _statPill('Done', '${completedMinutes}m'),
                _statPill('Planned', '${plannedMinutes}m'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _isValidReasonSkip(TaskModel task) {
    if (task.state != TaskState.skipped) return false;
    final tag = (task.reasonTag ?? '').toLowerCase();
    return tag == 'valid_reason' || tag == 'day_off' || tag == 'illness';
  }

  Widget _endOfDayPrompt() {
    final tasks = ref.watch(todayTasksProvider).valueOrNull ?? const [];
    final userData = ref.watch(currentUserDocumentProvider).valueOrNull;
    final now = DateTime.now();
    final configuredTime = _parseTodayTime(
      userData?['endOfDayPromptTime'] ??
          userData?['sleepTime'] ??
          userData?['sleep_time'],
    );
    final afterSleepBlock = tasks.any((task) {
      final title = task.title.toLowerCase();
      return title.contains('sleep') && now.isAfter(task.plannedStart);
    });
    final showPrompt = afterSleepBlock ||
        (configuredTime != null && now.isAfter(configuredTime)) ||
        (configuredTime == null && now.hour >= 22);
    if (!showPrompt) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: LiquidCard(
        radius: 22,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Row(
          children: [
            const Icon(Icons.nightlight_round, color: _kRingDark),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'End-of-day check-in is ready',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _kInk,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                ref.read(routineServiceProvider).runDayCloseIfNeeded();
              },
              child: const Text('Review'),
            ),
          ],
        ),
      ),
    );
  }

  DateTime? _parseTodayTime(Object? value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})')
        .firstMatch(value?.toString().trim() ?? '');
    if (match == null) return null;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  Widget _statPill(String label, String value) {
    return LiquidCard.solid(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _kSubtext,
                  letterSpacing: 0.8)),
          const SizedBox(height: 3),
          Text(value,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _kInk,
                  letterSpacing: -0.5)),
        ],
      ),
    );
  }

  // ── Habit Check-in — pill chips with glass orb icons ──────────────────────
  Widget _habitSection() {
    final habitsAsync = ref.watch(habitsProvider);
    final logsAsync = ref.watch(todayHabitLogsProvider);

    final habits = habitsAsync.valueOrNull ?? [];
    final logs = logsAsync.valueOrNull ?? [];

    // Quick lookup for habits that have a 'good' log today
    final completedHabitIds = logs
        .where((doc) => doc.data()['logType'] == 'good')
        .map((doc) => doc.data()['habitId'] as String)
        .toSet();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Habit Check-in',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _kInk)),
                Text('${habits.length}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kSubtext)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 58,
            child: habits.isEmpty
                ? const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('No habits yet.',
                          style: TextStyle(color: _kSubtext)),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(right: 20),
                    itemCount: habits.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 10),
                    itemBuilder: (context, i) {
                      final h = habits[i];
                      return _HabitPill(h,
                          completedToday: completedHabitIds.contains(h.id));
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ── Streak Summary + Plan by Date (2-column) ───────────────────────────────
  Widget _streakSection() {
    final streaksAsync = ref.watch(allStreaksProvider);
    final tasksAsync = ref.watch(todayTasksProvider);
    final streaks = streaksAsync.valueOrNull ?? [];

    int longestActive = 0;
    for (final s in streaks) {
      if (s.state == StreakState.active && s.currentCount > longestActive) {
        longestActive = s.currentCount;
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: streak cards
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Streak Summary',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800, color: _kInk)),
              const SizedBox(height: 10),
              Column(
                children: [
                  _streakCard(
                    emoji: '🔥',
                    value: longestActive.toString(),
                    badge: 'Active',
                    label: 'Longest Streak',
                    gradColors: [
                      const Color(0xFFFF9B3E),
                      const Color(0xFFFFB830)
                    ],
                    badgeColor: const Color(0xFF60D4A0),
                  ),
                  const SizedBox(height: 12),
                  _streakCard(
                    emoji: '⏱️',
                    value: '0h',
                    badge: 'Total',
                    label: 'Focus Time',
                    gradColors: [
                      const Color(0xFF8B7FFF),
                      const Color(0xFF6B5FEF)
                    ],
                    badgeColor: const Color(0xFF9B8FFF),
                    light: true,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 14),
          // Right: Plan by Date + calendar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Plan by Date',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _kInk)),
                  ],
                ),
                const SizedBox(height: 10),
                LiquidCard(
                  radius: 20,
                  padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
                  child: _InlineCalendar(
                    focusMonth: _focusMonth,
                    selectedDay: _selectedDay,
                    events: _eventsForMonth(
                      tasksAsync.valueOrNull ?? const <TaskModel>[],
                    ),
                    onMonthChanged: (d) => setState(() => _focusMonth = d),
                    onDayTapped: (d) => setState(() => _selectedDay = d),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _streakCard({
    required String emoji,
    required String value,
    required String badge,
    required String label,
    required List<Color> gradColors,
    required Color badgeColor,
    bool light = false,
  }) {
    final textColor = light ? Colors.white : const Color(0xFF1A0800);
    final subtextColor =
        light ? Colors.white70 : Colors.black.withValues(alpha: 0.55);
    return SizedBox(
      width: 110,
      child: LiquidCard.solid(
        radius: 20,
        padding: const EdgeInsets.all(12),
        tint: gradColors[0].withValues(alpha: 0.3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                        letterSpacing: -0.5)),
                const SizedBox(width: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(badge,
                      style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ],
            ),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: subtextColor)),
          ],
        ),
      ),
    );
  }

  // ── Your Recurring Routines ────────────────────────────────────────────────
  Widget _routinesSection() {
    final tasksAsync = ref.watch(todayTasksProvider);
    final tasks = tasksAsync.valueOrNull ?? [];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your Recurring Routines',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, color: _kInk)),
          const SizedBox(height: 12),
          if (tasks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('No routines scheduled for today',
                    style: TextStyle(color: _kSubtext)),
              ),
            )
          else
            ...List.generate(tasks.length, (i) {
              final t = tasks[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () {
                    // Route by task type until routine-specific screens own these rows.
                    final routineType = t.type.toJson();
                    if (routineType == 'skin_care') {
                      widget.onSkinCareTapped?.call();
                    } else if (routineType == 'class') {
                      widget.onClassesTapped?.call();
                    } else if (routineType == 'eating') {
                      widget.onEatingTapped?.call();
                    }
                  },
                  child: _TaskRow(t),
                ),
              );
            }),
        ],
      ),
    );
  }

  Map<int, Color> _eventsForMonth(List<TaskModel> tasks) {
    final events = <int, Color>{};
    for (final task in tasks) {
      if (task.plannedStart.year == _focusMonth.year &&
          task.plannedStart.month == _focusMonth.month) {
        events[task.plannedStart.day] =
            task.state == TaskState.completed ? _kAmber : _kRingDark;
      }
    }
    return events;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED GLASS CARD  (BackdropFilter + frosted white container)
class _GlassOrb extends StatelessWidget {
  final double size;
  final List<Color> colors;
  final Widget? child;

  const _GlassOrb({required this.size, required this.colors, this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.4),
          radius: 0.85,
          colors: [
            Colors.white.withValues(alpha: 0.90),
            colors[0].withValues(alpha: 0.70),
            colors[1],
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.80), width: 1.2),
        boxShadow: [
          BoxShadow(
              color: colors[1].withValues(alpha: 0.28),
              blurRadius: 14,
              offset: const Offset(0, 5)),
        ],
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HABIT PILL  (wide glass pill with 3-D orb icon + label)
// ─────────────────────────────────────────────────────────────────────────────

class _HabitPill extends StatelessWidget {
  final HabitModel h;
  final bool completedToday;
  const _HabitPill(this.h, {this.completedToday = false});

  @override
  Widget build(BuildContext context) {
    Color color = const Color(0xFF60B8FF);
    if (h.color != null) {
      final hex = h.color!.replaceFirst('#', '');
      color = Color(int.parse('FF$hex', radix: 16));
    }
    final emoji = completedToday ? '✅' : (h.emoji ?? '📌');

    return LiquidCard.solid(
      radius: 30,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      tint: completedToday
          ? const Color(0xFF60D4A0).withValues(alpha: 0.15)
          : Colors.white.withValues(alpha: 0.15),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 3-D orb icon
          _GlassOrb(
            size: 36,
            colors: [
              color.withValues(alpha: 0.55),
              color,
            ],
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 10),
          Text(h.name,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: _kInk)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ROUTINE ROW  (glass card + glass orb icon)
// ─────────────────────────────────────────────────────────────────────────────

class _TaskRow extends StatelessWidget {
  final TaskModel t;
  const _TaskRow(this.t);

  @override
  Widget build(BuildContext context) {
    Color orbColor = const Color(0xFF60D4A0);
    String emoji = '📌';
    final routineType = t.type.toJson();
    if (routineType == 'skin_care') {
      emoji = '🌿';
      orbColor = const Color(0xFF60D4A0);
    } else if (routineType == 'class') {
      emoji = '🎓';
      orbColor = const Color(0xFF60B8FF);
    } else if (routineType == 'eating') {
      emoji = '🍽️';
      orbColor = const Color(0xFFFFB830);
    }

    final isCompleted = t.state == TaskState.completed;

    return LiquidCard.solid(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 22,
      child: Row(
        children: [
          _GlassOrb(
            size: 44,
            colors: [
              orbColor.withValues(alpha: 0.50),
              orbColor,
            ],
            child: Center(
              child: Text(isCompleted ? '✅' : emoji,
                  style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        decoration:
                            isCompleted ? TextDecoration.lineThrough : null,
                        color: _kInk)),
                const SizedBox(height: 2),
                Text(
                    t.plannedDurationMin > 0
                        ? '${t.plannedDurationMin} min'
                        : 'Scheduled',
                    style: const TextStyle(fontSize: 12, color: _kSubtext)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: _kSubtext, size: 20),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MISSION RING  (dark navy progress arc)
// ─────────────────────────────────────────────────────────────────────────────

class _MissionRing extends StatelessWidget {
  final double progress;
  final bool isLoading;
  const _MissionRing({required this.progress, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 160,
      child: CustomPaint(
        painter: _RingPainter(progress: progress),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isLoading ? '--%' : '${(progress * 100).round()}%',
                style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    color: _kInk,
                    letterSpacing: -1.5),
              ),
              const Text(
                'COMPLETE',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _kSubtext,
                    letterSpacing: 1.8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  const _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 12;
    final rect = Rect.fromCircle(center: c, radius: r);

    // Track
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = const Color(0xFFDDDDDD).withValues(alpha: 0.60)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 13
        ..strokeCap = StrokeCap.round,
    );
    // Progress arc — dark navy like reference
    if (progress > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = _kRingDark
          ..style = PaintingStyle.stroke
          ..strokeWidth = 13
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// INLINE CALENDAR  (compact, fits inside glass card)
// ─────────────────────────────────────────────────────────────────────────────

class _InlineCalendar extends StatelessWidget {
  final DateTime focusMonth;
  final DateTime selectedDay;
  final Map<int, Color> events;
  final void Function(DateTime) onMonthChanged;
  final void Function(DateTime) onDayTapped;

  const _InlineCalendar({
    required this.focusMonth,
    required this.selectedDay,
    required this.events,
    required this.onMonthChanged,
    required this.onDayTapped,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(focusMonth.year, focusMonth.month, 1);
    final daysInMth = DateTime(focusMonth.year, focusMonth.month + 1, 0).day;
    final startCol = firstDay.weekday % 7;
    final prevMonthDays = DateTime(focusMonth.year, focusMonth.month, 0).day;
    final totalCells = startCol + daysInMth;
    final rows = (totalCells / 7).ceil();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => onMonthChanged(
                  DateTime(focusMonth.year, focusMonth.month - 1)),
              child: const Icon(Icons.chevron_left_rounded,
                  size: 18, color: _kInk),
            ),
            Text(
              '${_months[focusMonth.month - 1]} ${focusMonth.year}',
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: _kInk),
            ),
            GestureDetector(
              onTap: () => onMonthChanged(
                  DateTime(focusMonth.year, focusMonth.month + 1)),
              child: const Icon(Icons.chevron_right_rounded,
                  size: 18, color: _kInk),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: _weekDays
              .map((d) => Expanded(
                    child: Center(
                      child: Text(d,
                          style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: _kInk,
                              letterSpacing: .4)),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 3),
        for (int row = 0; row < rows; row++)
          Row(
            children: List.generate(7, (col) {
              final idx = row * 7 + col;
              final dayNum = idx - startCol + 1;

              if (dayNum < 1 || dayNum > daysInMth) {
                final label = dayNum < 1
                    ? '${prevMonthDays + dayNum}'
                    : '${dayNum - daysInMth}';
                return Expanded(
                  child: SizedBox(
                    height: 38,
                    child: Center(
                      child: Text(label,
                          style: const TextStyle(
                              fontSize: 10, color: Colors.black45)),
                    ),
                  ),
                );
              }

              final date = DateTime(focusMonth.year, focusMonth.month, dayNum);
              final isSel = date.year == selectedDay.year &&
                  date.month == selectedDay.month &&
                  date.day == selectedDay.day;
              final dot = events[dayNum];

              return Expanded(
                child: GestureDetector(
                  onTap: () => onDayTapped(date),
                  child: SizedBox(
                    height: 40,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: isSel ? _kRingDark : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text('$dayNum',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight:
                                      isSel ? FontWeight.w800 : FontWeight.w500,
                                  color: isSel ? Colors.white : _kInk,
                                )),
                          ),
                        ),
                        dot != null
                            ? Container(
                                width: 3,
                                height: 3,
                                decoration: BoxDecoration(
                                    color: dot, shape: BoxShape.circle))
                            : const SizedBox(height: 3),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        const SizedBox(height: 2),
      ],
    );
  }
}
