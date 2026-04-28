import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/models/habit_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Accent colour pool for habit cards — cycles through vibrant LiquidGlass tones
// ─────────────────────────────────────────────────────────────────────────────
const _kGoodAccents = [kMint, kBlue, kPurple, kAmber, kCoral];
const _kBadAccents = [kCoral, kRose, Color(0xFFFF5C93), kPurple];

class TrackerTab extends ConsumerStatefulWidget {
  const TrackerTab({super.key});

  @override
  ConsumerState<TrackerTab> createState() => _TrackerTabState();
}

class _TrackerTabState extends ConsumerState<TrackerTab> {
  /// Caches {habitId: dailyTotal} so we don't re-fetch on every build.
  final Map<String, num> _dailyTotals = {};
  final Map<String, int> _slipCounts = {};
  bool _totalsLoaded = false;

  Future<void> _loadDailyData(List<HabitModel> habits) async {
    if (_totalsLoaded) return;
    final service = ref.read(habitServiceProvider);
    final now = DateTime.now();
    for (final h in habits) {
      if (h.kind == HabitKind.good) {
        _dailyTotals[h.id] = await service.dailyTotal(h.id, now);
      } else {
        _slipCounts[h.id] = await service.dailyLogCount(h.id, now);
      }
    }
    if (mounted) setState(() => _totalsLoaded = true);
  }

  void _refreshData() {
    setState(() => _totalsLoaded = false);
  }

