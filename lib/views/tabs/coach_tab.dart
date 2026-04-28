import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:optivus2/services/firestore_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus2/providers/onboarding_provider.dart';
import 'package:optivus2/services/gemini_service.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────

class _CoachMessage {
  final String text;
  final bool isUser;
  _CoachMessage({required this.text, required this.isUser});
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared Constants & Geometry
// ─────────────────────────────────────────────────────────────────────────────

const double _kR = 24.0;
const double _kTailW = 32.0;
const double _kTailH = 22.0;
const double _kTailX = 26.0;

Path _buildBubblePath(Size size, {required bool isUser}) {
  final w = size.width;
  final bH = size.height - _kTailH;
  final r = _kR;

  // Tail geometry
  final double tailEdgeOffset = isUser ? w - _kTailX : _kTailX;
  final double tailTipX = isUser ? tailEdgeOffset + _kTailW * 0.5 : tailEdgeOffset - _kTailW * 0.5;

  final p = Path();

  // Top-left
  p.moveTo(r, 0);
  p.lineTo(w - r, 0);
  // Top-right
  p.quadraticBezierTo(w, 0, w, r);
  p.lineTo(w, bH - r);
  // Bottom-right
  p.quadraticBezierTo(w, bH, w - r, bH);

  if (isUser) {
    p.lineTo(tailEdgeOffset, bH);
    // User tail (bottom-right pointing down-right)
    p.cubicTo(
      tailEdgeOffset + 2, bH,
      tailTipX - 2, bH + _kTailH * 0.8,
      tailTipX, bH + _kTailH,
    );
    p.cubicTo(
      tailTipX - 10, bH + _kTailH * 0.5,
      tailEdgeOffset - _kTailW + 8, bH,
      tailEdgeOffset - _kTailW, bH,
    );
    p.lineTo(r, bH);
  } else {
    p.lineTo(tailEdgeOffset + _kTailW, bH);
    // AI tail (bottom-left pointing down-left)
    p.cubicTo(
      tailEdgeOffset + _kTailW - 8, bH,
      tailTipX + 10, bH + _kTailH * 0.5,
      tailTipX, bH + _kTailH,
    );
    p.cubicTo(
      tailTipX + 2, bH + _kTailH * 0.8,
      tailEdgeOffset - 2, bH,
      tailEdgeOffset, bH,
    );
    p.lineTo(r, bH);
  }

  // Bottom-left
  p.quadraticBezierTo(0, bH, 0, bH - r);
  p.lineTo(0, r);
  p.quadraticBezierTo(0, 0, r, 0);
  p.close();

  return p;
}

// ─────────────────────────────────────────────────────────────────────────────
// Heavy 3D Liquid Glass Painter
// ─────────────────────────────────────────────────────────────────────────────

class _BubbleShadowPainter extends CustomPainter {
  final bool isUser;
  const _BubbleShadowPainter({required this.isUser});

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildBubblePath(size, isUser: isUser);
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.12), 12, true);
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.04), 4, true);
  }

  @override
  bool shouldRepaint(covariant _BubbleShadowPainter old) => old.isUser != isUser;
}

class _HeavyGlassPainter extends CustomPainter {
  final bool isUser;
  const _HeavyGlassPainter({required this.isUser});

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildBubblePath(size, isUser: isUser);
    final rect = Offset.zero & size;

    canvas.save();
    canvas.clipPath(path);

    // ── 1. The Glass Tube Refraction Edge (Double Line) ──
    canvas.saveLayer(rect, Paint());

