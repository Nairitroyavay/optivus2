import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/models/habit_model.dart';
import 'package:optivus2/models/screen_time_log_model.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/widgets/app_button.dart';

class ScreenTimeTrackerView extends ConsumerStatefulWidget {
  final HabitModel habit;

  const ScreenTimeTrackerView({super.key, required this.habit});

  @override
  ConsumerState<ScreenTimeTrackerView> createState() => _ScreenTimeTrackerViewState();
}

class _ScreenTimeTrackerViewState extends ConsumerState<ScreenTimeTrackerView> {
  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(screenTimeImporterProvider).startForegroundSyncLoop();
      });
    }
  }

  @override
  void dispose() {
    // We don't stop the loop here because the user might still be in the app,
    // and tracker_tab.dart also relies on it. ScreenTimeImporter manages its own timer.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) {
      return const _UnsupportedPlatform();
    }

    final logAsync = ref.watch(screenTimeLogProvider);

    return logAsync.when(
      data: (log) {
        if (log == null) {
          return const _EmptyState();
        }
        return _Dashboard(log: log, accent: kBlue);
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator(color: kBlue)),
      ),
      error: (e, st) => Text('Error loading screen time: $e'),
    );
  }
}

class _UnsupportedPlatform extends StatelessWidget {
  const _UnsupportedPlatform();
  @override
  Widget build(BuildContext context) {
    return const LiquidCard(
      radius: 22,
      padding: EdgeInsets.all(16),
      child: Text('Screen time tracking is only supported on Android.'),
    );
  }
}

