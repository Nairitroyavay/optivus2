import 'package:flutter/material.dart';
import '../onboarding_screen.dart';

class OnboardingPage5 extends StatefulWidget {
  const OnboardingPage5({super.key});
  @override
  State<OnboardingPage5> createState() => _OnboardingPage5State();
}

class _OnboardingPage5State extends State<OnboardingPage5> {
  String _selectedCoach = 'Father';

  Widget _buildCoachCard({required IconData icon, required String title, required String subtitle, required bool isSelected}) {
    return GestureDetector(
      onTap: () => setState(() => _selectedCoach = title),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE0FDF7) : Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isSelected ? const Color(0xFF89F4DD) : Colors.transparent, width: 1.5),
          boxShadow: [if (!isSelected) BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Stack(
          children: [
            Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 3))]),
                  child: Icon(icon, color: const Color(0xFF1E293B), size: 22),
                ),
                const SizedBox(height: 10),
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F111A))),
                const SizedBox(height: 3),
                Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.blueGrey.shade600)),
              ]),
            ),
            if (isSelected) const Positioned(top: 0, right: 0, child: Icon(Icons.check_circle, color: Color(0xFF0D9488), size: 20)),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomCard({required bool isSelected}) {
    return GestureDetector(
      onTap: () => setState(() => _selectedCoach = 'Custom'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE0FDF7) : Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isSelected ? const Color(0xFF89F4DD) : Colors.transparent, width: 1.5),
          boxShadow: [if (!isSelected) BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Stack(
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.edit_note_rounded, color: Color(0xFF1E293B), size: 18),
                SizedBox(width: 6),
                Text('Custom', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F111A))),
              ]),
              const SizedBox(height: 10),
              Expanded(
                child: TextField(
                  enabled: isSelected, maxLines: null, maxLength: 100,
                  decoration: InputDecoration(
                    border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero, counterText: '',
                    hintText: 'Describe your ideal relationship...', hintStyle: TextStyle(fontSize: 12, color: Colors.blueGrey.shade400, height: 1.4),
                  ),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF0F111A), height: 1.4),
                ),
              ),
            ]),
            if (isSelected) const Positioned(top: 0, right: 0, child: Icon(Icons.check_circle, color: Color(0xFF0D9488), size: 20)),
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
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, top + 20, 24, bottom + 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('How Should Your\nCoach Guide You?', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF0F111A), height: 1.15, letterSpacing: -1)),
            const SizedBox(height: 10),
            Text('Select the personality that fits your goals.', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.blueGrey.shade700, height: 1.4)),
            const SizedBox(height: 24),
            GridView.count(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 1.0,
              children: [
                _buildCoachCard(icon: Icons.shield_rounded, title: 'Father', subtitle: 'Protective & Wise', isSelected: _selectedCoach == 'Father'),
                _buildCoachCard(icon: Icons.volunteer_activism_rounded, title: 'Mother', subtitle: 'Nurturing & Kind', isSelected: _selectedCoach == 'Mother'),
                _buildCoachCard(icon: Icons.handshake_rounded, title: 'Uncle', subtitle: 'Casual & Direct', isSelected: _selectedCoach == 'Uncle'),
                _buildCoachCard(icon: Icons.people_alt_rounded, title: 'Friend', subtitle: 'Supportive Peer', isSelected: _selectedCoach == 'Friend'),
                _buildCoachCard(icon: Icons.school_rounded, title: 'Teacher', subtitle: 'Strict & Driven', isSelected: _selectedCoach == 'Teacher'),
                _buildCustomCard(isSelected: _selectedCoach == 'Custom'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
