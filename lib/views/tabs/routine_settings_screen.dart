import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/providers/routine_provider.dart';
import 'package:optivus2/views/routine/skin_care_setup_screen.dart';
import 'package:optivus2/views/routine/eating_setup_screen.dart';
import 'package:optivus2/views/routine/class_setup_screen.dart';
import 'package:optivus2/views/routine/fixed_schedule_setup_screen.dart';

class RoutineSettingsScreen extends ConsumerWidget {
  const RoutineSettingsScreen({super.key});

  void _doSetup(BuildContext context, WidgetRef ref, RoutineFilter f) {
    if (f == RoutineFilter.skinCare) {
      Navigator.push(context, slideRoute(SkinCareSetupScreen(onComplete: () {
        ref.read(routineProvider.notifier).markSkinCareSetUp();
      })));
    } else if (f == RoutineFilter.eating) {
      Navigator.push(context, slideRoute(EatingSetupScreen(
          onComplete: () {})));
    } else if (f == RoutineFilter.classes) {
      Navigator.push(context, slideRoute(ClassSetupScreen(onComplete: () {
        ref.read(routineProvider.notifier).setClasses(kDefaultClasses);
      })));
    } else if (f == RoutineFilter.fixedSchedule) {
      Navigator.push(context, slideRoute(FixedScheduleSetupScreen(onComplete: () {})));
    }
  }

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
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
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
                      
                      // Options Container
                      LiquidCard(
                        frosted: true,
                        padding: EdgeInsets.zero,
                        radius: 20,
                        child: Column(
                          children: [
                            _buildPrefTile(
                              emoji: '🌿',
                              title: 'Skin Care Routine',
                              subtitle: 'Set up morning, afternoon & night steps',
                              hasArrow: !s.skinCareSetUp,
                              isDone: s.skinCareSetUp,
                              onTap: () => _doSetup(context, ref, RoutineFilter.skinCare),
                            ),
                            _buildDivider(),
                            _buildPrefTile(
                              emoji: '🎓',
                              title: 'Class Routine',
                              subtitle: 'Upload or enter your class timetable',
                              hasArrow: !s.classesSetUp,
                              isDone: s.classesSetUp,
                              onTap: () => _doSetup(context, ref, RoutineFilter.classes),
                            ),
                            _buildDivider(),
                            _buildPrefTile(
                              emoji: '🍽️',
                              title: 'Eating Routine',
                              subtitle: 'Plan your daily meals',
                              hasArrow: !s.eatingSetUp,
                              isDone: s.eatingSetUp,
                              onTap: () => _doSetup(context, ref, RoutineFilter.eating),
                            ),
                            _buildDivider(),
                            _buildPrefTile(
                              emoji: '📅',
                              title: 'Fixed Schedule',
                              subtitle: 'Base daily activities, sleep & work',
                              hasArrow: !s.fixedScheduleSetUp,
                              isDone: s.fixedScheduleSetUp,
                              onTap: () => _doSetup(context, ref, RoutineFilter.fixedSchedule),
                            ),
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
                              hasArrow: true,
                              onTap: () {},
                            ),
                            _buildDivider(),
                            _buildPrefTile(
                              emoji: '📤',
                              title: 'Export Schedule',
                              subtitle: 'Save to calendar or share as PDF',
                              hasArrow: true,
                              onTap: () {},
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

  Widget _buildPrefTile({
    required String emoji,
    required String title,
    required String subtitle,
    bool hasArrow = false,
    bool isDone = false,
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
                  BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 2)),
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
            if (isDone)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
            else if (hasArrow)
              const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF6B7280)),
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
}
