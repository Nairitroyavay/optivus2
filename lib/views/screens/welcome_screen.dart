import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:optivus2/widgets/glass_logo.dart';
import 'package:optivus2/widgets/app_button.dart';
import 'package:optivus2/widgets/animated_bot_avatar.dart';
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
                            const AnimatedBotAvatar(),
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
                    context.go('/signup');
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
                        context.go('/login');
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

