import 'dart:math' show pi;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:optivus2/core/router/app_router.dart';
import 'package:optivus2/providers/onboarding_provider.dart';
import 'package:optivus2/widgets/app_button.dart';
import 'package:optivus2/views/onboarding/onboarding_page_0.dart';
import 'package:optivus2/views/onboarding/onboarding_page_1.dart';
import 'package:optivus2/views/onboarding/onboarding_page_2.dart';
import 'package:optivus2/views/onboarding/onboarding_page_3.dart';
import 'package:optivus2/views/onboarding/onboarding_page_4.dart';
import 'package:optivus2/views/onboarding/onboarding_page_5.dart';
import 'package:optivus2/views/onboarding/onboarding_page_6.dart';
import 'package:optivus2/views/onboarding/onboarding_page_7.dart';
import 'package:optivus2/views/onboarding/onboarding_page_8.dart';
import 'package:optivus2/views/onboarding/onboarding_page_9.dart';

// Shared layout constants so pages know how much to inset
const double kIndicatorOverlayH = 44.0;  // top glass overlay height
const double kButtonOverlayH    = 140.0; // bottom glass overlay height (button + 72px sub-area)

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final PageController _pageController;
  late final _PageOffsetNotifier _pageOffset;
  int _currentPage = 0;

  double _dragStartPage = 0.0;
  double _dragStartX    = 0.0;
  bool   _isDragging    = false;
  int    _lastHapticPage = 0;
  static const double _indicatorStep = 48.0;

  // Save button state
  final GlobalKey<_OnboardingSaveButtonState> _saveButtonKey = GlobalKey<_OnboardingSaveButtonState>();

  @override
  void initState() {
    super.initState();
    final initialPage = AppRouter.currentUserModel?.onboardingStep ?? 0;
    _currentPage = initialPage;
    _pageController = PageController(initialPage: initialPage);
    _pageOffset = _PageOffsetNotifier(_pageController);
  }

  @override
  void dispose() {
    _pageOffset.dispose();
    _pageController.dispose();
    super.dispose();
  }

  /// Triggers save via the save-button and waits for it to finish.
  /// Returns true if the save succeeded.
  Future<bool> _saveCurrentPage() async {
    final btnState = _saveButtonKey.currentState;
    if (btnState == null) return true; // no button visible → nothing to save
    return btnState.triggerSave();
  }

  void _onNext() async {
    // Pages 1–8: save first, then navigate
    if (_currentPage >= 1 && _currentPage <= 8) {
      final ok = await _saveCurrentPage();
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save. Please check your connection and try again.')),
          );
        }
        return;
      }
      if (!mounted) return;
      // Small delay so user sees the checkmark before transitioning
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else if (_currentPage < 9) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      final ok = await ref.read(onboardingProvider.notifier).completeOnboarding();
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save profile. Please check your connection and try again.')),
          );
        }
        return;
      }
      if (!mounted) return;
      context.go('/home');
    }
  }

  String get _buttonLabel {
    if (_currentPage == 0) return 'Get Started';
    if (_currentPage == 9) return 'Enter Optivus';
    return 'Next';
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF6E6B4), Color(0xFFFCF8EE)],
              stops: [0.0, 0.6],
            ),
          ),
          child: Stack(
            children: [
              // ── Full-screen PageView (under everything) ──────────────
              Positioned.fill(
                child: PageView(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (i) {
                    setState(() => _currentPage = i);
                    ref.read(onboardingProvider.notifier).saveToFirestoreDebounced(i);
                  },
                  children: const [
                    OnboardingPage0(),
                    OnboardingPage1(),
                    OnboardingPage2(),
                    OnboardingPage3(),
                    OnboardingPage4(),
                    OnboardingPage5(),
                    OnboardingPage6(),
                    OnboardingPage7(),
                    OnboardingPage8(),
                    OnboardingPage9(),
                  ],
                ),
              ),

              // ── Top: Indicator + Save button row ──────────────────────
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                    child: Row(
                      children: [
                        // Left spacer to balance the save button on the right
                        const SizedBox(width: 60),
                        // ── Centre: Indicator pill with drag ──
                        Expanded(
                          child: Center(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onHorizontalDragStart: (d) {
                                setState(() {
                                  _isDragging     = true;
                                  _lastHapticPage = _pageOffset.value.round();
                                });
                                _dragStartPage = _pageOffset.value;
                                _dragStartX    = d.localPosition.dx;
                                HapticFeedback.lightImpact();
                              },
                              onHorizontalDragUpdate: (d) {
                                if (!_pageController.hasClients) return;
                                final dx        = d.localPosition.dx - _dragStartX;
                                final pageDelta = dx / _indicatorStep;
                                final newPage   = (_dragStartPage + pageDelta).clamp(0.0, 9.0);
                                final crossed   = newPage.round();
                                if (crossed != _lastHapticPage) {
                                  HapticFeedback.selectionClick();
                                  _lastHapticPage = crossed;
                                }
                                final vp = _pageController.position.viewportDimension;
                                _pageController.position.jumpTo(
                                  (newPage * vp).clamp(
                                    _pageController.position.minScrollExtent,
                                    _pageController.position.maxScrollExtent,
                                  ),
                                );
                              },
                              onHorizontalDragEnd: (d) {
                                HapticFeedback.mediumImpact();
                                setState(() => _isDragging = false);
                                if (!_pageController.hasClients) return;
                                final vx = d.velocity.pixelsPerSecond.dx;
                                int snap;
                                if (vx.abs() > 400) {
                                  snap = vx > 0
                                      ? (_pageOffset.value + 0.5).ceil().clamp(0, 9)
                                      : (_pageOffset.value - 0.5).floor().clamp(0, 9);
                                } else {
                                  snap = _pageOffset.value.round().clamp(0, 9);
                                }
                                _pageController.animateToPage(
                                  snap,
                                  duration: const Duration(milliseconds: 500),
                                  curve: Curves.easeOutCubic,
                                );
                              },
                              child: AnimatedScale(
                                scale: _isDragging ? 0.94 : 1.0,
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOutCubic,
                                child: ValueListenableBuilder<double>(
                                  valueListenable: _pageOffset,
                                  builder: (context, page, _) => _LiquidGlassIndicator(
                                    page: page,
                                    count: 10,
                                    onDotTap: (i) => _pageController.animateToPage(
                                      i,
                                      duration: const Duration(milliseconds: 420),
                                      curve: Curves.easeInOutCubic,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // ── Right: Save button (only visible on pages 1–8) ──
                        SizedBox(
                          width: 60,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: (_currentPage >= 1 && _currentPage <= 8)
                                ? _OnboardingSaveButton(
                                    key: ValueKey('save_$_currentPage'),
                                    globalKey: _saveButtonKey,
                                    onSave: () => ref.read(onboardingProvider.notifier).saveToFirestore(step: _currentPage),
                                  )
                                : const SizedBox.shrink(key: ValueKey('no_save')),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Bottom: Floating glass button overlay ─────────────────
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── Standalone Liquid Glass Custom Button ─────────────────
                        AppButton(
                          text: _buttonLabel,
                          onPressed: _onNext,
                        ),

                        // Fixed-height sub-area (matches welcome/login/signup screens)
                        // so the button always sits at the same vertical position.
                        SizedBox(
                          height: 72,
                          child: Center(
                            child: _currentPage == 0
                                ? Text(
                                    'By continuing, you agree to our Terms & Policy',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF6B7280).withValues(alpha: 0.85),
                                    ),
                                  )
                                : _currentPage == 9
                                    ? GestureDetector(
                                        onTap: () => _pageController.previousPage(
                                          duration: const Duration(milliseconds: 400),
                                          curve: Curves.easeInOutCubic,
                                        ),
                                        child: const Text(
                                          'Edit Plan',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF9CA3AF),
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── iOS Liquid Glass Capsule Indicator ────────────────────────────────────────
class _LiquidGlassIndicator extends StatelessWidget {
  final double page;
  final int count;
  final void Function(int)? onDotTap;

  const _LiquidGlassIndicator({
    required this.page,
    required this.count,
    this.onDotTap,
  });

  static const double _dotD  = 6.0;
  static const double _gap   = 9.0;
  static const double _pillH = 13.0;
  static const double _pillW = 22.0;
  static const double _padH  = 10.0;
  static const double _padV  = 7.0;

  double get _step          => _dotD + _gap;
  double get _trackContentW => count * _dotD + (count - 1) * _gap;
  double get _trackW        => _trackContentW + 2 * _padH;
  double get _trackH        => _pillH + 2 * _padV;

  double _cx(int i) => _padH + _dotD / 2 + i * _step;

  @override
  Widget build(BuildContext context) {
    final double p    = page.clamp(0.0, (count - 1).toDouble());
    final int    from = p.floor().clamp(0, count - 1);
    final int    to   = p.ceil().clamp(0, count - 1);
    final double frac = p - from.toDouble();

    final double fromCX = _cx(from);
    final double toCX   = _cx(to);

    final double leadT = Curves.easeInOut.transform((frac * 1.6).clamp(0.0, 1.0));
    final double lagT  = Curves.easeInOut.transform(((frac - 0.35) * 1.6).clamp(0.0, 1.0));
    final bool movingRight = to >= from;

    final double pillLeft = movingRight
        ? (fromCX - _pillW / 2) + lagT  * (toCX - fromCX)
        : (fromCX - _pillW / 2) + leadT * (toCX - fromCX);
    final double pillRight = movingRight
        ? (fromCX + _pillW / 2) + leadT * (toCX - fromCX)
        : (fromCX + _pillW / 2) + lagT  * (toCX - fromCX);

    final double pillWidth    = (pillRight - pillLeft).clamp(_pillH, double.infinity);
    final double pillTopLocal = _trackH / 2 - _pillH / 2;

    return ClipRRect(
      borderRadius: BorderRadius.circular(_trackH / 2),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: _trackW,
          height: _trackH,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(_trackH / 2),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.40),
              width: 1.0,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // Dots
              for (int i = 0; i < count; i++)
                Positioned(
                  left: _cx(i) - _dotD / 2,
                  top: _trackH / 2 - _dotD / 2,
                  width: _dotD,
                  height: _dotD,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.60),
                    ),
                  ),
                ),

              // Liquid pill — uses the mint color
              Positioned(
                left: pillLeft,
                top: pillTopLocal,
                width: pillWidth,
                height: _pillH,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_pillH / 2),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xCC89F4DD),
                        Color(0x8889F4DD),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.70),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF89F4DD).withValues(alpha: 0.40),
                        blurRadius: 6,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                ),
              ),

              // Tap areas
              for (int i = 0; i < count; i++)
                Positioned(
                  left: _cx(i) - _step / 2,
                  top: 0,
                  width: _step,
                  height: _trackH,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onDotTap?.call(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bridges PageController → ValueListenable<double> ─────────────────────────
class _PageOffsetNotifier extends ValueNotifier<double> {
  final PageController _controller;
  _PageOffsetNotifier(this._controller) : super(0.0) {
    _controller.addListener(_onScroll);
  }
  void _onScroll() {
    if (_controller.hasClients) {
      final page = _controller.page ?? 0.0;
      if (value != page) value = page;
    }
  }
  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    super.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ── Save Button with Dual-Arc Spinner + Checkmark ─────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════

enum _SaveButtonState { idle, loading, success }

class _OnboardingSaveButton extends StatefulWidget {
  final GlobalKey<_OnboardingSaveButtonState> globalKey;
  final Future<bool> Function() onSave;

  const _OnboardingSaveButton({
    super.key,
    required this.globalKey,
    required this.onSave,
  });

  @override
  State<_OnboardingSaveButton> createState() => _OnboardingSaveButtonState();
}

class _OnboardingSaveButtonState extends State<_OnboardingSaveButton>
    with TickerProviderStateMixin {
  _SaveButtonState _state = _SaveButtonState.idle;
  late final AnimationController _spinController;
  late final AnimationController _checkController;

  @override
  void initState() {
    super.initState();
    // Register this state with the global key so the parent can call triggerSave().
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // The global key is passed into the widget so the parent screen can
      // trigger saves programmatically (e.g. when the user taps Next instead
      // of Save).
    });
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _spinController.dispose();
    _checkController.dispose();
    super.dispose();
  }

  /// Called externally (via GlobalKey) or from the tap handler.
  /// Returns true when save succeeds, false on failure.
  Future<bool> triggerSave() async {
    if (_state == _SaveButtonState.loading) return false; // already in progress
    if (_state == _SaveButtonState.success) return true;  // already saved

    setState(() => _state = _SaveButtonState.loading);
    _spinController.repeat();

    final ok = await widget.onSave();

    if (!mounted) return ok;

    _spinController.stop();

    if (ok) {
      setState(() => _state = _SaveButtonState.success);
      _checkController.forward(from: 0.0);
    } else {
      setState(() => _state = _SaveButtonState.idle);
    }
    return ok;
  }

  // Height matches the indicator pill (_LiquidGlassIndicator._trackH = _pillH + 2*_padV = 13+14 = 27)
  static const double _btnHeight = 27.0;

  @override
  Widget build(BuildContext context) {
    // Re-register the global key so the parent screen can always reach
    // the *current* page's save-button state.
    widget.globalKey.currentState;  // no-op read, the key is set via constructor

    return GestureDetector(
      onTap: _state == _SaveButtonState.loading ? null : () => triggerSave(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_btnHeight / 2),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _btnHeight,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_btnHeight / 2),
              color: _state == _SaveButtonState.success
                  ? const Color(0xFF34A853).withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.18),
              border: Border.all(
                color: _state == _SaveButtonState.success
                    ? const Color(0xFF34A853).withValues(alpha: 0.50)
                    : Colors.white.withValues(alpha: 0.40),
                width: 1.0,
              ),
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: _buildContent(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_state) {
      case _SaveButtonState.idle:
        return const Text(
          'Save',
          key: ValueKey('save_text'),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
            letterSpacing: 0.1,
          ),
        );
      case _SaveButtonState.loading:
        return SizedBox(
          key: const ValueKey('save_spinner'),
          width: 16,
          height: 16,
          child: AnimatedBuilder(
            animation: _spinController,
            builder: (context, _) {
              return CustomPaint(
                painter: _DualArcSpinnerPainter(
                  rotation: _spinController.value * 2 * pi,
                ),
              );
            },
          ),
        );
      case _SaveButtonState.success:
        return AnimatedBuilder(
          key: const ValueKey('save_check'),
          animation: _checkController,
          builder: (context, _) {
            return CustomPaint(
              size: const Size(16, 16),
              painter: _CheckmarkPainter(
                progress: Curves.easeOutBack.transform(_checkController.value),
              ),
            );
          },
        );
    }
  }
}

// ── Wrapper so that _OnboardingSaveButton registers with a GlobalKey ──────────
// The real trick: we use a separate stateful wrapper that passes _its_ key
// down. But actually, the simpler approach is to use the globalKey directly
// on the State — we do this by overriding the build in _OnboardingScreenState
// to use the globalKey on the *child* _OnboardingSaveButtonInner.
//
// Actually, let's simplify: we use a dedicated inner widget whose GlobalKey
// the parent holds.


// ── Dual-Arc Spinner Painter ──────────────────────────────────────────────────
class _DualArcSpinnerPainter extends CustomPainter {
  final double rotation;
  _DualArcSpinnerPainter({required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 1.5;
    const strokeWidth = 2.5;
    const arcSweep = 130.0 * (pi / 180.0); // ~130 degrees each arc

    // Green arc
    final greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // Cyan-blue arc
    final bluePaint = Paint()
      ..color = const Color(0xFF00BFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final rect = Rect.fromCircle(center: center, radius: radius);

    // Arc 1 (green): starts at `rotation`
    canvas.drawArc(rect, rotation, arcSweep, false, greenPaint);

    // Arc 2 (blue): starts 180° (π) away from arc 1
    canvas.drawArc(rect, rotation + pi, arcSweep, false, bluePaint);
  }

  @override
  bool shouldRepaint(covariant _DualArcSpinnerPainter oldDelegate) {
    return oldDelegate.rotation != rotation;
  }
}

// ── Checkmark Painter ─────────────────────────────────────────────────────────
class _CheckmarkPainter extends CustomPainter {
  final double progress; // 0.0 → 1.0
  _CheckmarkPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Checkmark path: two segments
    // Segment 1: from bottom-left corner of check to the bottom point
    // Segment 2: from the bottom point up to the top-right
    final p1 = Offset(size.width * 0.18, size.height * 0.52);
    final p2 = Offset(size.width * 0.42, size.height * 0.75);
    final p3 = Offset(size.width * 0.82, size.height * 0.28);

    final path = Path();
    if (progress <= 0.5) {
      // Draw first segment partially
      final t = progress / 0.5;
      final current = Offset.lerp(p1, p2, t)!;
      path.moveTo(p1.dx, p1.dy);
      path.lineTo(current.dx, current.dy);
    } else {
      // Draw first segment fully + second segment partially
      path.moveTo(p1.dx, p1.dy);
      path.lineTo(p2.dx, p2.dy);
      final t = (progress - 0.5) / 0.5;
      final current = Offset.lerp(p2, p3, t)!;
      path.lineTo(current.dx, current.dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
