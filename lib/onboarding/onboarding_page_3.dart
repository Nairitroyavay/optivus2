import 'package:flutter/material.dart';
import '../onboarding_screen.dart';

class OnboardingPage3 extends StatefulWidget {
  const OnboardingPage3({super.key});
  @override
  State<OnboardingPage3> createState() => _OnboardingPage3State();
}

class _OnboardingPage3State extends State<OnboardingPage3> {
  final Set<String> _selectedHabits = {'Gym', 'Reading'};

  Widget _buildHabitItem({required IconData icon, required String title, String? subtitle, double? progress}) {
    final isSelected = _selectedHabits.contains(title);
    return GestureDetector(
      onTap: () => setState(() { if (isSelected) _selectedHabits.remove(title); else _selectedHabits.add(title); }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: isSelected ? const Color(0xFF89F4DD) : Colors.transparent, width: 2),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 16, offset: const Offset(0, 5))],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(color: isSelected ? const Color(0xFFE0FDF7) : const Color(0xFFF3F4F6), shape: BoxShape.circle),
                  child: Icon(icon, color: isSelected ? const Color(0xFF0D9488) : const Color(0xFF6B7280), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF0F111A))),
                    if (isSelected && subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade400)),
                    ],
                  ]),
                ),
                Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? const Color(0xFF89F4DD) : Colors.transparent,
                    border: Border.all(color: isSelected ? Colors.transparent : const Color(0xFFD1D5DB), width: 2),
                  ),
                  child: isSelected ? const Icon(Icons.check, color: Color(0xFF0D3B30), size: 16) : null,
                ),
              ],
            ),
            if (isSelected && progress != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 5, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(3)),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft, widthFactor: progress / 100,
                        child: Container(decoration: BoxDecoration(color: const Color(0xFF89F4DD), borderRadius: BorderRadius.circular(3))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('${progress.toInt()}%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
                ],
              ),
            ],
          ],
        ),
      ),
    );
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
          RichText(text: const TextSpan(
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF0F111A), height: 1.15, letterSpacing: -1),
            children: [TextSpan(text: 'Build Good '), TextSpan(text: 'Habits', style: TextStyle(color: Color(0xFF0D9488)))],
          )),
          const SizedBox(height: 10),
          Text('Track these daily to build a better version of yourself.', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.blueGrey.shade600, height: 1.4)),
          const SizedBox(height: 24),
          _buildHabitItem(icon: Icons.fitness_center_rounded, title: 'Gym', subtitle: 'Daily Goal: 45m', progress: 65),
          _buildHabitItem(icon: Icons.code_rounded, title: 'Coding', subtitle: 'Daily Goal: 2h', progress: 30),
          _buildHabitItem(icon: Icons.menu_book_rounded, title: 'Reading', subtitle: 'Daily Goal: 30m', progress: 0),
          _buildHabitItem(icon: Icons.self_improvement_rounded, title: 'Meditation', subtitle: 'Daily Goal: 15m', progress: 0),
          _buildHabitItem(icon: Icons.edit_note_rounded, title: 'Journaling', subtitle: 'Daily Goal: 10m', progress: 0),
        ],
      ),
    );
  }
}
