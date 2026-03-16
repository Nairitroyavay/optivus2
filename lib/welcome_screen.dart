import 'dart:ui';
import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import 'widgets/glass_logo.dart';
import 'widgets/app_button.dart';
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF6E6B4), // Soft warm golden hue
              Color(0xFFFCF8EE), // Extra light cream/off-white
            ],
            stops: [0.0, 0.5], // Fade evenly into white around middle
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 60),
                      const GlassLogo(),
                      const SizedBox(height: 28),

                      // Optivus Title
                      const Text(
                        'Optivus',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F111A), // Dark Navy/Black
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Yellow divider line
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD426), // Yellow accent
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Slogan
                      Text(
                        'PLAN. EXECUTE. BECOME.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.blueGrey.shade800,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 60),

                      // Feature Card (AI-Powered Coach) - Liquid Style
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F9FC).withValues(alpha: 0.35), // Glass background with #F4F9FC tint
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.8), // Shiny edge
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  blurRadius: 10,
                                  spreadRadius: -2,
                                  offset: const Offset(-2, -2),
                                ),
                              ],
                            ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFEFA6),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: _AnimatedBotIcon(),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'AI-Powered Coach',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Color(0xFF0F111A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Optimizing your daily workflow',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),

              // Get Started Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: AppButton(
                  text: 'Get Started',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SignupScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Log In Text
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Already have an account?",
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.only(bottom: 2), // space for underline
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Color(0xFFFFD426), // Yellow underline
                              width: 2.0,
                            ),
                          ),
                        ),
                        child: const Text(
                          'Log in',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Color(0xFF0F111A),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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