  @override
  Widget build(BuildContext context) {
    final habitsAsync = ref.watch(habitsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidBg(
        child: SafeArea(
          child: habitsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: kAmber),
            ),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 48, color: kCoral),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load habits',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: kInk.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      err.toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: kSub),
                    ),
                  ],
                ),
              ),
            ),
            data: (habits) {
              // Kick off daily data load
              _loadDailyData(habits);

              final goodHabits =
                  habits.where((h) => h.kind == HabitKind.good).toList();
              final badHabits =
                  habits.where((h) => h.kind == HabitKind.bad).toList();

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // ── Header ──
                  const SliverToBoxAdapter(
                    child: _TrackerHeader(),
                  ),

                  // ── Good Habits Section ──
                  if (goodHabits.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: LiquidSectionHeader(title: 'Good Habits'),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final habit = goodHabits[index];
                            final accent =
                                _kGoodAccents[index % _kGoodAccents.length];
                            final total = _dailyTotals[habit.id] ?? 0;
                            final goal = habit.dailyGoal ?? 1;
                            final progress =
                                (total / goal).clamp(0.0, 1.0).toDouble();

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _GoodHabitCard(
                                habit: habit,
                                accent: accent,
                                progress: progress,
                                currentValue: total,
                                goalValue: goal,
                              ),
                            );
                          },
                          childCount: goodHabits.length,
                        ),
                      ),
                    ),
                  ],

                  // ── Bad Habits Section ──
                  if (badHabits.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: LiquidSectionHeader(title: 'Habits to Break'),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 220,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: badHabits.length,
                          itemBuilder: (context, index) {
                            final habit = badHabits[index];
                            final accent =
                                _kBadAccents[index % _kBadAccents.length];
                            final slips = _slipCounts[habit.id] ?? 0;

                            return Padding(
                              padding: const EdgeInsets.only(right: 14),
                              child: _BadHabitCard(
                                habit: habit,
                                accent: accent,
                                slipCount: slips,
                                onLogSlip: () => _handleLogSlip(habit),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],

                  // ── Empty State ──
                  if (habits.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(),
                    ),

                  // Bottom padding
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogSlip(HabitModel habit) async {
    final confirmed = await showLiquidSheet<bool>(
      context: context,
      child: _LogSlipSheet(habit: habit),
    );
    if (confirmed == true) {
      _refreshData();
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// HEADER
// ═════════════════════════════════════════════════════════════════════════════

class _TrackerHeader extends StatelessWidget {
  const _TrackerHeader();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dayNames = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    final monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${dayNames[now.weekday - 1]}, ${monthNames[now.month - 1]} ${now.day}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: kSub.withValues(alpha: 0.7),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your Progress',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: kInk,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// GOOD HABIT CARD — frosted glass with animated progress bar
// ═════════════════════════════════════════════════════════════════════════════

class _GoodHabitCard extends StatelessWidget {
  final HabitModel habit;
  final Color accent;
  final double progress;
  final num currentValue;
  final num goalValue;

  const _GoodHabitCard({
    required this.habit,
    required this.accent,
    required this.progress,
    required this.currentValue,
    required this.goalValue,
  });

  IconData _iconForTracker(String trackerType) {
    switch (trackerType) {
      case 'water':
        return Icons.water_drop_rounded;
      case 'meditation':
        return Icons.self_improvement_rounded;
      case 'reading':
        return Icons.auto_stories_rounded;
      case 'exercise':
        return Icons.fitness_center_rounded;
      case 'sleep':
        return Icons.bedtime_rounded;
      case 'steps':
        return Icons.directions_walk_rounded;
      case 'nutrition':
        return Icons.restaurant_rounded;
      default:
        return Icons.check_circle_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = _iconForTracker(habit.trackerType);
    final emoji = habit.emoji;
    final pct = (progress * 100).toInt();
    final isComplete = progress >= 1.0;

    return LiquidCard(
      frosted: true,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Emoji or icon badge
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: emoji != null
                      ? Text(emoji, style: const TextStyle(fontSize: 22))
                      : Icon(icon, color: accent, size: 22),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: kInk,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$currentValue / $goalValue ${habit.unit}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: kSub.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              // Percentage badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isComplete
                      ? kMint.withValues(alpha: 0.18)
                      : accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isComplete ? '✓ Done' : '$pct%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isComplete ? kMint : accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Animated progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                // Track
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                // Fill with gradient
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      gradient: LinearGradient(
                        colors: [
                          accent,
                          accent.withValues(alpha: 0.7),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
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

// ═════════════════════════════════════════════════════════════════════════════
// BAD HABIT CARD — carousel card with slip counter and Log Slip CTA
// ═════════════════════════════════════════════════════════════════════════════

class _BadHabitCard extends StatelessWidget {
  final HabitModel habit;
  final Color accent;
  final int slipCount;
  final VoidCallback onLogSlip;

  const _BadHabitCard({
    required this.habit,
    required this.accent,
    required this.slipCount,
    required this.onLogSlip,
  });

  String _goalLabel(BadHabitGoalType? type) {
    switch (type) {
      case BadHabitGoalType.eliminate:
        return 'Goal: Zero today';
      case BadHabitGoalType.reduceToTarget:
        return 'Goal: Under ${habit.target ?? "?"}/day';
      default:
        return 'Tracking awareness';
    }
  }

  @override
  Widget build(BuildContext context) {
    final emoji = habit.emoji;
    final isOver = habit.goalType == BadHabitGoalType.eliminate && slipCount > 0;
    final isOverTarget = habit.goalType == BadHabitGoalType.reduceToTarget &&
        habit.target != null &&
        slipCount >= (habit.target ?? 0);

    return SizedBox(
      width: 180,
      child: LiquidCard(
        frosted: true,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon / Emoji
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: emoji != null
                    ? Text(emoji, style: const TextStyle(fontSize: 24))
                    : Icon(Icons.block_rounded, color: accent, size: 24),
              ),
            ),
            const SizedBox(height: 12),

            // Name
            Text(
              habit.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: kInk,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),

            // Goal label
            Text(
              _goalLabel(habit.goalType),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: kSub.withValues(alpha: 0.7),
              ),
            ),

            const Spacer(),

            // Slip counter
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isOver || isOverTarget)
                        ? kCoral.withValues(alpha: 0.18)
                        : kMint.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        (isOver || isOverTarget)
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline_rounded,
                        size: 14,
                        color: (isOver || isOverTarget) ? kCoral : kMint,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$slipCount slip${slipCount == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: (isOver || isOverTarget) ? kCoral : kMint,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Log Slip button
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onLogSlip();
              },
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    'Log Slip',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
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

// ═════════════════════════════════════════════════════════════════════════════
// LOG SLIP BOTTOM SHEET
// ═════════════════════════════════════════════════════════════════════════════

class _LogSlipSheet extends ConsumerStatefulWidget {
  final HabitModel habit;
  const _LogSlipSheet({required this.habit});

  @override
  ConsumerState<_LogSlipSheet> createState() => _LogSlipSheetState();
}

class _LogSlipSheetState extends ConsumerState<_LogSlipSheet> {
  final _triggerController = TextEditingController();
  final _noteController = TextEditingController();
  bool _isLogging = false;

  @override
  void dispose() {
    _triggerController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isLogging = true);
    try {
      final habitService = ref.read(habitServiceProvider);
      await habitService.logSlip(
        widget.habit.id,
        trigger: _triggerController.text.trim().isEmpty
            ? null
            : _triggerController.text.trim(),
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to log slip: $e'),
            backgroundColor: kCoral,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLogging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LiquidSheetHandle(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: kCoral.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: widget.habit.emoji != null
                          ? Text(widget.habit.emoji!,
                              style: const TextStyle(fontSize: 24))
                          : const Icon(Icons.block_rounded,
                              color: kCoral, size: 24),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Log a Slip',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: kInk,
                          ),
                        ),
                        Text(
                          widget.habit.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: kSub.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              LiquidTextField(
                hint: 'What triggered it? (optional)',
                prefixIcon: Icons.flash_on_rounded,
                controller: _triggerController,
              ),
              const SizedBox(height: 14),
              LiquidTextField(
                hint: 'Any notes? (optional)',
                prefixIcon: Icons.edit_note_rounded,
                controller: _noteController,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: LiquidButton(
                  label: _isLogging ? 'Logging…' : 'Log Slip',
                  color: kCoral,
                  onTap: _isLogging ? null : _submit,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: LiquidButton.outline(
                  label: 'Cancel',
                  color: kSub,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// EMPTY STATE
// ═════════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: kAmber.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.track_changes_rounded,
                size: 40,
                color: kAmber.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No habits yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: kInk,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first habit to start tracking your progress and building better routines.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: kSub.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
