import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/services/coach_service.dart';
import 'dart:async';

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────

class _CoachMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime? createdAt;
  final CoachTopicMode mode;
  final String? safetyBranch;
  final String? messageType;

  const _CoachMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.createdAt,
    required this.mode,
    this.safetyBranch,
    this.messageType,
  });

  bool get isCrisis =>
      !isUser && (safetyBranch == 'crisis' || messageType == 'safety_crisis');

  factory _CoachMessage.fromDomain(CoachChatMessage message) {
    return _CoachMessage(
      id: message.id,
      text: message.text,
      isUser: message.isUser,
      createdAt: message.createdAt,
      mode: message.mode,
      safetyBranch: message.safetyBranch,
      messageType: message.messageType,
    );
  }
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
  final double tailTipX =
      isUser ? tailEdgeOffset + _kTailW * 0.5 : tailEdgeOffset - _kTailW * 0.5;

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
      tailEdgeOffset + 2,
      bH,
      tailTipX - 2,
      bH + _kTailH * 0.8,
      tailTipX,
      bH + _kTailH,
    );
    p.cubicTo(
      tailTipX - 10,
      bH + _kTailH * 0.5,
      tailEdgeOffset - _kTailW + 8,
      bH,
      tailEdgeOffset - _kTailW,
      bH,
    );
    p.lineTo(r, bH);
  } else {
    p.lineTo(tailEdgeOffset + _kTailW, bH);
    // AI tail (bottom-left pointing down-left)
    p.cubicTo(
      tailEdgeOffset + _kTailW - 8,
      bH,
      tailTipX + 10,
      bH + _kTailH * 0.5,
      tailTipX,
      bH + _kTailH,
    );
    p.cubicTo(
      tailTipX + 2,
      bH + _kTailH * 0.8,
      tailEdgeOffset - 2,
      bH,
      tailEdgeOffset,
      bH,
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
  bool shouldRepaint(covariant _BubbleShadowPainter old) =>
      old.isUser != isUser;
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
            Colors.white.withValues(alpha: 0.5), // solid glass body transiton
            Colors.black.withValues(alpha: 0.2), // soft shadow wrapping
            Colors.black
                .withValues(alpha: 0.4), // deep inner shadow bottom-right
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
      size.width * 0.5,
      size.height * 0.05,
      size.width,
      size.height * 0.30,
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
    if (message.isCrisis) {
      return _CrisisCard(message: message);
    }

    final isUser = message.isUser;
    const contentPad = EdgeInsets.fromLTRB(22, 16, 22, 16 + _kTailH);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        child: CustomPaint(
          painter: _BubbleShadowPainter(isUser: isUser),
          foregroundPainter: _HeavyGlassPainter(isUser: isUser),
          child: ClipPath(
            clipper: _BubbleClipper(isUser: isUser),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                color: Colors.white
                    .withValues(alpha: 0.06), // Very faint base frost
                padding: contentPad,
                child: Text(
                  message.text,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(
                        0xFF111111), // pure black/dark grey text per reference
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

class _CrisisCard extends StatelessWidget {
  final _CoachMessage message;
  const _CrisisCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.9),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1F2).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFB7185), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF881337).withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                children: [
                  Icon(Icons.health_and_safety_rounded,
                      color: Color(0xFFBE123C), size: 22),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Crisis support',
                      style: TextStyle(
                        color: Color(0xFF881337),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                message.text,
                style: const TextStyle(
                  color: Color(0xFF4C0519),
                  fontSize: 15,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  _CrisisChip(icon: Icons.call_rounded, label: 'Call 988'),
                  _CrisisChip(icon: Icons.sms_rounded, label: 'Text 988'),
                  _CrisisChip(
                      icon: Icons.person_add_alt_1_rounded,
                      label: 'Contact someone trusted'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CrisisChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CrisisChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFDA4AF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFFBE123C)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF881337),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();
  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

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
                        width: 10,
                        height: 10,
                        transform: Matrix4.translationValues(0, -bounce * 6, 0),
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF0F172A)
                                .withValues(alpha: 0.4 + bounce * 0.6)),
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

class _HeavyGlassInputState extends State<_HeavyGlassInput>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim =
        AnimationController(vsync: this, duration: const Duration(seconds: 4))
          ..repeat();
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
                                          color: const Color(0xFF94A3B8)
                                              .withValues(alpha: 0.9),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w400,
                                        ),
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                vertical: 12),
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
                                  padding:
                                      const EdgeInsets.only(right: 6, left: 6),
                                  child: _buildSendBtn(),
                                )
                              : Padding(
                                  key: const ValueKey('mic'),
                                  padding:
                                      const EdgeInsets.only(right: 6, left: 6),
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
      onTap: () {
        HapticFeedback.lightImpact();
      },
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
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onSend();
      },
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
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

