// lib/views/fitness/activity_pre_start_screen.dart
//
// Pre-start configuration screen — shows selected activity type,
// goal/target inputs, notes, permission state, and Start button.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/core/utils/uuid_generator.dart';
import 'package:optivus2/models/fitness_activity_model.dart';

class ActivityPreStartScreen extends ConsumerStatefulWidget {
  final String activityType;
  final String? routineTaskId;

  const ActivityPreStartScreen({
    super.key,
    required this.activityType,
    this.routineTaskId,
  });

  @override
  ConsumerState<ActivityPreStartScreen> createState() =>
      _ActivityPreStartScreenState();
}

class _ActivityPreStartScreenState
    extends ConsumerState<ActivityPreStartScreen> {
  late FitnessActivityType _type;
  final _notesController = TextEditingController();
  final _distanceController = TextEditingController();
  final _durationController = TextEditingController();
  final _caloriesController = TextEditingController();

  // Swimming
  int _poolLength = 25;
  bool _isPoolSwimming = true;
  bool _openWaterGpsEnabled = false;

  String _workoutCategory = 'General workout';

  bool _isStarting = false;

  @override
  void initState() {
    super.initState();
    _type = FitnessActivityType.fromString(widget.activityType);
    if (_type == FitnessActivityType.swimming) {
      _isPoolSwimming = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_usesGps) _refreshPermissionState();
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    _distanceController.dispose();
    _durationController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final permState = ref.watch(fitnessPermissionProvider);
    final isGps = _usesGps;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidBg(
        colors: const [Color(0xFF78FDFF), Color(0xFFE8FEFE)],
        child: SafeArea(
          child: Column(
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
                    Expanded(
                      child: Text(
                        '${_type.emoji} ${_type.displayName}',
                        style: const TextStyle(
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

              // ── Scrollable body ──
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Activity Info Card ──
                      _ActivityInfoCard(type: _type),
                      const SizedBox(height: 16),

                      // ── GPS Permission Status (for GPS activities) ──
                      if (isGps) ...[
                        _GpsStatusCard(
                          isReady: permState.isGpsReady,
                          signalStrength: permState.gpsSignalStrength,
                          onRequestPermission: _requestLocationPermission,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Swimming pool config ──
                      if (_type == FitnessActivityType.swimming) ...[
                        _SwimmingConfigCard(
                          isPoolSwimming: _isPoolSwimming,
                          poolLength: _poolLength,
                          openWaterGpsEnabled: _openWaterGpsEnabled,
                          onPoolToggle: (v) {
                            setState(() => _isPoolSwimming = v);
                            if (!v) _refreshPermissionState();
                          },
                          onOpenWaterGpsChanged: (v) {
                            setState(() => _openWaterGpsEnabled = v);
                            if (v) _refreshPermissionState();
                          },
                          onPoolLengthChanged: (v) =>
                              setState(() => _poolLength = v),
                        ),
                        const SizedBox(height: 16),
                      ],

                      if (_type == FitnessActivityType.gymWorkout) ...[
                        _GymCategoryCard(
                          value: _workoutCategory,
                          onChanged: (v) =>
                              setState(() => _workoutCategory = v),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Goal / Target Inputs ──
                      const LiquidSectionHeader(title: 'Set Targets'),
                      const SizedBox(height: 8),
                      LiquidCard(
                        frosted: true,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            if (_type.isGpsActivity ||
                                _type == FitnessActivityType.swimming) ...[
                              LiquidTextField(
                                hint: 'Distance goal (km)',
                                prefixIcon: Icons.straighten_rounded,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                controller: _distanceController,
                              ),
                              const SizedBox(height: 12),
                            ],
                            LiquidTextField(
                              hint: 'Duration goal (minutes)',
                              prefixIcon: Icons.timer_outlined,
                              keyboardType: TextInputType.number,
                              controller: _durationController,
                            ),
                            const SizedBox(height: 12),
                            LiquidTextField(
                              hint: 'Calorie target',
                              prefixIcon: Icons.local_fire_department_rounded,
                              keyboardType: TextInputType.number,
                              controller: _caloriesController,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Notes ──
                      const LiquidSectionHeader(title: 'Notes'),
                      const SizedBox(height: 8),
                      LiquidTextField(
                        hint: 'Pre-activity notes (optional)',
                        prefixIcon: Icons.edit_note_rounded,
                        controller: _notesController,
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),

              // ── Start Button ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: LiquidButton(
                  label: _isStarting ? 'Starting…' : 'Start Activity',
                  leading: _isStarting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: kWhite,
                          ),
                        )
                      : const Icon(Icons.play_arrow_rounded,
                          color: kWhite, size: 22),
                  color: kMint,
                  onTap: _isStarting ? null : _startActivity,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startActivity() async {
    setState(() => _isStarting = true);
    try {
      final now = DateTime.now();
      final id = generateId();

      final distText = _distanceController.text.trim();
      final durText = _durationController.text.trim();
      final calText = _caloriesController.text.trim();

      final activity = FitnessActivityModel(
        activityId: id,
        activityType: _type,
        status: FitnessActivityStatus.pending,
        title: _type.displayName,
        notes: _notesController.text.trim(),
        isGpsActivity: _usesGps,
        isPoolSwimming:
            _type == FitnessActivityType.swimming && _isPoolSwimming,
        poolLengthMeters:
            _type == FitnessActivityType.swimming ? _poolLength : null,
        workoutCategory:
            _type == FitnessActivityType.gymWorkout ? _workoutCategory : '',
        routineTaskId: widget.routineTaskId,
        goalDistanceMeters: distText.isNotEmpty
            ? (double.tryParse(distText) ?? 0) * 1000 // km → meters
            : null,
        goalDurationMinutes: durText.isNotEmpty ? int.tryParse(durText) : null,
        goalCalories: calText.isNotEmpty ? int.tryParse(calText) : null,
        createdAt: now,
        updatedAt: now,
      );

      await ref
          .read(activeActivityControllerProvider.notifier)
          .startActivity(activity);

      final activeState = ref.read(activeActivityControllerProvider);
      if (activeState.activity == null || activeState.errorMessage != null) {
        throw activeState.errorMessage ??
            'Activity could not start. Check permission and GPS state.';
      }

      if (mounted) {
        context.go('/fitness/live');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start activity: $e'),
            backgroundColor: kCoral,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  bool get _usesGps =>
      _type.isGpsActivity ||
      (_type == FitnessActivityType.swimming &&
          !_isPoolSwimming &&
          _openWaterGpsEnabled);

  Future<void> _requestLocationPermission() async {
    final next = await ref
        .read(locationTrackingServiceProvider)
        .requestForegroundPermission();
    ref.read(fitnessPermissionProvider.notifier).state = next;
  }

  Future<void> _refreshPermissionState() async {
    final next =
        await ref.read(locationTrackingServiceProvider).checkPermissionState();
    if (mounted) {
      ref.read(fitnessPermissionProvider.notifier).state = next;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Activity Info Card — selected type summary
// ─────────────────────────────────────────────────────────────────────────────

class _ActivityInfoCard extends StatelessWidget {
  final FitnessActivityType type;

  const _ActivityInfoCard({required this.type});

  @override
  Widget build(BuildContext context) {
    return LiquidCard(
      frosted: true,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _accentFor(type).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(type.emoji, style: const TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type.displayName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: kInk,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (type.isGpsActivity) ...[
                      Icon(Icons.gps_fixed_rounded,
                          size: 12, color: kBlue.withValues(alpha: 0.7)),
                      const SizedBox(width: 4),
                      Text(
                        'GPS tracked',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: kBlue.withValues(alpha: 0.7),
                        ),
                      ),
                    ] else ...[
                      Icon(Icons.timer_rounded,
                          size: 12, color: kPurple.withValues(alpha: 0.7)),
                      const SizedBox(width: 4),
                      Text(
                        'Time-based',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: kPurple.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _accentFor(FitnessActivityType type) {
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
}

// ─────────────────────────────────────────────────────────────────────────────
// GPS Status Card — Phase 1 stub
// ─────────────────────────────────────────────────────────────────────────────

class _GpsStatusCard extends StatelessWidget {
  final bool isReady;
  final dynamic signalStrength;
  final VoidCallback onRequestPermission;

  const _GpsStatusCard({
    required this.isReady,
    required this.signalStrength,
    required this.onRequestPermission,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidCard(
      frosted: true,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: kBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.gps_fixed_rounded,
              size: 20,
              color: kBlue.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GPS Tracking',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isReady ? kMint : kInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isReady
                      ? 'GPS is ready. Tracking starts only after you tap Start.'
                      : 'Location permission is needed to draw your route.',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: kSub.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                ),
                if (!isReady) ...[
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: onRequestPermission,
                    icon: const Icon(Icons.location_searching_rounded),
                    label: const Text('Enable location'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Swimming Config Card
// ─────────────────────────────────────────────────────────────────────────────

class _SwimmingConfigCard extends StatelessWidget {
  final bool isPoolSwimming;
  final int poolLength;
  final bool openWaterGpsEnabled;
  final ValueChanged<bool> onPoolToggle;
  final ValueChanged<bool> onOpenWaterGpsChanged;
  final ValueChanged<int> onPoolLengthChanged;

  const _SwimmingConfigCard({
    required this.isPoolSwimming,
    required this.poolLength,
    required this.openWaterGpsEnabled,
    required this.onPoolToggle,
    required this.onOpenWaterGpsChanged,
    required this.onPoolLengthChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidCard(
      frosted: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Pool Swimming',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kInk,
                  ),
                ),
              ),
              LiquidToggle(
                value: isPoolSwimming,
                onChanged: onPoolToggle,
                activeColor: kBlue,
              ),
            ],
          ),
          if (isPoolSwimming) ...[
            const SizedBox(height: 14),
            Text(
              'Pool Length',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: kSub.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final len in [25, 50]) ...[
                  if (len == 50) const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onPoolLengthChanged(len);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: poolLength == len
                              ? kBlue
                              : kWhite.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: poolLength == len
                                ? kBlue.withValues(alpha: 0.6)
                                : kWhite.withValues(alpha: 0.9),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${len}m',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: poolLength == len ? kWhite : kInk,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ] else ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Record route when GPS is available',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: kSub.withValues(alpha: 0.78),
                    ),
                  ),
                ),
                LiquidToggle(
                  value: openWaterGpsEnabled,
                  onChanged: onOpenWaterGpsChanged,
                  activeColor: kBlue,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Manual distance is available after finish if route data is missing.',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: kSub.withValues(alpha: 0.66),
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GymCategoryCard extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _GymCategoryCard({
    required this.value,
    required this.onChanged,
  });

  static const _categories = [
    'General workout',
    'Strength',
    'Cardio',
    'Mobility',
  ];

  @override
  Widget build(BuildContext context) {
    return LiquidCard(
      frosted: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Workout Category',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: kInk,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in _categories)
                ChoiceChip(
                  label: Text(category),
                  selected: value == category,
                  selectedColor: kPurple.withValues(alpha: 0.2),
                  onSelected: (_) => onChanged(category),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
