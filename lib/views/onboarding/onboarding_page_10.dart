import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus2/providers/onboarding_provider.dart';
import 'package:optivus2/views/screens/onboarding_screen.dart';

class OnboardingPage10 extends ConsumerWidget {
  const OnboardingPage10({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarding = ref.watch(onboardingProvider);
    final routine = _routinePreview(onboarding.fixedSchedule);
    final habits = _habitPreview(onboarding);
    final goals = _goalPreview(onboarding.goals);
    final isStarterPlan = onboarding.fixedSchedule
        .where((item) => (item['title']?.toString().trim() ?? '').isNotEmpty)
        .isEmpty;
    final top = MediaQuery.of(context).padding.top + kIndicatorOverlayH;
    final bottom = MediaQuery.of(context).padding.bottom + kButtonOverlayH;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, top + 16, 20, bottom + 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Today is ready',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F111A),
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isStarterPlan
                ? 'A minimal starter plan is set. You can tune it after your first day.'
                : 'Your fixed blocks, habits, goals, notifications, and coach setup are lined up.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 22),
          _PreviewPanel(
            icon: Icons.today_rounded,
            title: 'Today\'s Routine',
            accent: const Color(0xFF2563EB),
            child: Column(
              children: [
                for (var i = 0; i < routine.length; i++)
                  _RoutineRow(
                    time: _formatTime(routine[i]['startTime']),
                    title: routine[i]['title'] ?? 'Routine block',
                    isLast: i == routine.length - 1,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _PreviewPanel(
            icon: Icons.track_changes_rounded,
            title: 'Habit Focus',
            accent: const Color(0xFF059669),
            child: _ChipList(items: habits),
          ),
          const SizedBox(height: 12),
          _PreviewPanel(
            icon: Icons.flag_rounded,
            title: 'Top Goals',
            accent: const Color(0xFFF59E0B),
            child: _ChipList(items: goals),
          ),
          const SizedBox(height: 12),
          _PreviewPanel(
            icon: Icons.notifications_active_rounded,
            title: 'Notification Summary',
            accent: const Color(0xFF7C3AED),
            child: _SummaryText(
              text:
                  '${routine.length.clamp(1, 3)} starter reminders will be scheduled from today\'s routine, within the daily notification budget.',
            ),
          ),
          const SizedBox(height: 12),
          _PreviewPanel(
            icon: Icons.psychology_rounded,
            title: 'Coach Style',
            accent: const Color(0xFFDB2777),
            child: _SummaryText(
              text:
                  '${onboarding.coachStyle} coaching${onboarding.coachName.trim().isEmpty ? '' : ' with ${onboarding.coachName.trim()}'} and ${onboarding.accountabilityType.toLowerCase()} accountability.',
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, String>> _routinePreview(List<Map<String, dynamic>> raw) {
    final items = raw
        .where((item) => (item['title']?.toString().trim() ?? '').isNotEmpty)
        .map((item) => {
              'title': item['title']?.toString().trim() ?? '',
              'startTime': item['startTime']?.toString() ?? '09:00',
            })
        .toList()
      ..sort((a, b) => a['startTime']!.compareTo(b['startTime']!));

    if (items.isNotEmpty) return items;
    return const [
      {'title': 'Morning Focus', 'startTime': '09:00'},
      {'title': 'Habit Check-in', 'startTime': '13:00'},
      {'title': 'Evening Review', 'startTime': '20:30'},
    ];
  }

  List<String> _habitPreview(OnboardingState onboarding) {
    final habits = [
      ...onboarding.goodHabits,
      ...onboarding.badHabits,
    ].map((item) => item.replaceAll('\n', ' ').trim()).where((item) {
      return item.isNotEmpty;
    }).toList();
    return habits.isEmpty
        ? const ['Review daily plan']
        : habits.take(4).toList();
  }

  List<String> _goalPreview(List<String> raw) {
    final goals = raw
        .map((item) => item.replaceAll('\n', ' ').trim())
        .where((item) => item.isNotEmpty)
        .toList();
    return goals.isEmpty
        ? const ['Complete today with one finished block']
        : goals.take(3).toList();
  }

  String _formatTime(String? value) {
    final parts = (value ?? '09:00').split(':');
    final hour = int.tryParse(parts.first) ?? 9;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$hour12:${minute.toString().padLeft(2, '0')} $suffix';
  }
}

class _PreviewPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color accent;
  final Widget child;

  const _PreviewPanel({
    required this.icon,
    required this.title,
    required this.accent,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _RoutineRow extends StatelessWidget {
  final String time;
  final String title;
  final bool isLast;

  const _RoutineRow({
    required this.time,
    required this.title,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              time,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF2563EB),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipList extends StatelessWidget {
  final List<String> items;

  const _ChipList({required this.items});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              item,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
          ),
      ],
    );
  }
}

class _SummaryText extends StatelessWidget {
  final String text;

  const _SummaryText({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: Color(0xFF475569),
      ),
    );
  }
}
