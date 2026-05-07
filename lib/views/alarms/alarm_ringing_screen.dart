import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import 'snooze_reason_sheet.dart';

const _kInk = Color(0xFF10131D);
const _kAmber = Color(0xFFFFB830);
const _kGreen = Color(0xFF22C55E);
const _kRed = Color(0xFFEF4444);

class AlarmRingingScreen extends StatefulWidget {
  final String notifId;
  final String title;
  final String? body;
  final String? taskId;
  final DateTime? scheduledFor;
  final List<int> snoozeDurations;
  final String soundAsset;
  final bool coachVoiceEnabled;
  final String coachVoiceAsset;
  final String vibrationPattern;
  final Future<void> Function()? onStart;
  final Future<void> Function(SnoozeReasonResult reason, int minutes)? onSnooze;
  final Future<void> Function(SnoozeReasonResult reason)? onSkip;

  const AlarmRingingScreen({
    super.key,
    required this.notifId,
    required this.title,
    this.body,
    this.taskId,
    this.scheduledFor,
    this.snoozeDurations = const [5, 10],
    this.soundAsset =
        'assets/audio/ambient_atmospheric/ambient_atmospheric_01.mp3',
    this.coachVoiceEnabled = true,
    this.coachVoiceAsset = 'assets/audio/healing_432hz/healing_432hz_01.mp3',
    this.vibrationPattern = 'standard',
    this.onStart,
    this.onSnooze,
    this.onSkip,
  });

  @override
  State<AlarmRingingScreen> createState() => _AlarmRingingScreenState();
}

class _AlarmRingingScreenState extends State<AlarmRingingScreen>
    with TickerProviderStateMixin {
  final _alarmPlayer = AudioPlayer();
  final _voicePlayer = AudioPlayer();
  Timer? _vibeTimer;
  bool _working = false;

  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    unawaited(_startAudio());
    _startVibration();
  }

  @override
  void dispose() {
    _vibeTimer?.cancel();
    _pulseCtrl.dispose();
    _alarmPlayer.dispose();
    _voicePlayer.dispose();
    super.dispose();
  }

  Future<void> _startAudio() async {
    try {
      await _alarmPlayer.setAsset(widget.soundAsset);
      await _alarmPlayer.setLoopMode(LoopMode.one);
      await _alarmPlayer.play();
    } catch (_) {
      // Alarm UX must remain usable even if an asset is missing.
    }

    if (!widget.coachVoiceEnabled) return;
    try {
      await _voicePlayer.setAsset(widget.coachVoiceAsset);
      await _voicePlayer.play();
    } catch (_) {}
  }

  void _startVibration() {
    if (widget.vibrationPattern == 'none') return;
    final period = switch (widget.vibrationPattern) {
      'urgent' => const Duration(milliseconds: 650),
      'pulse' => const Duration(milliseconds: 1200),
      _ => const Duration(milliseconds: 1800),
    };
    HapticFeedback.heavyImpact();
    _vibeTimer = Timer.periodic(period, (_) => HapticFeedback.heavyImpact());
  }

  Future<void> _stopFeedback() async {
    _vibeTimer?.cancel();
    await _alarmPlayer.stop();
    await _voicePlayer.stop();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await _stopFeedback();
      await action();
      if (mounted) Navigator.of(context).maybePop();
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _start() async {
    await _run(() async {
      await widget.onStart?.call();
    });
  }

  Future<void> _snooze() async {
    final reason = await SnoozeReasonSheet.show(
      context,
      title: 'Why snooze?',
      actionLabel: 'Snooze',
      snoozeDurations: widget.snoozeDurations,
    );
    if (reason == null || !mounted) return;
    final minutes = reason.snoozeMinutes ??
        (widget.snoozeDurations.isEmpty
            ? 5
            : widget.snoozeDurations.reduce((a, b) => a < b ? a : b));
    await _run(() async {
      await widget.onSnooze?.call(reason, minutes);
    });
  }

  Future<void> _skip() async {
    final reason = await SnoozeReasonSheet.show(
      context,
      title: 'Why skip?',
      actionLabel: 'Skip',
    );
    if (reason == null || !mounted) return;
    await _run(() async {
      await widget.onSkip?.call(reason);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _kInk,
        body: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(22, 20, 22, 22 + bottom),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: 'Skip',
                    onPressed: _working ? null : _skip,
                    icon: const Icon(Icons.close_rounded),
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
                const Spacer(),
                ScaleTransition(
                  scale: Tween<double>(begin: 0.96, end: 1.04).animate(
                    CurvedAnimation(
                      parent: _pulseCtrl,
                      curve: Curves.easeInOut,
                    ),
                  ),
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      color: _kAmber,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _kAmber.withValues(alpha: 0.42),
                          blurRadius: 38,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.alarm_rounded,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 34),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                if ((widget.body ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    widget.body!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.68),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: FilledButton.icon(
                    onPressed: _working ? null : _start,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _kGreen,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _working ? null : _snooze,
                        icon: const Icon(Icons.snooze_rounded),
                        label: const Text('Snooze'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _working ? null : _skip,
                        icon: const Icon(Icons.skip_next_rounded),
                        label: const Text('Skip'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kRed,
                          side: BorderSide(
                            color: _kRed.withValues(alpha: 0.44),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