    // Inner bright/dark rim
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14.0 // extends 7px inside
        ..strokeJoin = StrokeJoin.round
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.95), // hot white reflection
            Colors.white.withValues(alpha: 0.5),  // solid glass body transiton
            Colors.black.withValues(alpha: 0.2),  // soft shadow wrapping
            Colors.black.withValues(alpha: 0.4),  // deep inner shadow bottom-right
          ],
          stops: const [0.0, 0.4, 0.7, 1.0],
        ).createShader(rect),
    );

    // Clear the center to hollow out the tube, leaving a 3px band (from 4px to 7px inward)
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.0 // clears 0 to 4px inside
        ..strokeJoin = StrokeJoin.round
        ..blendMode = BlendMode.clear
        ..color = Colors.black,
    );

    // Light frosting in the middle gap (from 0 to 4px inward)
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.0
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white.withValues(alpha: 0.1),
    );

    // Sharp outer rim defining the very edge (from 0 to 1.5px inward)
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeJoin = StrokeJoin.round
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 1.0), // intense hot spot
            Colors.white.withValues(alpha: 0.6), // solid continuous edge
            Colors.black.withValues(alpha: 0.5), // shadowed continuous edge
            Colors.black.withValues(alpha: 0.8), // deep shadow lip
          ],
          stops: const [0.0, 0.4, 0.7, 1.0],
        ).createShader(rect),
    );

    canvas.restore(); // merge layer

    // ── 2. Top Specular Glint (Water Droplet highlights) ──
    // Main curved lens highlight
    final lensPath = Path();
    lensPath.moveTo(0, size.height * 0.35);
    lensPath.quadraticBezierTo(
      size.width * 0.5, size.height * 0.05,
      size.width, size.height * 0.30,
    );
    lensPath.lineTo(size.width, 0);
    lensPath.lineTo(0, 0);
    lensPath.close();

    canvas.drawPath(
      lensPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.40),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(rect),
    );

    // Small sharp glint strip at the very top (the capsule)
    final sw = size.width * 0.6;
    final sh = 6.0;
    final sx = (size.width - sw) / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(sx, 4, sw, sh),
        const Radius.circular(3),
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    canvas.restore(); // restore initial clip
  }

  @override
  bool shouldRepaint(covariant _HeavyGlassPainter old) => old.isUser != isUser;
}



class _BubbleClipper extends CustomClipper<Path> {
  final bool isUser;
  const _BubbleClipper({required this.isUser});

  @override
  Path getClip(Size size) => _buildBubblePath(size, isUser: isUser);
  @override
  bool shouldReclip(covariant _BubbleClipper old) => old.isUser != isUser;
}

// ─────────────────────────────────────────────────────────────────────────────
// UI Components
// ─────────────────────────────────────────────────────────────────────────────

