import 'package:flutter/material.dart';
import '../onboarding_screen.dart';

class OnboardingPage8 extends StatelessWidget {
  const OnboardingPage8({super.key});

  Widget _buildTimeLabel(String hour, String ampm) {
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(hour, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
      Text(ampm, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF9CA3AF))),
    ]);
  }

  Widget _buildBlock({required double top, required double height, required String title, required String time, IconData? icon, Color? iconBg, Color? iconColor, bool simple = false}) {
    return Positioned(
      top: top, left: 48, right: 0,
      child: Container(
        height: height,
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: simple ? 0 : 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(simple ? 14 : 24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: simple
            ? Row(children: [
                Container(width: 3, margin: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: const Color(0xFF818CF8), borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 10),
                Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
                  Text(time, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF6B7280))),
                ]),
              ])
            : Row(children: [
                if (icon != null) ...[
                  Container(width: 38, height: 38, decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle), child: Icon(icon, color: iconColor, size: 18)),
                  const SizedBox(width: 10),
                ],
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
                  if (time.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(time, style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade500)),
                  ],
                ])),
                const Icon(Icons.drag_indicator_rounded, color: Color(0xFF9CA3AF), size: 16),
              ]),
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
            const Text('Set Your Fixed Schedule', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF0F111A), height: 1.15, letterSpacing: -1)),
            const SizedBox(height: 10),
            Text('Drag blocks to define your non-negotiables.', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.blueGrey.shade600, height: 1.4)),
            const SizedBox(height: 24),
            SizedBox(
              height: 520,
              child: Stack(
                children: [
                  Positioned(left: 24, top: 0, bottom: 0, child: Container(width: 1, color: const Color(0xFFF3F4F6))),
                  for (final e in [[0.0, '6', 'AM'], [90.0, '8', 'AM'], [180.0, '10', 'AM'], [270.0, '12', 'PM'], [360.0, '2', 'PM'], [450.0, '4', 'PM']])
                    Positioned(top: e[0] as double, left: 0, right: 0, child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                      SizedBox(width: 20, child: _buildTimeLabel(e[1] as String, e[2] as String)),
                      const SizedBox(width: 4),
                      Expanded(child: Container(height: 1, color: const Color(0xFFF3F4F6))),
                    ])),
                  _buildBlock(top: 0, height: 44, title: 'Sleep', time: 'Ends 6:30 AM', simple: true),
                  _buildBlock(top: 108, height: 100, title: 'Classes', time: '9:00 AM – 12:00 PM', icon: Icons.school_rounded, iconBg: const Color(0xFFEFF6FF), iconColor: const Color(0xFF3B82F6)),
                  _buildBlock(top: 258, height: 128, title: 'Work', time: '1:00 PM – 5:00 PM', icon: Icons.work_rounded, iconBg: const Color(0xFFFFFBEB), iconColor: const Color(0xFFD97706)),
                  _buildBlock(top: 440, height: 68, title: 'Gym', time: '', icon: Icons.fitness_center_rounded, iconBg: const Color(0xFFECFDF5), iconColor: const Color(0xFF10B981)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