class _EmptyState extends ConsumerStatefulWidget {
  const _EmptyState();
  @override
  ConsumerState<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends ConsumerState<_EmptyState> {
  late Future<bool> _permFuture;

  @override
  void initState() {
    super.initState();
    _permFuture = ref.read(screenTimeImporterProvider).hasPermission();
  }

  void _recheckPerm() {
    setState(() {
      _permFuture = ref.read(screenTimeImporterProvider).hasPermission();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _permFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator(color: kBlue)),
          );
        }
        final hasPermission = snap.data ?? false;
        if (!hasPermission) {
          return _PermissionGate(onGranted: _recheckPerm);
        }
        return LiquidCard(
          radius: 22,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'No screen time data yet — sync starting…',
                style: TextStyle(color: kInk, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              LiquidButton(
                label: 'Sync Now',
                color: kBlue,
                onTap: () {
                  ref.read(screenTimeImporterProvider).sync();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Shown when the PACKAGE_USAGE_STATS permission has not yet been granted.
class _PermissionGate extends ConsumerWidget {
  final VoidCallback onGranted;

  const _PermissionGate({required this.onGranted});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LiquidCard(
      radius: 22,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.phone_android_rounded, color: kBlue, size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Usage Access Required',
                  style: TextStyle(
                    color: kInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Optivus needs the "Usage Access" permission to read your screen time. '
            'Your data stays on your device and in your private Firestore account — '
            'never shared.',
            style: TextStyle(
              color: kInk.withValues(alpha: 0.65),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          LiquidButton(
            label: 'Grant Access',
            color: kBlue,
            onTap: () async {
              await ref.read(screenTimeImporterProvider).requestPermission();
              // Re-check permission after the user returns from system settings.
              onGranted();
            },
          ),
        ],
      ),
    );
  }
}

class _Dashboard extends ConsumerWidget {
  final ScreenTimeLogModel log;
  final Color accent;

  const _Dashboard({required this.log, required this.accent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeroCard(log: log, accent: accent),
        const SizedBox(height: 14),
        if (log.crossingCount >= 2) ...[
          _CoachPrompt(accent: accent),
          const SizedBox(height: 14),
        ],
        if (log.hourlyDistribution.isNotEmpty) ...[
          _HourlyChart(distribution: log.hourlyDistribution, accent: accent),
          const SizedBox(height: 14),
        ],
        _TopAppsList(log: log, accent: accent),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final ScreenTimeLogModel log;
  final Color accent;

  const _HeroCard({required this.log, required this.accent});

  @override
  Widget build(BuildContext context) {
    final avg = log.weeklyAverage > 0 ? log.weeklyAverage : log.totalMinutes;
    final ratio = (log.totalMinutes / avg).clamp(0.0, 2.0);
    final isOver = log.totalMinutes > avg;

    return LiquidCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today\'s Screen Time',
            style: TextStyle(color: kInk, fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                log.formattedTotal,
                style: TextStyle(color: accent, fontSize: 24, fontWeight: FontWeight.w900),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${log.unlockCount} unlocks',
                    style: const TextStyle(color: kInk, fontWeight: FontWeight.bold),
                  ),
                  if (log.unlockHeuristicFlagged)
                    const Text(
                      'High unlock frequency',
                      style: TextStyle(color: kCoral, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                ],
              )
            ],
          ),
          const SizedBox(height: 16),
          // Comparison bar
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: kInk.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: (ratio / 2).clamp(0.05, 1.0),
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: isOver ? kCoral : accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isOver ? 'Over average' : 'Under average',
                style: TextStyle(
                  color: (isOver ? kCoral : kInk).withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Avg: ${log.weeklyAverage}m',
                style: TextStyle(
                  color: kInk.withValues(alpha: 0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HourlyChart extends StatelessWidget {
  final List<int> distribution;
  final Color accent;

  const _HourlyChart({required this.distribution, required this.accent});

  @override
  Widget build(BuildContext context) {
    final maxMins = distribution.isEmpty ? 1 : distribution.reduce((a, b) => a > b ? a : b).clamp(1, 60);
    return LiquidCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hourly Distribution',
            style: TextStyle(color: kInk, fontSize: 15, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 60,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (int i = 0; i < distribution.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Tooltip(
                        message: '${i % 12 == 0 ? 12 : i % 12}${i < 12 ? 'AM' : 'PM'} - ${distribution[i]}m',
                        child: FractionallySizedBox(
                          heightFactor: (distribution[i] / maxMins).clamp(0.05, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(2),
                            ),
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
    );
  }
}

class _TopAppsList extends ConsumerStatefulWidget {
  final ScreenTimeLogModel log;
  final Color accent;

  const _TopAppsList({required this.log, required this.accent});

  @override
  ConsumerState<_TopAppsList> createState() => _TopAppsListState();
}

class _TopAppsListState extends ConsumerState<_TopAppsList> {
  /// Package names whose cap-warning banner has been dismissed this session.
  /// Dismissal is local-only (no Firestore write, no event) — consistent with
  /// "Optivus does NOT hard-block apps."
  final Set<String> _dismissedCaps = {};

  @override
  Widget build(BuildContext context) {
    final log = widget.log;
    final accent = widget.accent;
    return LiquidCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top 5 Apps',
            style: TextStyle(color: kInk, fontSize: 15, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          for (final app in log.topApps.take(5))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app.appName,
                          style: const TextStyle(fontWeight: FontWeight.w800, color: kInk, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${app.minutes}m • ${app.unlockCount} unlocks',
                          style: TextStyle(color: kInk.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        if (log.appCaps[app.packageName] != null &&
                            app.minutes >= log.appCaps[app.packageName]! &&
                            !_dismissedCaps.contains(app.packageName))
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: kCoral, size: 14),
                                const SizedBox(width: 4),
                                const Text(
                                  'Cap crossed!',
                                  style: TextStyle(color: kCoral, fontSize: 11, fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(width: 12),
                                // Lock 1 hr — mutes notifications for the app for one hour.
                                InkWell(
                                  onTap: () async {
                                    await ref.read(screenTimeBridgeProvider).lockApp(app.packageName);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Notifications muted for ${app.appName} (1 hr)'),
                                          backgroundColor: accent,
                                        ),
                                      );
                                    }
                                  },
                                  child: Text(
                                    'Lock 1 hr',
                                    style: TextStyle(
                                      color: accent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Dismiss — collapses the warning for this session only.
                                InkWell(
                                  onTap: () {
                                    setState(() => _dismissedCaps.add(app.packageName));
                                  },
                                  child: Text(
                                    'Dismiss',
                                    style: TextStyle(
                                      color: kInk.withValues(alpha: 0.45),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  _CapEditor(
                    packageName: app.packageName,
                    currentCap: log.appCaps[app.packageName],
                    accent: accent,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CapEditor extends ConsumerStatefulWidget {
  final String packageName;
  final int? currentCap;
  final Color accent;

  const _CapEditor({
    required this.packageName,
    required this.currentCap,
    required this.accent,
  });

  @override
  ConsumerState<_CapEditor> createState() => _CapEditorState();
}

class _CapEditorState extends ConsumerState<_CapEditor> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
        text: widget.currentCap != null ? widget.currentCap.toString() : '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final val = int.tryParse(_controller.text);
    if (val != null && val >= 0) {
      ref.read(screenTimeImporterProvider).updateAppCap(widget.packageName, val);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cap updated')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 50,
          child: TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Cap(m)',
              isDense: true,
            ),
            style: const TextStyle(fontSize: 13),
          ),
        ),
        IconButton(
          icon: Icon(Icons.check, size: 18, color: widget.accent),
          onPressed: _save,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }
}

class _CoachPrompt extends StatelessWidget {
  final Color accent;

  const _CoachPrompt({required this.accent});

  @override
  Widget build(BuildContext context) {
    return LiquidCard(
      radius: 22,
      tint: kCoral.withValues(alpha: 0.1),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.chat_bubble_outline_rounded, color: kCoral),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Second cap crossed today. Want to talk about what\'s driving this?',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppButton(
            text: 'Talk to Coach',
            onPressed: () {
              // TODO(task-coach-nav): Replace snackbar with navigation to the
              // AI Coach tab once GoRouter route '/coach/screen-time' is wired.
              // Tracked in Task 7.3 / coach-tab navigation task.
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('AI Coach conversation initiated…')),
              );
            },
          ),
        ],
      ),
    );
  }
}
