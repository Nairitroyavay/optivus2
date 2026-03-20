import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/onboarding_provider.dart';
import '../home_screen.dart';
import 'widgets/app_button.dart';
import 'onboarding/onboarding_page_0.dart';
import 'onboarding/onboarding_page_1.dart';
import 'onboarding/onboarding_page_2.dart';
import 'onboarding/onboarding_page_3.dart';
import 'onboarding/onboarding_page_4.dart';
import 'onboarding/onboarding_page_5.dart';
import 'onboarding/onboarding_page_6.dart';
import 'onboarding/onboarding_page_7.dart';
import 'onboarding/onboarding_page_8.dart';
import 'onboarding/onboarding_page_9.dart';

// Shared layout constants so pages know how much to inset
const double kIndicatorOverlayH = 44.0;  // top glass overlay height
const double kButtonOverlayH    = 140.0; // bottom glass overlay height (button + 72px sub-area)

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  late final _PageOffsetNotifier _pageOffset;
  int _currentPage = 0;

  double _dragStartPage = 0.0;
  double _dragStartX    = 0.0;
  bool   _isDragging    = false;
  int    _lastHapticPage = 0;
  static const double _indicatorStep = 48.0;

  @override
  void initState() {
    super.initState();
    _pageOffset = _PageOffsetNotifier(_pageController);
  }

  @override
  void dispose() {
    _pageOffset.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onNext() async {
    if (_currentPage < 9) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      await ref.read(onboardingProvider.notifier).saveToFirestore();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
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
                    ref.read(onboardingProvider.notifier).saveToFirestore();
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

              // ── Top: Indicator (no outer glass — pill has its own blur) ──
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Center(
                    heightFactor: 1.0,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
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
