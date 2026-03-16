import 'package:flutter/material.dart';
import '../onboarding_screen.dart';

class OnboardingPage9 extends StatelessWidget {
  const OnboardingPage9({super.key});

  Widget _buildSection({required Widget child}) {
    return Container(
      width: double.infinity, margin: const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.65), borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: child,
    );
  }

  Widget _buildTimelineItem({required String time, required String title, required bool isLast, required bool isActive}) {
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(width: 22, child: Column(children: [
          Container(width: 11, height: 11, margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(color: isActive ? const Color(0xFF3B82F6) : const Color(0xFFD1D5DB), shape: BoxShape.circle,
              border: Border.all(color: isActive ? const Color(0xFFEFF6FF) : Colors.transparent, width: 2))),
          if (!isLast) Expanded(child: Container(width: 2, color: const Color(0xFFE5E7EB))),
        ])),
        const SizedBox(width: 10),
        Expanded(child: Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(time, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F111A))),
            const SizedBox(height: 2),
            Text(title, style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade600)),
          ]),
        )),
      ]),
    );
  }

  Widget _buildGoalItem({required String title, required bool isCompleted}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(isCompleted ? Icons.check_circle : Icons.radio_button_unchecked, color: isCompleted ? const Color(0xFF3B82F6) : const Color(0xFF9CA3AF), size: 18),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
      ]),
    );
  }

  Widget _buildRadial({required IconData icon, required int percentage, required Color color, required String label}) {
    return Column(children: [
      SizedBox(width: 78, height: 78, child: Stack(fit: StackFit.expand, children: [
        CircularProgressIndicator(value: percentage / 100, strokeWidth: 7, backgroundColor: color.withOpacity(0.15), valueColor: AlwaysStoppedAnimation<Color>(color), strokeCap: StrokeCap.round),
        Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 2),
          Text('$percentage%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ]),
      ])),
      const SizedBox(height: 8),
      Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.blueGrey.shade600)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top + kIndicatorOverlayH;
    final bottom = MediaQuery.of(context).padding.bottom + kButtonOverlayH;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(24, top + 20, 24, bottom + 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your AI Plan is Ready', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF0F111A), height: 1.15, letterSpacing: -1)),
          const SizedBox(height: 10),
          Text('Based on your inputs, Optivus has designed your optimal flow.', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.blueGrey.shade700, height: 1.4)),
          const SizedBox(height: 20),

          _buildSection(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                Container(padding: const EdgeInsets.all(7), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.wb_sunny_rounded, color: Color(0xFF3B82F6), size: 16)),
                const SizedBox(width: 10),
                const Text('Daily Routine', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
              ]),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(16)),
                child: const Text('Preview', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF3B82F6))),
              ),
            ]),
            const SizedBox(height: 18),
            _buildTimelineItem(time: '07:00 AM', title: 'Deep Work Session', isLast: false, isActive: true),
            _buildTimelineItem(time: '08:30 AM', title: 'Team Sync & Planning', isLast: true, isActive: false),
          ])),

          _buildSection(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                Container(padding: const EdgeInsets.all(7), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.emoji_events_rounded, color: Color(0xFFF59E0B), size: 16)),
                const SizedBox(width: 10),
                const Text('Top 3 Goals', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
              ]),
              const Icon(Icons.flag_rounded, color: Color(0xFFE5E7EB), size: 28),
            ]),
            const SizedBox(height: 16),
            _buildGoalItem(title: 'Launch MVP Product', isCompleted: true),
            _buildGoalItem(title: 'Run 5k Marathon', isCompleted: false),
            _buildGoalItem(title: 'Read 2 books/mo', isCompleted: false),
          ])),

          _buildSection(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(7), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.data_usage_rounded, color: Color(0xFF10B981), size: 16)),
              const SizedBox(width: 10),
              const Text('Habit Focus', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
            ]),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _buildRadial(icon: Icons.nightlight_round, percentage: 75, color: const Color(0xFF3B82F6), label: 'Sleep'),
              _buildRadial(icon: Icons.fitness_center_rounded, percentage: 60, color: const Color(0xFF2ECA7F), label: 'Fitness'),
            ]),
          ])),
        ],
      ),
    );
  }
}
