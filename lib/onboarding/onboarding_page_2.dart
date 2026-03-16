import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../onboarding_screen.dart';

class OnboardingPage2 extends StatefulWidget {
  const OnboardingPage2({super.key});
  @override
  State<OnboardingPage2> createState() => _OnboardingPage2State();
}

class _OnboardingPage2State extends State<OnboardingPage2> {
  bool _cigarettes = false;
  bool _doomScrolling = true;
  bool _junkFood = false;
  bool _procrastination = false;

  Widget _buildHabitItem({required IconData icon, required Color iconColor, required Color bgColor, required String title, required bool value, required ValueChanged<bool> onChanged}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 16, offset: const Offset(0, 5))],
      ),
      child: Row(
        children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle), child: Icon(icon, color: iconColor, size: 22)),
          const SizedBox(width: 16),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF0F111A)))),
          CupertinoSwitch(value: value, activeColor: const Color(0xFF0D9488), trackColor: const Color(0xFFE5E7EB), onChanged: onChanged),
        ],
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
          const Text('Drop Bad Habits', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF0F111A), height: 1.15, letterSpacing: -1)),
          const SizedBox(height: 10),
          Text('Select habits you want Optivus to help you eliminate.', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.blueGrey.shade600, height: 1.4)),
          const SizedBox(height: 28),
          _buildHabitItem(icon: Icons.smoking_rooms_outlined, iconColor: const Color(0xFFEA580C), bgColor: const Color(0xFFFFF7ED), title: 'Cigarettes', value: _cigarettes, onChanged: (v) => setState(() => _cigarettes = v)),
          _buildHabitItem(icon: Icons.phone_iphone_rounded, iconColor: const Color(0xFF2563EB), bgColor: const Color(0xFFEFF6FF), title: 'Doom Scrolling', value: _doomScrolling, onChanged: (v) => setState(() => _doomScrolling = v)),
          _buildHabitItem(icon: Icons.fastfood_rounded, iconColor: const Color(0xFFD97706), bgColor: const Color(0xFFFEF3C7), title: 'Junk Food', value: _junkFood, onChanged: (v) => setState(() => _junkFood = v)),
          _buildHabitItem(icon: Icons.schedule_rounded, iconColor: const Color(0xFF7C3AED), bgColor: const Color(0xFFF5F3FF), title: 'Procrastination', value: _procrastination, onChanged: (v) => setState(() => _procrastination = v)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {},
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(28), border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5)),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(radius: 10, backgroundColor: Color(0xFF6B7280), child: Icon(Icons.add, color: Colors.white, size: 14)),
                  SizedBox(width: 8),
                  Text('Add Custom Habit', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
