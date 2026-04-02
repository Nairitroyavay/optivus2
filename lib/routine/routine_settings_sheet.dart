import 'package:flutter/material.dart';

import 'glass_filter_dropdown.dart';
import '../providers/routine_provider.dart';

const _kInk  = Color(0xFF0F111A);
const _kSub  = Color(0xFF6B7280);
const _kCard = Colors.white;
const _kShad = Color(0x0D000000);

class _SettingsOption {
  final String emoji;
  final String title;
  final String subtitle;
  final RoutineFilter? filter; // null = non-setup option
  const _SettingsOption({
    required this.emoji, required this.title,
    required this.subtitle, this.filter,
  });
}

const _options = [
  _SettingsOption(
    emoji: '🌿', title: 'Skin Care Routine',
    subtitle: 'Set up morning, afternoon & night steps',
    filter: RoutineFilter.skinCare,
  ),
  _SettingsOption(
    emoji: '🎓', title: 'Class Routine',
    subtitle: 'Upload or enter your class timetable',
    filter: RoutineFilter.classes,
  ),
  _SettingsOption(
    emoji: '🍽️', title: 'Eating Routine',
    subtitle: 'Plan your daily meals',
    filter: RoutineFilter.eating,
  ),
  _SettingsOption(
    emoji: '📅', title: 'Fixed Schedule',
    subtitle: 'Base daily activities, sleep & work',
    filter: RoutineFilter.fixedSchedule,
  ),
  _SettingsOption(
    emoji: '🔔', title: 'Notification Settings',
    subtitle: 'Reminders for each routine block',
  ),
  _SettingsOption(
    emoji: '📤', title: 'Export Schedule',
    subtitle: 'Save to calendar or share as PDF',
  ),
];

class RoutineSettingsSheet extends StatelessWidget {
  final Map<RoutineFilter, bool> setupDone;
  final void Function(RoutineFilter) onSetup;

  const RoutineSettingsSheet({
    super.key,
    required this.setupDone,
    required this.onSetup,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          // Handle bar
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: _kInk.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Routine Settings',
                  style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w900,
                    color: _kInk,
                  )),
            ),
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Set up or manage your routines',
                  style: TextStyle(fontSize: 13, color: _kSub)),
            ),
          ),
          const SizedBox(height: 16),

          // Option list
          ..._options.map((opt) {
            final isDone = opt.filter != null &&
                (setupDone[opt.filter] ?? false);
            return GestureDetector(
              onTap: () {
                if (opt.filter != null) onSetup(opt.filter!);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F5F0),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      // Icon
                      Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          color: _kCard,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(color: _kShad, blurRadius: 8,
                                offset: Offset(0, 2)),
                          ],
                        ),
                        child: Center(
                          child: Text(opt.emoji,
                              style: const TextStyle(fontSize: 20)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Text
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(opt.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: _kInk,
                                )),
                            const SizedBox(height: 2),
                            Text(opt.subtitle,
                                style: const TextStyle(
                                    fontSize: 12, color: _kSub)),
                          ],
                        ),
                      ),
                      // Done badge or chevron
                      if (isDone)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF60D4A0).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Done',
                              style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700,
                                color: Color(0xFF1A8A5A),
                              )),
                        )
                      else
                        const Icon(Icons.chevron_right_rounded,
                            color: _kSub, size: 20),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
