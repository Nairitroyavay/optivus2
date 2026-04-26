import 'package:flutter/material.dart';

class BotAvatarOrb extends StatelessWidget {
  const BotAvatarOrb({super.key});

  @override
  Widget build(BuildContext context) {
    const c = Color(0xFF3B82F6);
    const rim = Color(0xFF1D4ED8);
    const light = Color(0xFF93C5FD);

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(0.0, 0.15),
          radius: 0.90,
          colors: [
            light.withValues(alpha: 0.60),
            c.withValues(alpha: 0.92),
            rim,
          ],
          stops: const [0.0, 0.60, 1.0],
        ),
        border: Border.all(color: rim.withValues(alpha: 0.75), width: 2.2),
        boxShadow: [
          BoxShadow(color: c.withValues(alpha: 0.45), blurRadius: 22, offset: const Offset(0, 6), spreadRadius: -2),
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 10, offset: const Offset(0, 4)),
          BoxShadow(color: Colors.white.withValues(alpha: 0.70), blurRadius: 5, offset: const Offset(-2, -3)),
        ],
      ),
      child: ClipOval(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                height: 24,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xCCFFFFFF), Color(0x00FFFFFF)],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 5, left: 8,
              child: Container(
                width: 14, height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0xEEFFFFFF), Color(0x00FFFFFF)],
                  ),
                ),
              ),
            ),
            Icon(Icons.smart_toy_rounded, size: 22, color: Colors.white,
              shadows: [Shadow(color: rim.withValues(alpha: 0.55), blurRadius: 4)]),
          ],
        ),
      ),
    );
  }
}
