import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:optivus2/providers/routine_provider.dart';

const _kInk = Color(0xFF0F111A);
const _kSub = Color(0xFF6B7280);
const _kCard = Colors.white;
const _kShad = Color(0x0D000000);

String _countLabel(RoutineState s, RoutineFilter filter) {
  switch (filter) {
    case RoutineFilter.fixedSchedule:
      final n = s.fixedScheduleTemplates.length;
      if (n == 0) return 'Not set up yet';
      return '$n block${n == 1 ? '' : 's'}';
    case RoutineFilter.skinCare:
      final nNew = (s.routineTemplates['skin_care'] ?? const []).length;
      if (nNew > 0) return '$nNew step${nNew == 1 ? '' : 's'}';
      if (!s.skinCareSetUp) return 'Not set up yet';
      final nLeg = s.skinCarePlans.fold<int>(
          0, (acc, d) => acc + d.morning.length + d.afternoon.length + d.night.length);
      return nLeg > 0 ? '$nLeg step${nLeg == 1 ? '' : 's'}' : 'Configured';
    case RoutineFilter.supplements:
      final n = (s.routineTemplates['supplements'] ?? const []).length;
      return n == 0 ? 'Not set up yet' : '$n supplement${n == 1 ? '' : 's'}';
    case RoutineFilter.classes:
      final nNew = (s.routineTemplates['classes'] ?? const []).length;
      if (nNew > 0) return '$nNew class${nNew == 1 ? '' : 'es'}';
      if (!s.classesSetUp) return 'Not set up yet';
      final nLeg = s.classes.length;
      return nLeg > 0 ? '$nLeg class${nLeg == 1 ? '' : 'es'}' : 'Configured';
    case RoutineFilter.eating:
      final nNew = (s.routineTemplates['eating'] ?? const []).length;
      if (nNew > 0) return '$nNew meal${nNew == 1 ? '' : 's'}';
      if (!s.eatingSetUp) return 'Not set up yet';
      final nLeg = s.mealPlans.fold<int>(0, (acc, d) => acc + d.meals.length);
      return nLeg > 0 ? '$nLeg meal${nLeg == 1 ? '' : 's'}' : 'Configured';
    default:
      return '';
  }
}

/// Each row in the settings list.
class _RoutineRow {
  final String emoji;
  final String title;
  final RoutineFilter filter;
  final String route;
  const _RoutineRow({
    required this.emoji,
    required this.title,
    required this.filter,
    required this.route,
  });
}

/// The five routine types, in canonical display order.
const _routineRows = [
  _RoutineRow(
    emoji: '📅',
    title: 'Fixed Schedule',
    filter: RoutineFilter.fixedSchedule,
    route: '/settings/fixed-schedule',
  ),
  _RoutineRow(
    emoji: '🌿',
    title: 'Skin Care Routine',
    filter: RoutineFilter.skinCare,
    route: '/settings/skin-care',
  ),
  _RoutineRow(
    emoji: '🎓',
    title: 'Class Routine',
    filter: RoutineFilter.classes,
    route: '/settings/classes',
  ),
  _RoutineRow(
    emoji: '💊',
    title: 'Supplements',
    filter: RoutineFilter.supplements,
    route: '/settings/supplements',
  ),
  _RoutineRow(
    emoji: '🍽️',
    title: 'Eating Routine',
    filter: RoutineFilter.eating,
    route: '/settings/eating',
  ),
];

class RoutineSettingsSheet extends ConsumerWidget {
  /// Legacy params kept for backward-compat with routine_tab.dart call site.
  final Map<RoutineFilter, bool> setupDone;
  final void Function(RoutineFilter) onSetup;

  const RoutineSettingsSheet({
    super.key,
    this.setupDone = const {},
    this.onSetup = _noOp,
  });

  static void _noOp(RoutineFilter _) {}

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(routineProvider);

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
            width: 36,
            height: 4,
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
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
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

          // ── Routine type rows ──────────────────────────────────────────
          ..._routineRows.map((row) {
            final subtitle = _countLabel(s, row.filter);
            final isConfigured = subtitle != 'Not set up yet';

            return GestureDetector(
              onTap: () {
                Navigator.pop(context); // dismiss sheet
                context.push(row.route);
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F5F0),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      // Emoji icon
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _kCard,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                                color: _kShad,
                                blurRadius: 8,
                                offset: Offset(0, 2)),
                          ],
                        ),
                        child: Center(
                          child: Text(row.emoji,
                              style: const TextStyle(fontSize: 20)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Title + count
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(row.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: _kInk,
                                )),
                            const SizedBox(height: 2),
                            Text(subtitle,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isConfigured
                                      ? const Color(0xFF1A8A5A)
                                      : _kSub,
                                  fontWeight: isConfigured
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                )),
                          ],
                        ),
                      ),
                      // Chevron
                      const Icon(Icons.chevron_right_rounded,
                          color: _kSub, size: 20),
                    ],
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 8),

          // ── Non-routine settings ───────────────────────────────────────
          _buildUtilityRow(
            emoji: '🔔',
            title: 'Notification Settings',
            subtitle: 'Reminders for each routine block',
          ),
          _buildUtilityRow(
            emoji: '📤',
            title: 'Export Schedule',
            subtitle: 'Save to calendar or share as PDF',
          ),
        ],
      ),
    );
  }

  Widget _buildUtilityRow({
    required String emoji,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F5F0),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                      color: _kShad, blurRadius: 8, offset: Offset(0, 2)),
                ],
              ),
              child:
                  Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _kInk,
                      )),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 12, color: _kSub)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _kSub, size: 20),
          ],
        ),
      ),
    );
  }
}