class _SpeechBubble extends StatelessWidget {
  final _CoachMessage message;
  const _SpeechBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    const contentPad = EdgeInsets.fromLTRB(22, 16, 22, 16 + _kTailH);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        child: CustomPaint(
          painter: _BubbleShadowPainter(isUser: isUser),
          foregroundPainter: _HeavyGlassPainter(isUser: isUser),
          child: ClipPath(
            clipper: _BubbleClipper(isUser: isUser),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                color: Colors.white.withValues(alpha: 0.06), // Very faint base frost
                padding: contentPad,
                child: Text(
                  message.text,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF111111), // pure black/dark grey text per reference
                    height: 1.3,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();
  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: CustomPaint(
        painter: const _BubbleShadowPainter(isUser: false),
        foregroundPainter: const _HeavyGlassPainter(isUser: false),
        child: ClipPath(
          clipper: const _BubbleClipper(isUser: false),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: Colors.white.withValues(alpha: 0.06),
              padding: const EdgeInsets.fromLTRB(26, 20, 26, 20 + _kTailH),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  return AnimatedBuilder(
                    animation: _ctrl,
                    builder: (_, __) {
                      final t = (_ctrl.value - i * 0.15).clamp(0.0, 1.0);
                      final bounce = math.sin(t * math.pi);
                      return Container(
                        margin: EdgeInsets.symmetric(horizontal: 3),
                        width: 10, height: 10,
                        transform: Matrix4.translationValues(0, -bounce * 6, 0),
                        decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF0F172A).withValues(alpha: 0.4 + bounce * 0.6)),
                      );
                    },
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Exact Refractive Glass Input Bar
// ─────────────────────────────────────────────────────────────────────────────

class _HeavyGlassInput extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasText;
  final VoidCallback onSend;

  const _HeavyGlassInput({
    required this.controller,
    required this.focusNode,
    required this.hasText,
    required this.onSend,
  });

  @override
  State<_HeavyGlassInput> createState() => _HeavyGlassInputState();
}

class _HeavyGlassInputState extends State<_HeavyGlassInput> with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final phase = _anim.value * math.pi * 2;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: SizedBox(
            height: 66,
            child: CustomPaint(
              painter: _OuterShadowWavyPainter(phase),
              child: ClipPath(
                clipper: _WavyClipper(phase),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: CustomPaint(
                    painter: _WavyGlassInputPainter(phase),
                    child: Row(
                      children: [
                        // --- Left '+' Icon ---
                        const SizedBox(width: 4),
                        _buildIconBtn(Icons.add_rounded, 30),
                        
                        // --- Inner Cavity ---
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: CustomPaint(
                              painter: _InnerCavityPainter(),
                              child: Row(
                                children: [
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextField(
                                      controller: widget.controller,
                                      focusNode: widget.focusNode,
                                      textInputAction: TextInputAction.send,
                                      onSubmitted: (_) => widget.onSend(),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF64748B),
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Type a message...',
                                        hintStyle: TextStyle(
                                          color: const Color(0xFF94A3B8).withValues(alpha: 0.9),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w400,
                                        ),
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // --- Right Icon (Mic / Send) ---
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: widget.hasText
                              ? Padding(
                                  key: const ValueKey('send'),
                                  padding: const EdgeInsets.only(right: 6, left: 6),
                                  child: _buildSendBtn(),
                                )
                              : Padding(
                                  key: const ValueKey('mic'),
                                  padding: const EdgeInsets.only(right: 6, left: 6),
                                  child: _buildIconBtn(Icons.mic_rounded, 26),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIconBtn(IconData icon, double size) {
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); },
      child: Container(
        width: 48,
        height: 48,
        color: Colors.transparent,
        child: Center(
          child: Icon(icon, size: size, color: const Color(0xFF8E8E93)),
        ),
      ),
    );
  }

  Widget _buildSendBtn() {
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); widget.onSend(); },
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight, 
            colors: [Color(0xFFC084FC), Color(0xFF6366F1)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFC084FC).withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: const Center(
          child: Icon(Icons.send_rounded, size: 20, color: Colors.white),
        ),
      ),
    );
  }
}

Path _getMorphingPillPath(Size size, double phase, {
  double ampTop = 4.0, 
  double ampBot = 4.0, 
  double topYOffset = 0.0, 
  double botYOffset = 0.0, 
  double phaseOffset = 0.0
}) {
  final w = size.width;
  final h = size.height;
  final r = h / 2;
  final path = Path();
  final segments = 50;
  
  final startTopX = r;
  final endTopX = w - r;
  
  // Math for identical endcaps considering offsets
  // Default radius is 'r' for offset 0; adjusts mathematically when inset
  final arcRadius = Radius.circular(math.max(0.1, r - (topYOffset - botYOffset) / 2));
  
  path.moveTo(startTopX, topYOffset);
  
  // Top wave (left to right)
  for (int i = 0; i <= segments; i++) {
    double t = i / segments;
    double x = startTopX + t * (endTopX - startTopX);
    
    // Attenuate zero-slope at connection points
    double attenuation = math.sin(t * math.pi);
    attenuation = attenuation * attenuation * (3 - 2 * attenuation);

    double wave = math.sin(t * math.pi * 3 + phase + phaseOffset) * 0.7 +
                  math.cos(t * math.pi * 5 - phase * 1.3) * 0.3;
                  
    double y = topYOffset + wave * ampTop * attenuation;
    if (i == 0 || i == segments) y = topYOffset; // Lock exact endpoints
    
    path.lineTo(x, y);
  }
  
  // Perfect right semi-circle 
  path.arcToPoint(
    Offset(endTopX, h + botYOffset),
    radius: arcRadius,
    clockwise: true,
  );
  
  // Bottom wave (right to left)
  for (int i = segments; i >= 0; i--) {
    double t = i / segments;
    double x = startTopX + t * (endTopX - startTopX);
    
    double attenuation = math.sin(t * math.pi);
    attenuation = attenuation * attenuation * (3 - 2 * attenuation);

    double wave = math.sin(t * math.pi * 4 - phase + phaseOffset) * 0.7 +
                  math.cos(t * math.pi * 6 + phase * 1.1) * 0.3;
                  
    double y = h + botYOffset + wave * ampBot * attenuation;
    if (i == 0 || i == segments) y = h + botYOffset; // Lock exactly
    
    path.lineTo(x, y);
  }
  
  // Perfect left semi-circle
  path.arcToPoint(
    Offset(startTopX, topYOffset),
    radius: arcRadius,
    clockwise: true,
  );
  
  path.close();
  return path;
}

class _WavyClipper extends CustomClipper<Path> {
  final double phase;
  _WavyClipper(this.phase);
  @override
  Path getClip(Size size) => _getMorphingPillPath(size, phase, ampTop: 5.0, ampBot: 5.0);
  @override
  bool shouldReclip(covariant _WavyClipper old) => old.phase != phase;
}

class _OuterShadowWavyPainter extends CustomPainter {
  final double phase;
  _OuterShadowWavyPainter(this.phase);
  
  @override
  void paint(Canvas canvas, Size size) {
    final path = _getMorphingPillPath(size, phase, ampTop: 5.0, ampBot: 5.0);
    // Dark shadow tracking the outer shape exactly
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.08), 16, true);
  }
  
  @override
  bool shouldRepaint(covariant _OuterShadowWavyPainter old) => old.phase != phase;
}

class _WavyGlassInputPainter extends CustomPainter {
  final double phase;
  _WavyGlassInputPainter(this.phase);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final baseLayer = _getMorphingPillPath(size, phase, ampTop: 5.0, ampBot: 5.0);

    canvas.save();
    canvas.clipPath(baseLayer);

    // 1. Frost background inside the glass volume
    canvas.drawColor(Colors.white.withValues(alpha: 0.15), BlendMode.srcOver);

    // 2. Thick 3D glass edge deepening (inner shading)
    canvas.drawPath(
      baseLayer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 24
        ..shader = LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.12),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.08),
          ],
        ).createShader(rect),
    );

    // Deep heavy flares on the left and right semi-circular ends
    final sideRefraction = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 36
      ..shader = LinearGradient(
        begin: Alignment.centerLeft, end: Alignment.centerRight,
        colors: [
          Colors.black.withValues(alpha: 0.14),
          Colors.transparent,
          Colors.black.withValues(alpha: 0.14),
        ],
        stops: const [0.0, 0.35, 1.0],
      ).createShader(rect);
    canvas.drawPath(baseLayer, sideRefraction);
    
    // 3. Iridescent caustics
    // offset 3px inside logically, mimicking internal liquid reflections!
    final iridescencePath = _getMorphingPillPath(size, phase, ampTop: 5.0, ampBot: 5.0, topYOffset: 3.0, botYOffset: -3.0);
    canvas.drawPath(
      iridescencePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0
        ..shader = LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [
            const Color(0xFFC084FC).withValues(alpha: 0.7), // Theme purple glow
            Colors.white.withValues(alpha: 0.2),            // Transparent pass
            Colors.cyan.withValues(alpha: 0.5),             // Fluid inner gradient 
            const Color(0xFF9333EA).withValues(alpha: 0.6), // Darker coach vibe
          ],
          stops: const [0.0, 0.4, 0.7, 1.0],
        ).createShader(rect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );

    // 4. Heavy white fluid reflections
    // Flowing independently mostly on top inner edge
    final topWhite = _getMorphingPillPath(size, phase, ampTop: 6.0, ampBot: 4.0, topYOffset: 1.0, botYOffset: -1.0, phaseOffset: 0.5);
    canvas.drawPath(
      topWhite,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..shader = LinearGradient(
          begin: Alignment.centerLeft, end: Alignment.centerRight,
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.9),
            Colors.white.withValues(alpha: 0.3),
            Colors.white.withValues(alpha: 0.8),
            Colors.white.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
        ).createShader(rect),
    );

    // Thin inner rim highlight (gives depth to the bottom edge)
    final botWhite = _getMorphingPillPath(size, phase, ampTop: 4.0, ampBot: 6.0, topYOffset: 5.0, botYOffset: -5.0, phaseOffset: -0.5);
    canvas.drawPath(
      botWhite,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..shader = LinearGradient(
          begin: Alignment.centerLeft, end: Alignment.centerRight,
          colors: [
            Colors.transparent,
            Colors.white.withValues(alpha: 0.6),
            Colors.transparent,
          ],
          stops: const [0.1, 0.5, 0.9],
        ).createShader(rect),
    );

    canvas.restore(); // end clipPath(baseLayer)

    // 5. Razor thin outer glass membrane sealing everything
    canvas.drawPath(
      baseLayer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..shader = LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.9),
            const Color(0xFFC084FC).withValues(alpha: 0.4), 
            Colors.black.withValues(alpha: 0.15),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _WavyGlassInputPainter old) => old.phase != phase;
}

