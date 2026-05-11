import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/providers/routine_provider.dart';

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
          0,
          (acc, d) =>
              acc + d.morning.length + d.afternoon.length + d.night.length);
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

/// Row descriptor for each routine type (canonical order shared with the
/// bottom-sheet in routine_settings_sheet.dart).
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

class RoutineSettingsScreen extends ConsumerWidget {
  const RoutineSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(routineProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidBg(
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header with back navigation button
                      _buildHeader(context),
                      const SizedBox(height: 32),

                      // Heading
                      Text(
                        'MANAGE ROUTINES',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: kSub.withValues(alpha: 0.8),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Routine rows — canonical order
                      LiquidCard(
                        frosted: true,
                        padding: EdgeInsets.zero,
                        radius: 20,
                        child: Column(
                          children: [
                            for (int i = 0; i < _routineRows.length; i++) ...[
                              if (i > 0) _buildDivider(),
                              _buildRoutineTile(
                                context,
                                row: _routineRows[i],
                                subtitle:
                                    _countLabel(s, _routineRows[i].filter),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
                      Text(
                        'SETTINGS & EXPORT',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: kSub.withValues(alpha: 0.8),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      LiquidCard(
                        frosted: true,
                        padding: EdgeInsets.zero,
                        radius: 20,
                        child: Column(
                          children: [
                            _buildPrefTile(
                              emoji: '🔔',
                              title: 'Notification Settings',
                              subtitle: 'Reminders for each routine block',
                              onTap: () =>
                                  context.push('/settings/notifications'),
                            ),
                            _buildDivider(),
                            _buildPrefTile(
                              emoji: '📤',
                              title: 'Export Schedule',
                              subtitle: 'Save to calendar or share as PDF',
                              onTap: () => _showExportDeferred(context),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),
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

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        LiquidIconBtn(
          icon: Icons.arrow_back_ios_new_rounded,
          size: 44,
          onTap: () {
            Navigator.pop(context); // Go back to profile tab
          },
        ),
        const Text(
          'ROUTINE SETTINGS',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: kSub,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(width: 44),
      ],
    );
  }

  /// Builds a routine-type tile with icon, name, count, and chevron.
  Widget _buildRoutineTile(
    BuildContext context, {
    required _RoutineRow row,
    required String subtitle,
  }) {
    final isConfigured = subtitle != 'Not set up yet';

    return InkWell(
      onTap: () => context.push(row.route),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x0D000000),
                      blurRadius: 8,
                      offset: Offset(0, 2)),
                ],
              ),
              child: Center(
                child: Text(row.emoji, style: const TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F111A), // kInk
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isConfigured
                          ? const Color(0xFF1A8A5A)
                          : const Color(0xFF6B7280),
                      fontWeight:
                          isConfigured ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            if (isConfigured)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF60D4A0).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Done',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A8A5A),
                    )),
              ),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: Color(0xFF6B7280)),
          ],
        ),
      ),
    );
  }

  Widget _buildPrefTile({
    required String emoji,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x0D000000),
                      blurRadius: 8,
                      offset: Offset(0, 2)),
                ],
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F111A), // kInk
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280), // kSub
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: Color(0xFF6B7280)),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      color: Colors.white.withValues(alpha: 0.3),
      margin: const EdgeInsets.symmetric(horizontal: 20),
    );
  }

  void _showExportDeferred(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E202A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Schedule export',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Calendar/PDF export is deferred for MVP testing. Routine data is still saved in Firestore and account export is available from Profile.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