Path _getMorphingPillPath(Size size, double phase,
    {double ampTop = 4.0,
    double ampBot = 4.0,
    double topYOffset = 0.0,
    double botYOffset = 0.0,
    double phaseOffset = 0.0}) {
  final w = size.width;
  final h = size.height;
  final r = h / 2;
  final path = Path();
  final segments = 50;

  final startTopX = r;
  final endTopX = w - r;

  // Math for identical endcaps considering offsets
  // Default radius is 'r' for offset 0; adjusts mathematically when inset
  final arcRadius =
      Radius.circular(math.max(0.1, r - (topYOffset - botYOffset) / 2));

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
  Path getClip(Size size) =>
      _getMorphingPillPath(size, phase, ampTop: 5.0, ampBot: 5.0);
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
  bool shouldRepaint(covariant _OuterShadowWavyPainter old) =>
      old.phase != phase;
}

class _WavyGlassInputPainter extends CustomPainter {
  final double phase;
  _WavyGlassInputPainter(this.phase);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final baseLayer =
        _getMorphingPillPath(size, phase, ampTop: 5.0, ampBot: 5.0);

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
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
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
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
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
    final iridescencePath = _getMorphingPillPath(size, phase,
        ampTop: 5.0, ampBot: 5.0, topYOffset: 3.0, botYOffset: -3.0);
    canvas.drawPath(
      iridescencePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFC084FC).withValues(alpha: 0.7), // Theme purple glow
            Colors.white.withValues(alpha: 0.2), // Transparent pass
            Colors.cyan.withValues(alpha: 0.5), // Fluid inner gradient
            const Color(0xFF9333EA).withValues(alpha: 0.6), // Darker coach vibe
          ],
          stops: const [0.0, 0.4, 0.7, 1.0],
        ).createShader(rect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );

    // 4. Heavy white fluid reflections
    // Flowing independently mostly on top inner edge
    final topWhite = _getMorphingPillPath(size, phase,
        ampTop: 6.0,
        ampBot: 4.0,
        topYOffset: 1.0,
        botYOffset: -1.0,
        phaseOffset: 0.5);
    canvas.drawPath(
      topWhite,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
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
    final botWhite = _getMorphingPillPath(size, phase,
        ampTop: 4.0,
        ampBot: 6.0,
        topYOffset: 5.0,
        botYOffset: -5.0,
        phaseOffset: -0.5);
    canvas.drawPath(
      botWhite,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
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
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.9),
            const Color(0xFFC084FC).withValues(alpha: 0.4),
            Colors.black.withValues(alpha: 0.15),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _WavyGlassInputPainter old) =>
      old.phase != phase;
}

class _InnerCavityPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect =
        RRect.fromRectAndRadius(rect, Radius.circular(size.height / 2));

    // Frost base
    canvas.drawRRect(
        rrect, Paint()..color = Colors.white.withValues(alpha: 0.15));

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
    canvas.clipRect(
        Rect.fromLTWH(0, size.height * 0.5, size.width, size.height * 0.5));
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

class _ModeTile extends StatelessWidget {
  final CoachTopicMode mode;
  final bool selected;
  final VoidCallback onTap;

  const _ModeTile({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  IconData get _icon {
    return switch (mode) {
      CoachTopicMode.recovery => Icons.replay_circle_filled_rounded,
      CoachTopicMode.study => Icons.menu_book_rounded,
      CoachTopicMode.calm => Icons.self_improvement_rounded,
      CoachTopicMode.askAnything => Icons.auto_awesome_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFF3E8FF)
                : Colors.white.withValues(alpha: 0.0),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(_icon,
                  color: selected
                      ? const Color(0xFF7E22CE)
                      : const Color(0xFF64748B)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode.label,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mode.description,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF7E22CE)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RetryReplyBanner extends StatelessWidget {
  final VoidCallback onRetry;

  const _RetryReplyBanner({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.wifi_off_rounded,
                  size: 20, color: Color(0xFFB45309)),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Reply failed. Your message is saved.',
                  style: TextStyle(
                    color: Color(0xFF78350F),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF7E22CE),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OlderMessagesLoader extends StatelessWidget {
  const _OlderMessagesLoader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Color(0xFF9333EA),
          ),
        ),
      ),
    );
  }
}

class _HistoryErrorRow extends StatelessWidget {
  final String text;
  final VoidCallback onRetry;

