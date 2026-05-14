import 'package:flutter/material.dart';
import 'package:optivus2/views/screens/onboarding_screen.dart';
import 'package:optivus2/widgets/liquid_glass_panel.dart';

class OnboardingPatienceTestPage extends StatelessWidget {
  const OnboardingPatienceTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top + kIndicatorOverlayH;
    final bottom = MediaQuery.of(context).padding.bottom + kButtonOverlayH;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(24, top + 24, 24, bottom + 24),
      child: LiquidGlassPanel(
        hasScrews: true,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Your first patience\ntest',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F111A),
                height: 1.15,
                letterSpacing: -1.0,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Optivus is a discipline and patience app. Before you enter the main app, complete every setup step honestly. This is your first test: do not skip the foundation if you want a better life.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.blueGrey.shade600,
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
