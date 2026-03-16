import 'package:flutter/material.dart';
import '../onboarding_screen.dart';

class OnboardingPage7 extends StatefulWidget {
  const OnboardingPage7({super.key});
  @override
  State<OnboardingPage7> createState() => _OnboardingPage7State();
}

class _OnboardingPage7State extends State<OnboardingPage7> {
  String _selectedCoach = 'Challenging';

  Widget _buildCoachCard({required String title, required String description, required String imageUrl, required bool isSelected}) {
    return GestureDetector(
      onTap: () => setState(() => _selectedCoach = title),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(isSelected ? 1.0 : 0.65),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: isSelected ? const Color(0xFF89F4DD) : Colors.transparent, width: 2),
          boxShadow: [if (!isSelected) BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 5))],
        ),
        child: Stack(
          children: [
            Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 68, height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: isSelected ? Border.all(color: const Color(0xFF89F4DD), width: 2.5) : null,
                  image: DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 10),
              Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isSelected ? const Color(0xFF0D6A58) : const Color(0xFF0F111A))),
              const SizedBox(height: 5),
              Text(description, textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: Colors.blueGrey.shade600, height: 1.4)),
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
            RichText(text: const TextSpan(
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF0F111A), height: 1.15, letterSpacing: -1),
              children: [TextSpan(text: 'Choose Your '), TextSpan(text: 'AI Coach', style: TextStyle(color: Color(0xFF3B82F6)))],
            )),
            const SizedBox(height: 10),
            Text('Select the personality that best fits your growth style.', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.blueGrey.shade600, height: 1.4)),
            const SizedBox(height: 24),
            GridView.count(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 0.85,
              children: [
                _buildCoachCard(title: 'Supportive', description: 'Gentle nudges and positive reinforcement.', imageUrl: 'https://i.pravatar.cc/150?img=47', isSelected: _selectedCoach == 'Supportive'),
                _buildCoachCard(title: 'Challenging', description: 'Tough love and high standards.', imageUrl: 'https://i.pravatar.cc/150?img=53', isSelected: _selectedCoach == 'Challenging'),
                _buildCoachCard(title: 'Calm', description: 'Mindful guidance to reduce stress.', imageUrl: 'https://i.pravatar.cc/150?img=34', isSelected: _selectedCoach == 'Calm'),
                _buildCoachCard(title: 'Strategic', description: 'Data-driven logic and efficiency.', imageUrl: 'https://i.pravatar.cc/150?img=60', isSelected: _selectedCoach == 'Strategic'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
