// lib/views/fitness/fitness_settings_screen.dart
//
// Fitness settings — unit preferences, heart rate zones,
// Health Connect toggle (stub), AI feedback toggle, data export.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/core/providers.dart';

class FitnessSettingsScreen extends ConsumerStatefulWidget {
  const FitnessSettingsScreen({super.key});

  @override
  ConsumerState<FitnessSettingsScreen> createState() =>
      _FitnessSettingsScreenState();
}

class _FitnessSettingsScreenState
    extends ConsumerState<FitnessSettingsScreen> {
  bool _useMetric = true;
  bool _aiCoachEnabled = true;
  bool _healthConnected = false;

  // Heart rate zones (default 5-zone model)
  final _zones = <String, (int, int)>{
    'Zone 1 (Recovery)': (100, 120),
    'Zone 2 (Endurance)': (120, 140),
    'Zone 3 (Tempo)': (140, 160),
    'Zone 4 (Threshold)': (160, 175),
    'Zone 5 (Max)': (175, 200),
  };

  @override
  Widget build(BuildContext context) {
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
                    const Expanded(
                      child: Text(
                        'Fitness Settings',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: kInk,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Body ──
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Units
                      _SectionHeader(title: 'Units'),
                      LiquidCard(
                        frosted: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4,
                        ),
                        child: Column(
                          children: [
                            _ToggleRow(
                              label: 'Distance',
                              value: _useMetric ? 'Kilometres' : 'Miles',
                              onTap: () =>
                                  setState(() => _useMetric = !_useMetric),
                            ),
                            Divider(
                              height: 1,
                              color: kSub.withValues(alpha: 0.1),
                            ),
                            _ToggleRow(
                              label: 'Weight',
                              value: _useMetric ? 'Kilograms' : 'Pounds',
                              onTap: () =>
                                  setState(() => _useMetric = !_useMetric),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Heart rate zones
                      _SectionHeader(title: 'Heart Rate Zones'),
                      LiquidCard(
                        frosted: true,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: _zones.entries.map((e) {
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      e.key,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: kSub.withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${e.value.$1} – ${e.value.$2} bpm',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: kInk,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Health Connect
                      _SectionHeader(title: 'Health Integration'),
                      LiquidCard(
                        frosted: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4,
                        ),
                        child: _SwitchRow(
                          label: 'Health Connect / HealthKit',
                          subtitle: _healthConnected
                              ? 'Connected'
                              : 'Not connected (stub)',
                          value: _healthConnected,
                          onChanged: (v) async {
                            final connector = ref.read(
                              fitnessHealthConnectorServiceProvider,
                            );
                            if (v) {
                              await connector.requestPermissions();
                            } else {
                              await connector.disconnect();
                            }
                            setState(() => _healthConnected = v);
                          },
                        ),
                      ),

                      const SizedBox(height: 20),

                      // AI Coach
                      _SectionHeader(title: 'AI Coach'),
                      LiquidCard(
                        frosted: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4,
                        ),
                        child: _SwitchRow(
                          label: 'Post-activity feedback',
                          subtitle: 'Get AI insights after each workout',
                          value: _aiCoachEnabled,
                          onChanged: (v) =>
                              setState(() => _aiCoachEnabled = v),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Data
                      _SectionHeader(title: 'Data'),
                      LiquidCard(
                        frosted: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4,
                        ),
                        child: _ActionRow(
                          label: 'Export fitness data',
                          icon: Icons.download_rounded,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Export will be available in a future update.',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
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
// Helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: kSub.withValues(alpha: 0.5),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: kInk,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: kBlue.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: kSub.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: kMint,
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionRow({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: kBlue, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: kInk,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right_rounded,
              color: kSub.withValues(alpha: 0.4),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
