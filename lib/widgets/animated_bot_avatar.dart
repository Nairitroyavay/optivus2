import 'dart:ui';
import 'package:flutter/material.dart';

class AnimatedBotAvatar extends StatelessWidget {
  const AnimatedBotAvatar({super.key});

  @override
  Widget build(BuildContext context) {
    const c = Color(0xFFFFEFA6); // Matches original circle colour
    const rim = Color(0xFFFFD54F); // Slightly darker yellow rim
    const light = Color(0xFFFFF9C4); // Very light yellow top

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(0.0, 0.15),
          radius: 0.90,
          colors: [
            light.withValues(alpha: 0.90),
            c.withValues(alpha: 0.95),
            rim,
          ],
          stops: const [0.0, 0.60, 1.0],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.5),
        boxShadow: [
          // Bouncy coloured underglow
          BoxShadow(
            color: const Color(0xFFFFD54F).withValues(alpha: 0.6),
            blurRadius: 18,
            offset: const Offset(0, 6),
            spreadRadius: -2,
          ),
          // Occlusion shadow
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          // Inner bright top rim (embossed glass effect)
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.85),
            blurRadius: 5,
            offset: const Offset(-2, -3),
          ),
        ],
      ),
      child: ClipOval(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Huge top-half shiny reflection
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                height: 24,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xDDFFFFFF), Color(0x00FFFFFF)],
                  ),
                ),
              ),
            ),
            // Tiny intense specular crescent highlight
            Positioned(
              top: 4, left: 8,
              child: Container(
                width: 14, height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xEEFFFFFF), Color(0x00FFFFFF)],
                  ),
                ),
              ),
            ),
            // The same bouncy animated bot
            const _AnimatedBotIcon(),
          ],
        ),
      ),
    );
  }
}
class _AnimatedBotIcon extends StatefulWidget {
  const _AnimatedBotIcon();

  @override
  State<_AnimatedBotIcon> createState() => _AnimatedBotIconState();
}

class _AnimatedBotIconState extends State<_AnimatedBotIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounceAnimation;
  late Animation<double> _moodAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      // 1.5 seconds for a full cycle (sad to happy and back)
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    // Bouncing up and down as it gets happy/sad
    _bounceAnimation = Tween<double>(begin: 0, end: -4).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutSine,
      ),
    );

    // 0.0 (sad) to 1.0 (happy)
    _moodAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _bounceAnimation.value),
          child: CustomPaint(
            size: const Size(26, 26),
            painter: _RobotPainter(_moodAnimation.value),
          ),
        );
      },
    );
  }
}

class _RobotPainter extends CustomPainter {
  final double animationValue;

  _RobotPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE5B500) // Bot gold/yellow color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);

    // Head
    final headWidth = size.width * 0.75;
    final headHeight = size.height * 0.65;
    final headCenter = center + Offset(0, size.height * 0.05);
    final headRect = Rect.fromCenter(center: headCenter, width: headWidth, height: headHeight);
    canvas.drawRRect(RRect.fromRectAndRadius(headRect, Radius.circular(size.width * 0.12)), paint);

    // Ears
    final earWidth = size.width * 0.15;
    final earHeight = size.height * 0.28;
    final leftEarRect = Rect.fromCenter(center: Offset(headRect.left - earWidth / 2 + 1, headCenter.dy), width: earWidth, height: earHeight);
    final rightEarRect = Rect.fromCenter(center: Offset(headRect.right + earWidth / 2 - 1, headCenter.dy), width: earWidth, height: earHeight);
    canvas.drawRRect(RRect.fromRectAndRadius(leftEarRect, Radius.circular(earWidth / 2)), paint);
    canvas.drawRRect(RRect.fromRectAndRadius(rightEarRect, Radius.circular(earWidth / 2)), paint);

    // Top parts (like gears/nodes)
    final nodeWidth = size.width * 0.16;
    final nodeHeight = size.height * 0.15;
    final nodeSpacing = size.width * 0.22;
    final nodeY = headRect.top - nodeHeight / 2 + 2;
    
    for (int i = -1; i <= 1; i++) {
       final nodeRect = Rect.fromCenter(
         center: Offset(headCenter.dx + (i * nodeSpacing), nodeY), 
         width: nodeWidth, 
         height: nodeHeight
       );
       canvas.drawRRect(RRect.fromRectAndRadius(nodeRect, Radius.circular(nodeWidth * 0.3)), paint);
    }

    // Cutout Paint for eyes and mouth
    final cutoutPaint = Paint()
      ..color = const Color(0xFFFFEFA6) // Circle background color to look like cutouts
      ..style = PaintingStyle.fill;
    
    // Eyes
    final eyeRadius = size.width * 0.08;
    // Eyes move slightly based on mood
    final eyeYOffset = lerpDouble(size.height * 0.02, -size.height * 0.02, animationValue)!;
    final eyeY = headCenter.dy - size.height * 0.1 + eyeYOffset;
    final eyeSpacing = size.width * 0.18;
    
    canvas.drawCircle(Offset(headCenter.dx - eyeSpacing, eyeY), eyeRadius, cutoutPaint);
    canvas.drawCircle(Offset(headCenter.dx + eyeSpacing, eyeY), eyeRadius, cutoutPaint);

    // Mouth
    final mouthPaint = Paint()
      ..color = const Color(0xFFFFEFA6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round;

    final mouthY = headCenter.dy + size.height * 0.12;
    final mouthWidth = size.width * 0.28;
    
    final path = Path();
    path.moveTo(headCenter.dx - mouthWidth / 2, mouthY);
    
    // Control point Y offset: negative for sad (up), positive for happy (down)
    final controlDy = lerpDouble(-size.height * 0.12, size.height * 0.15, animationValue)!;
    
    path.quadraticBezierTo(
      headCenter.dx, mouthY + controlDy, 
      headCenter.dx + mouthWidth / 2, mouthY
    );
    
    canvas.drawPath(path, mouthPaint);
  }

  @override
  bool shouldRepaint(covariant _RobotPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
