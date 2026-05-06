// lib/views/habits/variants/meditation_timer_screen.dart
//
// Full-screen meditation timer per UF §8.4.
// Features: animated breathing orb, pause/resume, mark-complete,
// pre/post mood sliders, type picker, interval bells (haptic).
// Returns result map on pop for dashboard to display.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/models/meditation_track_model.dart';

/// Meditation types offered in the pre-session picker.
const _kMeditationTypes = [
  'Mindfulness',
  'Breathing',
  'Body Scan',
  'Loving-Kindness',
  'Mantra',
  'Open Awareness',
  'Unguided',
];

/// Interval bell choices in minutes (0 = none).
const _kIntervalOptions = [0, 1, 5, 10];

/// Target duration options in minutes (0 = open ended).
const _kTargetOptions = [0, 5, 10, 15, 20, 30, 45, 60];

class MeditationTimerScreen extends ConsumerStatefulWidget {
  final String habitId;
  final String habitName;

  const MeditationTimerScreen({
    super.key,
    required this.habitId,
    required this.habitName,
  });

  @override
  ConsumerState<MeditationTimerScreen> createState() =>
      _MeditationTimerScreenState();
}

enum _Phase { setup, running, postSession }

class _MeditationTimerScreenState extends ConsumerState<MeditationTimerScreen>
    with TickerProviderStateMixin {
  // ── Setup state ──
  String _selectedType = _kMeditationTypes.first;
  bool _trackMood = true;
  int? _moodBefore = 5;
  int _intervalMin = 0;
  int _targetMin = 0;
  MeditationTrack? _selectedTrack;

  // ── Timer state ──
  _Phase _phase = _Phase.setup;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _tickTimer;
  int _elapsedSeconds = 0;
  bool _isPaused = false;
  int _lastBellAt = 0; // last interval bell fired at (seconds)

  // ── Breathing orb animation ──
  late final AnimationController _breathCtrl;

  // ── Post-session state ──
  int? _moodAfter = 5;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _breathCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    _initAudio();
  }

  Future<void> _initAudio() async {
    final service = ref.read(meditationAudioServiceProvider);
    await service.init();
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _breathCtrl.dispose();
    _stopwatch.stop();
    super.dispose();
  }

  // ── Timer control ──

  Future<void> _startTimer() async {
    setState(() => _phase = _Phase.running);
    _stopwatch.start();
    _breathCtrl.repeat();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedSeconds = _stopwatch.elapsed.inSeconds);
      _checkIntervalBell();
      _checkAutoComplete();
    });

    if (_selectedTrack != null &&
        await _selectedTrackAssetIsAvailable(_selectedTrack!)) {
      final audio = ref.read(meditationAudioServiceProvider);
      try {
        await audio.setTrack(_selectedTrack!);
        await audio.play();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading track: $e'),
              backgroundColor: kCoral,
            ),
          );
        }
      }
    }

    _playBell();
  }

  Future<bool> _selectedTrackAssetIsAvailable(MeditationTrack track) async {
    try {
      await rootBundle.load(track.assetPath);
      return true;
    } catch (_) {
      if (mounted) {
        setState(() => _selectedTrack = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Background sound unavailable. Starting silently.'),
            backgroundColor: kAmber,
          ),
        );
      }
      return false;
    }
  }

  void _togglePause() {
    final audio = ref.read(meditationAudioServiceProvider);
    if (_isPaused) {
      _stopwatch.start();
      _breathCtrl.repeat();
      if (_selectedTrack != null) audio.play();
    } else {
      _stopwatch.stop();
      _breathCtrl.stop();
      if (_selectedTrack != null) audio.pause();
    }
    setState(() => _isPaused = !_isPaused);
    HapticFeedback.mediumImpact();
  }

  void _markComplete() {
    if (_phase != _Phase.running) return;
    _stopwatch.stop();
    _tickTimer?.cancel();
    _breathCtrl.stop();
    ref.read(meditationAudioServiceProvider).stop();
    _playBell(end: true);
    setState(() {
      _moodAfter = _trackMood ? _moodBefore : null;
      _phase = _Phase.postSession;
    });
  }

  void _discardSession() {
    _tickTimer?.cancel();
    _stopwatch.stop();
    _breathCtrl.stop();
    ref.read(meditationAudioServiceProvider).stop();
    Navigator.pop(context);
  }

  void _playBell({bool end = false}) {
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();
    if (end) {
      Future.delayed(
        const Duration(milliseconds: 220),
        () => HapticFeedback.mediumImpact(),
      );
      Future.delayed(
        const Duration(milliseconds: 440),
        () => HapticFeedback.lightImpact(),
      );
    }
  }

  void _checkIntervalBell() {
    if (_intervalMin <= 0) return;
    final intervalSec = _intervalMin * 60;
    if (_elapsedSeconds > 0 &&
        _elapsedSeconds % intervalSec == 0 &&
        _elapsedSeconds != _lastBellAt) {
      _lastBellAt = _elapsedSeconds;
      SystemSound.play(SystemSoundType.click);
      HapticFeedback.mediumImpact();
    }
  }

  void _checkAutoComplete() {
    if (_targetMin <= 0) return;
    if (_elapsedSeconds >= _targetMin * 60) {
      _markComplete();
    }
  }

  Future<void> _saveAndClose() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final durationMin = (_elapsedSeconds / 60).ceil().clamp(1, 99999);

    try {
      final service = ref.read(habitServiceProvider);
      await service.logGood(
        widget.habitId,
        amount: durationMin,
        unit: 'min',
        durationSec: _elapsedSeconds,
        type: _selectedType,
        moodBefore: _moodBefore,
        moodAfter: _moodAfter,
        source: 'meditation_timer',
      );

      if (mounted) {
        Navigator.of(context).pop(<String, dynamic>{
          'durationSec': _elapsedSeconds,
          'type': _selectedType,
          'moodBefore': _moodBefore,
          'moodAfter': _moodAfter,
          if (_trackMood && _moodBefore != null && _moodAfter != null)
            'meditationLift': _moodAfter! - _moodBefore!,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: kCoral),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  // ── Format helpers ──

  String _formatTime(int totalSec) {
    final m = (totalSec ~/ 60).toString().padLeft(2, '0');
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _phase == _Phase.running ? const Color(0xFF0F111A) : kBg,
      body: SafeArea(
        child: switch (_phase) {
          _Phase.setup => _buildSetup(),
          _Phase.running => _buildTimer(),
          _Phase.postSession => _buildPostSession(),
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SETUP PHASE
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSetup() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Close button
          Align(
            alignment: Alignment.centerLeft,
            child: LiquidIconBtn(
              icon: Icons.close_rounded,
              onTap: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Prepare Your Session',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: kInk,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'No pressure on length — sit as long as feels right.',
            style: TextStyle(
              color: kSub.withValues(alpha: 0.75),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 28),

          // ── Type picker ──
          _sectionLabel('Meditation Type'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _kMeditationTypes
                .map((t) => LiquidChip(
                      label: t,
                      selected: _selectedType == t,
                      accentColor: kPurple,
                      onTap: () => setState(() => _selectedType = t),
                    ))
                .toList(),
          ),

          const SizedBox(height: 28),

          // ── Pre-session mood ──
          Row(
            children: [
              Expanded(child: _sectionLabel('Track mood lift')),
              Switch.adaptive(
                value: _trackMood,
                activeThumbColor: kPurple,
                activeTrackColor: kPurple.withValues(alpha: 0.25),
                onChanged: (value) {
                  setState(() {
                    _trackMood = value;
                    _moodBefore = value ? (_moodBefore ?? 5) : null;
                    _moodAfter =
                        value ? (_moodAfter ?? _moodBefore ?? 5) : null;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_trackMood)
            _MoodSlider(
              value: _moodBefore ?? 5,
              onChanged: (v) => setState(() => _moodBefore = v),
              accent: kPurple,
            )
          else
            const _MoodSkippedCard(),

          const SizedBox(height: 28),

          // ── Target Duration ──
          _sectionLabel('Target Duration'),
          const SizedBox(height: 10),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _kTargetOptions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final min = _kTargetOptions[i];
                final selected = _targetMin == min;
                final label = min == 0 ? 'Open' : '${min}m';
                return GestureDetector(
                  onTap: () => setState(() => _targetMin = min),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: selected ? kPurple : kWhite.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? kPurple.withValues(alpha: 0.6)
                            : kWhite.withValues(alpha: 0.9),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: selected ? kWhite : kInk,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 28),

          // ── Interval bells ──
          _sectionLabel('Interval Bells'),
          const SizedBox(height: 10),
          Row(
            children: _kIntervalOptions.map((min) {
              final label = min == 0 ? 'None' : '${min}m';
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: min == _kIntervalOptions.last ? 0 : 8,
                  ),
                  child: GestureDetector(
                    onTap: () => setState(() => _intervalMin = min),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _intervalMin == min
                            ? kPurple
                            : kWhite.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _intervalMin == min
                              ? kPurple.withValues(alpha: 0.6)
                              : kWhite.withValues(alpha: 0.9),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _intervalMin == min ? kWhite : kInk,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 28),

          // ── Music Selection (Categorized) ──
          _sectionLabel('Background Music'),
          const SizedBox(height: 10),
          StreamBuilder<List<MeditationTrack>>(
            stream: ref.watch(meditationAudioServiceProvider).watchTracks(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(
                    child: CircularProgressIndicator(color: kPurple));
              }

              final tracks = snapshot.data ?? [];
              if (tracks.isEmpty &&
                  snapshot.connectionState == ConnectionState.active) {
                return Text(
                  'No meditation tracks found. Check assets configuration.',
                  style: TextStyle(
                      color: kSub.withValues(alpha: 0.6), fontSize: 12),
                );
              }

              // Group tracks by subCategory
              final grouped = <String, List<MeditationTrack>>{};

              // Helper to get display name for subCategory
              String getSubCategoryName(String sub) {
                return switch (sub) {
                  'deep_healing' => '432 Hz / Deep Healing',
                  'om_mantra' => 'Om / Mantra Meditation',
                  'rain_sounds' => 'Rain Sounds',
                  'ocean_water' => 'Ocean / Water Sounds',
                  'forest_wind_birds' => 'Forest / Wind / Birds',
                  'ambient_meditation' => 'Ambient Meditation',
                  'deep_space_meditation' => 'Deep / Space Meditation',
                  'piano_meditation' => 'Piano Meditation',
                  _ => 'Other'
                };
              }

              for (final t in tracks) {
                final subName = getSubCategoryName(t.subCategory);
                grouped.putIfAbsent(subName, () => []).add(t);
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // "None" option
                  _TrackCard(
                    track: null,
                    selected: _selectedTrack == null,
                    onTap: () => setState(() => _selectedTrack = null),
                  ),
                  const SizedBox(height: 16),

                  // Groups
                  ...grouped.entries.map((entry) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12, top: 8),
                            child: Text(
                              entry.key,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: kInk.withValues(alpha: 0.8),
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 160,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: entry.value.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 14),
                              itemBuilder: (_, i) {
                                final track = entry.value[i];
                                final selected = _selectedTrack?.id == track.id;

                                return _TrackCard(
                                  track: track,
                                  selected: selected,
                                  onTap: () =>
                                      setState(() => _selectedTrack = track),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      )),
                ],
              );
            },
          ),

          const SizedBox(height: 36),

          // ── Begin button ──
          LiquidButton(
            label: 'Begin Meditation',
            color: kPurple,
            leading: const Icon(Icons.play_arrow_rounded, color: kWhite),
            onTap: _startTimer,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TIMER PHASE
  // ═══════════════════════════════════════════════════════════════

  Widget _buildTimer() {
    return Column(
      children: [
        // Top bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _confirmExit(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white54, size: 20),
                ),
              ),
              const Spacer(),
              Text(
                _selectedType,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              const SizedBox(width: 40),
            ],
          ),
        ),

        const Spacer(),

        // Elapsed time
        Text(
          _formatTime(_elapsedSeconds),
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w300,
            color: Colors.white.withValues(alpha: 0.85),
            letterSpacing: 4,
          ),
        ),

        const SizedBox(height: 32),

        // Breathing orb
        AnimatedBuilder(
          animation: _breathCtrl,
          builder: (_, __) {
            // 0→0.5 = inhale (grow), 0.5→1 = exhale (shrink)
            final t = _breathCtrl.value;
            final breathPhase = t < 0.5
                ? Curves.easeInOut.transform(t * 2)
                : Curves.easeInOut.transform(1 - (t - 0.5) * 2);
            final scale = 0.7 + 0.3 * breathPhase;
            final glowRadius = 40 + 30 * breathPhase;

            return Column(
              children: [
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color:
                            kPurple.withValues(alpha: 0.25 + 0.2 * breathPhase),
                        blurRadius: glowRadius,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            kPurple.withValues(alpha: 0.9),
                            kPurple.withValues(alpha: 0.4),
                            kPurple.withValues(alpha: 0.05),
                          ],
                          stops: const [0.0, 0.55, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  t < 0.5 ? 'Breathe in' : 'Breathe out',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            );
          },
        ),

        const Spacer(),

        // Music Control (Floating)
        if (_selectedTrack != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.music_note_rounded,
                      color: Colors.white.withValues(alpha: 0.4), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    _selectedTrack!.label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Controls
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pause / Resume
              GestureDetector(
                onTap: _togglePause,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Icon(
                    _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    color: Colors.white70,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              // Mark Complete
              GestureDetector(
                onTap: _elapsedSeconds >= 5 ? _markComplete : null,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _elapsedSeconds >= 5 ? 1 : 0.3,
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    decoration: BoxDecoration(
                      color: kPurple,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: kPurple.withValues(alpha: 0.4),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_rounded, color: kWhite, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Complete',
                          style: TextStyle(
                            color: kWhite,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmExit() {
    if (_elapsedSeconds < 5) {
      _discardSession();
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBg,
        title: const Text('End session?',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('You can save your progress or discard it.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Continue', style: TextStyle(color: kPurple)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _discardSession();
            },
            child: const Text('Discard', style: TextStyle(color: kSub)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _markComplete();
            },
            child: const Text('Save',
                style: TextStyle(color: kMint, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // POST-SESSION PHASE
  // ═══════════════════════════════════════════════════════════════

  Widget _buildPostSession() {
    final hasLift = _trackMood && _moodBefore != null && _moodAfter != null;
    final lift = hasLift ? _moodAfter! - _moodBefore! : 0;
    final liftColor = lift > 0
        ? kMint
        : lift < 0
            ? kCoral
            : kAmber;
    final liftEmoji = lift > 0
        ? '🌟'
        : lift < 0
            ? '🌧'
            : '☀️';
    final liftLabel = lift > 0
        ? '+$lift lift'
        : lift < 0
            ? '$lift'
            : 'Neutral';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          const Center(
            child: Text(
              '🧘',
              style: TextStyle(fontSize: 48),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Session Complete',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: kInk,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '${_formatTime(_elapsedSeconds)} • $_selectedType',
              style: TextStyle(
                color: kSub.withValues(alpha: 0.75),
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(height: 32),
          if (_trackMood) ...[
            // Post-session mood
            _sectionLabel('How do you feel now?'),
            const SizedBox(height: 10),
            _MoodSlider(
              value: _moodAfter ?? _moodBefore ?? 5,
              onChanged: (v) => setState(() => _moodAfter = v),
              accent: kPurple,
            ),
            const SizedBox(height: 28),
          ],
          if (hasLift)
            LiquidCard(
              tint: liftColor.withValues(alpha: 0.06),
              child: Row(
                children: [
                  Text(liftEmoji, style: const TextStyle(fontSize: 32)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Meditation Lift',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: kInk,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          liftLabel,
                          style: TextStyle(
                            color: liftColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Text('Before',
                          style: TextStyle(
                              fontSize: 11,
                              color: kSub.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w700)),
                      Text('$_moodBefore',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: kInk)),
                      const SizedBox(height: 4),
                      Text('After',
                          style: TextStyle(
                              fontSize: 11,
                              color: kSub.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w700)),
                      Text('$_moodAfter',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: liftColor)),
                    ],
                  ),
                ],
              ),
            )
          else
            const _MoodSkippedCard(),
          const SizedBox(height: 36),
          LiquidButton(
            label: _isSaving ? 'Saving…' : 'Save & Close',
            color: kPurple,
            leading: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: kWhite,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.check_rounded, color: kWhite),
            onTap: _isSaving ? null : _saveAndClose,
          ),
        ],
      ),
    );
  }

  // ── Shared widgets ──

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w900,
        color: kInk,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TRACK CARD — for music selection with offline support
// ═══════════════════════════════════════════════════════════════════════════════

class _TrackCard extends StatelessWidget {
  final MeditationTrack? track;
  final bool selected;
  final VoidCallback onTap;

  const _TrackCard({
    required this.track,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isNone = track == null;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 160,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? kPurple.withValues(alpha: 0.12)
              : kWhite.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? kPurple.withValues(alpha: 0.4)
                : kWhite.withValues(alpha: 0.9),
            width: 2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: kPurple.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: selected ? kPurple : kSub.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isNone
                        ? Icons.music_off_rounded
                        : (selected
                            ? Icons.play_arrow_rounded
                            : Icons.music_note_rounded),
                    color: selected ? kWhite : kSub,
                    size: 18,
                  ),
                ),
                if (!isNone && track!.isRoyaltyFree)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: kAmber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'FREE',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: kAmber,
                      ),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            if (isNone)
              const Center(
                child: Text(
                  'No Background',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: kSub,
                  ),
                ),
              )
            else ...[
              Text(
                track!.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: selected ? kPurple : kInk,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${track!.durationLabel ?? '??'} • ${track!.category.replaceAll('_', ' ')}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: kSub.withValues(alpha: 0.6),
                ),
              ),
              const Spacer(),

              // Available Status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: kMint.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, color: kMint, size: 10),
                    SizedBox(width: 2),
                    Text('READY',
                        style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: kMint)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MoodSlider extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final Color accent;

  const _MoodSlider({
    required this.value,
    required this.onChanged,
    required this.accent,
  });

  static const _emojis = [
    '😞',
    '😟',
    '😕',
    '😐',
    '🙂',
    '😊',
    '😄',
    '😁',
    '🤩',
    '🧘'
  ];

  @override
  Widget build(BuildContext context) {
    return LiquidCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _emojis[(value - 1).clamp(0, 9)],
                style: const TextStyle(fontSize: 28),
              ),
              const SizedBox(width: 12),
              Text(
                '$value / 10',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: accent,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: accent,
              inactiveTrackColor: accent.withValues(alpha: 0.15),
              thumbColor: accent,
              overlayColor: accent.withValues(alpha: 0.1),
              trackHeight: 6,
            ),
            child: Slider(
              value: value.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                onChanged(v.round());
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Low',
                  style: TextStyle(
                      fontSize: 11,
                      color: kSub.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w700)),
              Text('High',
                  style: TextStyle(
                      fontSize: 11,
                      color: kSub.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoodSkippedCard extends StatelessWidget {
  const _MoodSkippedCard();

  @override
  Widget build(BuildContext context) {
    return LiquidCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      tint: kSub.withValues(alpha: 0.04),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: kSub.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.remove_red_eye_outlined,
              color: kSub.withValues(alpha: 0.7),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Mood tracking skipped',
              style: TextStyle(
                color: kSub.withValues(alpha: 0.75),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