  const _HistoryErrorRow({
    required this.text,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Center(
        child: TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(text),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF7E22CE),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
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
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _coachName = 'AI Coach';
  String? _loadError;
  String? _failedReplyText;
  CoachTopicMode? _failedReplyMode;
  CoachTopicMode _mode = CoachTopicMode.askAnything;
  DocumentSnapshot<Map<String, dynamic>>? _oldestDocument;

  final List<_CoachMessage> _messages = [];

  /// IDs of messages already displayed — prevents stream/page duplicates.
  final Set<String> _seenMessageIds = {};

  StreamSubscription<List<CoachChatMessage>>? _latestSub;

  @override
  void initState() {
    super.initState();
    _fetchCoachName();
    _loadInitialHistory();
    _listenForLatestMessages();
    _scroll.addListener(_maybeLoadMore);
    _ctrl.addListener(() {
      final has = _ctrl.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  CoachService get _coachService => ref.read(coachServiceProvider);

  void _listenForLatestMessages() {
    _latestSub = _coachService.watchLatestMessages().listen((messages) {
      if (!mounted) return;
      final hadNew = _mergeMessages(messages);
      if (hadNew) _scrollToBottom();
    }, onError: (e) {
      debugPrint('[CoachTab] Error listening to coach_messages: $e');
    });
  }

  Future<void> _loadInitialHistory() async {
    try {
      final page = await _coachService.loadMessagesPage();
      if (!mounted) return;
      setState(() {
        _messages.clear();
        _seenMessageIds.clear();
        _oldestDocument = page.oldestDocument;
        _hasMore = page.hasMore;
        _loadError = null;
        _isLoadingInitial = false;
        if (page.messages.isEmpty) {
          _addWelcomeMessage();
        } else {
          _appendDomainMessages(page.messages);
        }
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Could not load coach history.';
        _isLoadingInitial = false;
      });
      debugPrint('Error loading coach chat history: $e');
    }
  }

  Future<void> _fetchCoachName() async {
    try {
      final name = await _coachService.loadCoachName();
      if (mounted) {
        setState(() => _coachName = name);
      }
    } catch (e) {
      debugPrint('Error fetching coach name: $e');
    }
  }

  @override
  void dispose() {
    _latestSub?.cancel();
    _scroll.removeListener(_maybeLoadMore);
    _ctrl.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(0,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  void _maybeLoadMore() {
    if (!_scroll.hasClients || !_hasMore || _isLoadingMore) return;
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent - 220) {
      _loadMoreHistory();
    }
  }

  Future<void> _loadMoreHistory() async {
    final cursor = _oldestDocument;
    if (cursor == null || _isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final page = await _coachService.loadMessagesPage(startAfter: cursor);
      if (!mounted) return;
      setState(() {
        _oldestDocument = page.oldestDocument;
        _hasMore = page.hasMore;
        _prependDomainMessages(page.messages);
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
      debugPrint('Error loading older coach history: $e');
    }
  }

  void _addWelcomeMessage() {
    const id = 'local_welcome';
    _seenMessageIds.add(id);
    _messages.add(_CoachMessage(
      id: id,
      text:
          "Hello! I'm $_coachName, your personal AI coach. How can I support you today?",
      isUser: false,
      createdAt: null,
      mode: CoachTopicMode.askAnything,
    ));
  }

  bool _mergeMessages(List<CoachChatMessage> incoming) {
    var changed = false;
    setState(() {
      for (final message in incoming) {
        if (_seenMessageIds.contains(message.id)) continue;
        _seenMessageIds.add(message.id);
        _messages.add(_CoachMessage.fromDomain(message));
        changed = true;
      }
      if (changed) _sortMessages();
    });
    return changed;
  }

  void _appendDomainMessages(List<CoachChatMessage> messages) {
    for (final message in messages) {
      if (_seenMessageIds.contains(message.id)) continue;
      _seenMessageIds.add(message.id);
      _messages.add(_CoachMessage.fromDomain(message));
    }
    _sortMessages();
  }

  void _prependDomainMessages(List<CoachChatMessage> messages) {
    final older = <_CoachMessage>[];
    for (final message in messages) {
      if (_seenMessageIds.contains(message.id)) continue;
      _seenMessageIds.add(message.id);
      older.add(_CoachMessage.fromDomain(message));
    }
    _messages.insertAll(0, older);
    _sortMessages();
  }

  void _sortMessages() {
    _messages.sort((a, b) {
      final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aTime.compareTo(bTime);
    });
  }

  Future<void> _sendMessage() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _isTyping) return;
    HapticFeedback.lightImpact();
    _ctrl.clear();
    final sendMode = _mode;

    try {
      final userMessage = await _coachService.saveUserMessage(
        text: text,
        mode: sendMode,
      );
      if (!mounted) return;
      setState(() {
        _failedReplyText = null;
        _failedReplyMode = null;
        _isTyping = true;
        _appendDomainMessages([userMessage]);
      });
      _scrollToBottom();
      await _requestReply(text, sendMode);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _failedReplyText = text;
        _failedReplyMode = sendMode;
      });
      _scrollToBottom();
    }
  }

  Future<void> _requestReply(String text, CoachTopicMode mode) async {
    try {
      final reply = await _coachService.generateAndSaveAssistantReply(
        userText: text,
        mode: mode,
      );
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _failedReplyText = null;
        _failedReplyMode = null;
        _appendDomainMessages([reply]);
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _failedReplyText = text;
        _failedReplyMode = mode;
      });
      debugPrint('[CoachTab] Coach reply failed: $e');
      _scrollToBottom();
    }
  }

  Future<void> _retryLastReply() async {
    final text = _failedReplyText;
    final mode = _failedReplyMode ?? _mode;
    if (text == null || _isTyping) return;
    HapticFeedback.lightImpact();
    setState(() {
      _failedReplyText = null;
      _failedReplyMode = null;
      _isTyping = true;
    });
    await _requestReply(text, mode);
  }

  void _showModePicker() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white.withValues(alpha: 0.96),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                for (final mode in CoachTopicMode.values)
                  _ModeTile(
                    mode: mode,
                    selected: mode == _mode,
                    onTap: () {
                      Navigator.of(context).pop();
                      setState(() => _mode = mode);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
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
        ? keyboardHeight + 8 // above keyboard
        : tabBarHeight; // above tab bar normally

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
                  child: _isLoadingInitial
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF9333EA),
                          ),
                        )
                      : ShaderMask(
                          shaderCallback: (Rect bounds) {
                            return const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.white,
                                Colors.white
                              ],
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
                            itemCount: _messages.length +
                                (_isTyping ? 1 : 0) +
                                (_isLoadingMore ? 1 : 0) +
                                (_loadError != null ? 1 : 0),
                            itemBuilder: (context, i) {
                              if (_isTyping && i == 0) {
                                return const Padding(
                                    padding: EdgeInsets.only(bottom: 16),
                                    child: _TypingBubble());
                              }
                              final offset = _isTyping ? 1 : 0;
                              final messageIndex = i - offset;
                              if (messageIndex >= _messages.length) {
                                if (_loadError != null) {
                                  return _HistoryErrorRow(
                                    text: _loadError!,
                                    onRetry: _loadInitialHistory,
                                  );
                                }
                                return const _OlderMessagesLoader();
                              }
                              final msg = _messages[
                                  _messages.length - 1 - messageIndex];
                              return Padding(
                                key: ValueKey(msg.id),
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
          if (_failedReplyText != null)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              left: 16,
              right: 16,
              bottom: inputBottom + inputBarHeight + 8,
              child: _RetryReplyBanner(onRetry: _retryLastReply),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final aiReady = ref.watch(appFeatureFlagsProvider).aiCoachMessagesReady;
    final statusLabel = aiReady ? 'Online' : 'Manual';
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onLongPress: _showModePicker,
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFC084FC).withValues(alpha: 0.25),
              ),
              child: const Icon(Icons.smart_toy_rounded,
                  color: Color(0xFF9333EA), size: 30),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_coachName,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5)),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF4CAF50),
                        boxShadow: [
                          BoxShadow(
                              color: const Color(0xFF4CAF50)
                                  .withValues(alpha: 0.5),
                              blurRadius: 4)
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '$statusLabel · ${_mode.label}',
                        style: TextStyle(
                            fontSize: 14,
                            color:
                                const Color(0xFF64748B).withValues(alpha: 0.9),
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _showModePicker,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.35),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.9), width: 1.2),
              ),
              child: const Icon(Icons.more_horiz_rounded,
                  color: Color(0xFF64748B), size: 24),
            ),
          ),
        ],
      ),
    );
  }
}
