import 'package:flutter/material.dart';
import '../onboarding_screen.dart';

class OnboardingPage4 extends StatefulWidget {
  const OnboardingPage4({super.key});
  @override
  State<OnboardingPage4> createState() => _OnboardingPage4State();
}

class _OnboardingPage4State extends State<OnboardingPage4> {
  final Set<String> _selectedIdentities = {'Build strong body', 'Find inner peace'};

  Widget _buildChip({required IconData icon, required String title}) {
    final isSelected = _selectedIdentities.contains(title);
    return GestureDetector(
      onTap: () => setState(() { if (isSelected) _selectedIdentities.remove(title); else _selectedIdentities.add(title); }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE0FDF7) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: isSelected ? const Color(0xFF89F4DD) : Colors.transparent, width: 1.5),
          boxShadow: [if (!isSelected) BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? const Color(0xFF0D9488) : const Color(0xFF6B7280)),
            const SizedBox(width: 7),
            Text(title, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600, color: const Color(0xFF1F2937))),
            if (isSelected) ...[const SizedBox(width: 6), const Icon(Icons.check_circle, size: 15, color: Color(0xFF0D9488))],
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
            children: [TextSpan(text: 'Long-Term\n'), TextSpan(text: 'Identity Goals', style: TextStyle(color: Color(0xFFD97706)))],
          )),
          const SizedBox(height: 10),
          Text('Select the identities you want to embody.', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.blueGrey.shade600, height: 1.4)),
          const SizedBox(height: 24),
          Wrap(spacing: 10, runSpacing: 12, children: [
            _buildChip(icon: Icons.account_balance_wallet_rounded, title: 'Become financially free'),
            _buildChip(icon: Icons.fitness_center_rounded, title: 'Build strong body'),
            _buildChip(icon: Icons.self_improvement_rounded, title: 'Become disciplined'),
            _buildChip(icon: Icons.translate_rounded, title: 'Master a new language'),
            _buildChip(icon: Icons.rocket_launch_rounded, title: 'Start a business'),
            _buildChip(icon: Icons.spa_rounded, title: 'Find inner peace'),
            _buildChip(icon: Icons.favorite_rounded, title: 'Be a better partner'),
            _buildChip(icon: Icons.public_rounded, title: 'Travel the world'),
            _buildChip(icon: Icons.menu_book_rounded, title: 'Read 20 books'),
          ]),
          const SizedBox(height: 28),
          const Text('Add your own', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26), border: Border.all(color: const Color(0xFF6B7280), width: 1)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: const TextField(
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Type a custom goal...',
                hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
