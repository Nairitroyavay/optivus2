import 'package:flutter/material.dart';
import '../onboarding_screen.dart';

class OnboardingPage6 extends StatefulWidget {
  const OnboardingPage6({super.key});
  @override
  State<OnboardingPage6> createState() => _OnboardingPage6State();
}

class _OnboardingPage6State extends State<OnboardingPage6> {
  final TextEditingController _nameController = TextEditingController();
  String get coachName => _nameController.text.trim().isEmpty ? 'Coach Arjun' : _nameController.text.trim();
  final List<String> _suggestions = ['Dad', 'Maa', 'Sensei', 'Bro', 'Sir'];

  @override
  void dispose() { _nameController.dispose(); super.dispose(); }

  Widget _buildChip(String text) {
    return GestureDetector(
      onTap: () => setState(() => _nameController.text = text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFFFDF8EB).withOpacity(0.8), borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
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
          const Text('What Should We\nCall Your Coach?', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF0F111A), height: 1.15, letterSpacing: -1)),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFF6B7280), width: 1), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 14, offset: const Offset(0, 5))]),
            child: TextField(
              controller: _nameController, onChanged: (v) => setState(() {}),
              decoration: const InputDecoration(border: InputBorder.none, hintText: 'Enter coach name...', hintStyle: TextStyle(color: Color(0xFF6B7280), fontSize: 17, fontWeight: FontWeight.w500), suffixIcon: Icon(Icons.edit, color: Color(0xFF9CA3AF), size: 18), suffixIconConstraints: BoxConstraints(minWidth: 18, minHeight: 18)),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
            ),
          ),
          const SizedBox(height: 28),
          Text('SUGGESTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.blueGrey.shade600, letterSpacing: 1.3)),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), clipBehavior: Clip.none,
            child: Row(children: [for (int i = 0; i < _suggestions.length; i++) ...[_buildChip(_suggestions[i]), if (i < _suggestions.length - 1) const SizedBox(width: 10)]]),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.55), borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withOpacity(0.80), width: 1.5),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 18, offset: const Offset(0, 10))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('PREVIEW', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.blueGrey.shade500, letterSpacing: 1.1)),
                Icon(Icons.visibility, color: Colors.blueGrey.shade400, size: 16),
              ]),
              const SizedBox(height: 18),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 44, height: 44, decoration: const BoxDecoration(color: Color(0xFF3B82F6), shape: BoxShape.circle), child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 22)),
                const SizedBox(width: 14),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: const BorderRadius.only(topRight: Radius.circular(18), bottomLeft: Radius.circular(18), bottomRight: Radius.circular(18)), border: Border.all(color: Colors.black.withOpacity(0.04), width: 1)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Good morning, Nairit.', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF1F2937))),
                      const SizedBox(height: 6),
                      Text('— $coachName', style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade500)),
                    ]),
                  ),
                ),
              ]),
            ]),
          ),
        ],
      ),
    );
  }
}
