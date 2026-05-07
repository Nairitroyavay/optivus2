// lib/views/fitness/activity_selection_screen.dart
//
// Activity type selection — grid of activity types with icons and GPS indicators.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/models/fitness_activity_model.dart';

class ActivitySelectionScreen extends ConsumerWidget {
  const ActivitySelectionScreen({super.key});

  static const _activityTypes = [
    FitnessActivityType.running,
    FitnessActivityType.walking,
    FitnessActivityType.cycling,
    FitnessActivityType.hiking,
    FitnessActivityType.swimming,
    FitnessActivityType.gymWorkout,
    FitnessActivityType.custom,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(activityHistoryProvider).valueOrNull ?? [];
    final lastByType = <FitnessActivityType, FitnessActivityModel>{};
    for (final activity in history) {
      lastByType.putIfAbsent(activity.activityType, () => activity);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidBg(
        colors: const [Color(0xFF78FDFF), Color(0xFFE8FEFE)],
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
                child: Row(
                  children: [
                    LiquidIconBtn(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => context.pop(),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'Choose Activity',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: kInk,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 6, 24, 16),
                child: Text(
                  'Select a workout type to get started',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kSub.withValues(alpha: 0.7),
                  ),
                ),
              ),

              // ── Activity Grid ──
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.builder(
                    physics: const BouncingScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 1.15,
                    ),
                    itemCount: _activityTypes.length,
                    itemBuilder: (context, index) {
                      final type = _activityTypes[index];
                      return _ActivityTypeCard(
                        type: type,
                        lastActivity: lastByType[type],
                        onTap: () {
                          HapticFeedback.lightImpact();
                          context.push(
                            '/fitness/pre-start?type=${type.toJson()}',
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Activity Type Card
// ─────────────────────────────────────────────────────────────────────────────

class _ActivityTypeCard extends StatefulWidget {
  final FitnessActivityType type;
  final FitnessActivityModel? lastActivity;
  final VoidCallback onTap;

  const _ActivityTypeCard({
    required this.type,
    required this.onTap,
    this.lastActivity,
  });

  @override
  State<_ActivityTypeCard> createState() => _ActivityTypeCardState();
}

class _ActivityTypeCardState extends State<_ActivityTypeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentForType(widget.type);

    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: LiquidCard(
          frosted: true,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Emoji + GPS indicator
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        widget.type.emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (widget.type.isGpsActivity)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: kBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.gps_fixed_rounded,
                              size: 10, color: kBlue.withValues(alpha: 0.8)),
                          const SizedBox(width: 3),
                          Text(
                            'GPS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: kBlue.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const Spacer(),
              // Label
              Text(
                widget.type.displayName,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: kInk,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.lastActivity == null
                    ? _subtitleForType(widget.type)
                    : _lastActivityLabel(widget.lastActivity!),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: kSub.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _accentForType(FitnessActivityType type) {
    switch (type) {
      case FitnessActivityType.running:
        return kCoral;
      case FitnessActivityType.walking:
        return kMint;
      case FitnessActivityType.cycling:
        return kBlue;
      case FitnessActivityType.hiking:
        return kRose;
      case FitnessActivityType.swimming:
        return const Color(0xFF40C4FF);
      case FitnessActivityType.gymWorkout:
        return kPurple;
      case FitnessActivityType.custom:
        return kAmber;
    }
  }

  String _subtitleForType(FitnessActivityType type) {
    switch (type) {
      case FitnessActivityType.running:
        return 'Outdoor or treadmill';
      case FitnessActivityType.walking:
        return 'Casual or brisk';
      case FitnessActivityType.cycling:
        return 'Road or stationary';
      case FitnessActivityType.hiking:
        return 'Trail & elevation';
      case FitnessActivityType.swimming:
        return 'Pool or open water';
      case FitnessActivityType.gymWorkout:
        return 'Weights & cardio';
      case FitnessActivityType.custom:
        return 'Any workout';
    }
  }

  String _lastActivityLabel(FitnessActivityModel activity) {
    final duration = activity.activeDuration;
    final minutes = duration.inMinutes;
    final distanceKm = activity.distanceMeters / 1000;
    if (activity.isGpsActivity && distanceKm > 0) {
      return 'Last ${distanceKm.toStringAsFixed(1)} km';
    }
    if (minutes > 0) return 'Last $minutes min';
    return 'Last activity saved';
  }
}