class _InnerCavityPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(size.height / 2));
    
    // Frost base
    canvas.drawRRect(rrect, Paint()..color = Colors.white.withValues(alpha: 0.15));

    // Inner top shadow
    canvas.save();
    canvas.clipRRect(rrect);
    final topShadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawRRect(rrect.shift(const Offset(0, -3)), topShadow);
    canvas.restore();

    // Bottom crisp white lip
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, size.height * 0.5, size.width, size.height * 0.5));
    final bottomLip = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.white.withValues(alpha: 0.8);
    canvas.drawRRect(rrect, bottomLip);
    canvas.restore();
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Coach Tab Screen
// ─────────────────────────────────────────────────────────────────────────────

class CoachTab extends ConsumerStatefulWidget {
  const CoachTab({super.key});

  @override
  ConsumerState<CoachTab> createState() => _CoachTabState();
}

class _CoachTabState extends ConsumerState<CoachTab> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  bool _hasText = false;
  bool _isTyping = false;
  String _coachName = 'AI Coach';
  GeminiChatSession? _chatSession;

  final List<_CoachMessage> _messages = [];
  final List<Map<String, dynamic>> _geminiHistory = [];

  @override
  void initState() {
    super.initState();
    _fetchCoachName();
    _loadHistory();
    _ctrl.addListener(() {
      final has = _ctrl.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  Future<void> _loadHistory() async {
    try {
      final turns = await FirestoreService().getCoachChatTurns('main_thread');
      if (turns.isNotEmpty && mounted) {
        setState(() {
          _messages.clear();
          _geminiHistory.clear();
          for (final turn in turns) {
            final isUser = turn['isUser'] as bool;
            final text = turn['text'] as String;
            _messages.add(_CoachMessage(text: text, isUser: isUser));
            _geminiHistory.add({
              'role': isUser ? 'user' : 'model',
              'parts': [{'text': text}],
            });
          }
        });
        _scrollToBottom();
      } else if (mounted) {
        setState(() {
          _messages.add(_CoachMessage(
            text: "Hello! I'm $_coachName, your personal AI coach. How can I support you today?",
            isUser: false,
          ));
        });
      }
    } catch (e) {
      debugPrint('Error loading coach chat history: $e');
    }
  }

  Future<void> _fetchCoachName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final data = await FirestoreService().getUserProfile();
        if (data != null && mounted) {
          if (data.containsKey('onboarding')) {
            final ob = data['onboarding'] as Map<String, dynamic>;
            if (ob.containsKey('coachName') && ob['coachName'].toString().isNotEmpty) {
              setState(() => _coachName = ob['coachName'].toString());
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching coach name: $e');
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _messages.add(_CoachMessage(text: text, isUser: true));
      _isTyping = true;
    });
    _ctrl.clear();
    _scrollToBottom();
    
    try {
      final userTurnId = const Uuid().v4();
      await FirestoreService().saveCoachChatTurn('main_thread', userTurnId, {
        'id': userTurnId,
        'text': text,
        'isUser': true,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (_chatSession == null) {
        final ob = ref.read(onboardingProvider);
        final goals = ob.goals.join(', ');
        final habits = ob.badHabits.join(', ');
        final tone = ob.coachStyle.isEmpty ? 'Empathetic and motivating' : ob.coachStyle;
        
        final sysPrompt = '''You are the user's personal Optivus AI life coach. Your name is $_coachName.
Your tone should be: $tone.
User's main goals: $goals.
Habits trying to break: $habits.
You are embedded in their daily timeline app. Keep responses engaging, supportive, and relatively concise (1-3 paragraphs max) so they fit well in a chat bubble.''';

        _chatSession = GeminiService().startChat(sysPrompt, initialHistory: List.from(_geminiHistory));
      }
      
      final reply = await _chatSession!.sendMessage(text);
      
      final coachTurnId = const Uuid().v4();
      await FirestoreService().saveCoachChatTurn('main_thread', coachTurnId, {
        'id': coachTurnId,
        'text': reply,
        'isUser': false,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      
      setState(() {
        _isTyping = false;
        _messages.add(_CoachMessage(text: reply, isUser: false));
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(_CoachMessage(text: "I'm having trouble connecting right now, but remember: Every setback is data, not defeat. Keep moving forward! 🌟", isUser: false));
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // Tab bar height: 72 (bar) + 28 (bottom padding) + system nav bar
    // With extendBody:true the Scaffold already folds tab bar + system inset
    // into mq.padding.bottom – do NOT add the tab bar size again.
    final double tabBarHeight = mq.padding.bottom;
    // Height of the input bar widget itself (bar + vertical padding)
    const double inputBarHeight = 60 + 4 + 8; // bar + top + bottom pad
    // When keyboard is up, lift the input bar above the keyboard
    final double keyboardHeight = mq.viewInsets.bottom;
    final double inputBottom = keyboardHeight > 0
        ? keyboardHeight + 8          // above keyboard
        : tabBarHeight;               // above tab bar normally

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Stack(
        children: [
          // ── Message list ──────────────────────────────────────
          Positioned.fill(
            child: Column(
              children: [
                SizedBox(height: mq.padding.top),
                _buildHeader(),
                Expanded(
                  child: ShaderMask(
                    shaderCallback: (Rect bounds) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.white, Colors.white],
                        stops: [0.0, 0.05, 1.0],
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.dstIn,
                    child: ListView.builder(
                      controller: _scroll,
                      padding: EdgeInsets.fromLTRB(
                        16, 12, 16,
                        // bottom padding keeps last bubble above input bar + tab bar
                        inputBottom + inputBarHeight + 16,
                      ),
                      reverse: true,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _messages.length + (_isTyping ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (_isTyping && i == 0) return const Padding(padding: EdgeInsets.only(bottom: 16), child: _TypingBubble());
                        final offset = _isTyping ? 1 : 0;
                        final msg = _messages[_messages.length - 1 - (i - offset)];
                        return Padding(
                          key: ValueKey(_messages.length - 1 - (i - offset)),
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _SpeechBubble(message: msg),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Input bar – floats above tab bar, lifts with keyboard ─
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            left: 0,
            right: 0,
            bottom: inputBottom,
            child: _HeavyGlassInput(
              controller: _ctrl,
              focusNode: _focus,
              hasText: _hasText,
              onSend: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 58, height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFC084FC).withValues(alpha: 0.25),
            ),
            child: const Icon(Icons.smart_toy_rounded, color: Color(0xFF9333EA), size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_coachName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.5)),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle, color: const Color(0xFF4CAF50),
                        boxShadow: [BoxShadow(color: const Color(0xFF4CAF50).withValues(alpha: 0.5), blurRadius: 4)],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('Online · Here for you', style: TextStyle(fontSize: 14, color: const Color(0xFF64748B).withValues(alpha: 0.9), fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.35),
              border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.2),
            ),
            child: const Icon(Icons.more_horiz_rounded, color: Color(0xFF64748B), size: 24),
          ),
        ],
      ),
    );
  }
}
