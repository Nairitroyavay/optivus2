import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';
import 'widgets/app_button.dart';
import 'widgets/liquid_glass_panel.dart';

// ─────────────────────────────────────────────────────────────────────────────
// COLOUR TOKENS
// ─────────────────────────────────────────────────────────────────────────────
const _kInk    = Color(0xFF0F111A);
const _kSub    = Color(0xFF6B7280);
const _kAmber  = Color(0xFFFFB830);
const _kGreen  = Color(0xFF22C55E);
const _kRed    = Color(0xFFEF4444);
const _kCream  = Color(0xFFF6E6B4);
const _kBg     = Color(0xFFFCF8EE);

// ─────────────────────────────────────────────────────────────────────────────
// PASSWORD RULE MODEL
// ─────────────────────────────────────────────────────────────────────────────
class _Rule {
  final String label;
  final bool Function(String) check;
  const _Rule({required this.label, required this.check});
}

final _passwordRules = [
  _Rule(
    label: 'At least 8 characters',
    check: (p) => p.length >= 8,
  ),
  _Rule(
    label: 'Starts with a capital letter',
    check: (p) => p.isNotEmpty && p[0] == p[0].toUpperCase() && p[0].contains(RegExp(r'[A-Z]')),
  ),
  _Rule(
    label: 'Contains a number (0–9)',
    check: (p) => p.contains(RegExp(r'[0-9]')),
  ),
  _Rule(
    label: 'Contains a special character (!@#\$%^&*)',
    check: (p) => p.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=\[\]\\\/~`]')),
  ),
];

bool _isPasswordValid(String password) =>
    _passwordRules.every((r) => r.check(password));

// ─────────────────────────────────────────────────────────────────────────────
// SIGNUP SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  // Controllers
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passCtrl     = TextEditingController();
  final _confirmCtrl  = TextEditingController();

  // Focus nodes
  final _nameFocus    = FocusNode();
  final _emailFocus   = FocusNode();
  final _passFocus    = FocusNode();
  final _confirmFocus = FocusNode();

  bool _obscurePass    = true;
  bool _obscureConfirm = true;
  bool _loading        = false;
  bool _showRules      = false; // shows rules panel once user starts typing password
  String? _errorMsg;

  // Animation for rule panel sliding in
  late AnimationController _ruleCtrl;
  late Animation<double>   _ruleSlide;

  @override
  void initState() {
    super.initState();
    _ruleCtrl  = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 300));
    _ruleSlide = CurvedAnimation(parent: _ruleCtrl, curve: Curves.easeOutCubic);

    _passCtrl.addListener(() {
      final show = _passCtrl.text.isNotEmpty;
      if (show != _showRules) {
        setState(() => _showRules = show);
        show ? _ruleCtrl.forward() : _ruleCtrl.reverse();
      } else {
        setState(() {}); // refresh rule ticks
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    _confirmFocus.dispose();
    _ruleCtrl.dispose();
    super.dispose();
  }

  // ── Validation ──────────────────────────────────────────────────────────

  String? _validate() {
    final name    = _nameCtrl.text.trim();
    final email   = _emailCtrl.text.trim();
    final pass    = _passCtrl.text;
    final confirm = _confirmCtrl.text;

    if (name.isEmpty)  return 'Please enter your full name.';
    if (name.length < 2) return 'Name must be at least 2 characters.';
    if (email.isEmpty) return 'Please enter your email address.';
    if (!RegExp(r'^[\w\.\+\-]+@[\w\-]+\.[a-z]{2,}$', caseSensitive: false)
        .hasMatch(email)) {
      return 'Please enter a valid email address.';
    }
    if (pass.isEmpty)  return 'Please enter a password.';
    if (!_isPasswordValid(pass)) {
      return 'Password does not meet all requirements below.';
    }
    if (confirm != pass) return 'Passwords do not match.';
    return null;
  }

  // ── Firebase create account ─────────────────────────────────────────────

  Future<void> _createAccount() async {
    FocusScope.of(context).unfocus();

    final error = _validate();
    if (error != null) {
      setState(() => _errorMsg = error);
      return;
    }

    setState(() { _loading = true; _errorMsg = null; });

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email:    _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );

      // Update display name
      await credential.user?.updateDisplayName(_nameCtrl.text.trim());

      if (!mounted) return;

      // Navigate to onboarding
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'email-already-in-use':
            _errorMsg = 'An account with this email already exists.';
            break;
          case 'invalid-email':
            _errorMsg = 'The email address is not valid.';
            break;
          case 'operation-not-allowed':
            _errorMsg = 'Email/password accounts are not enabled.';
            break;
          case 'weak-password':
            _errorMsg = 'Password is too weak. Please follow the rules below.';
            break;
          default:
            _errorMsg = 'Sign up failed. Please try again.';
        }
      });
    } catch (_) {
      setState(() => _errorMsg = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_kCream, _kBg],
            stops: [0.0, 0.45],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 40),

                      // Icon
                      Container(
                        width: 64, height: 64,
                        decoration: const BoxDecoration(
                          color: _kInk, shape: BoxShape.circle),
                        child: const Center(
                          child: Icon(Icons.diamond_outlined,
                              color: Colors.white, size: 28)),
                      ),
                      const SizedBox(height: 28),

                      // Title
                      const Text('Join the top 1%.',
                          style: TextStyle(
                            fontSize: 34, fontWeight: FontWeight.w900,
                            color: _kInk, letterSpacing: -1,
                          )),
                      const SizedBox(height: 8),
                      Text('Create your Optivus account.',
                          style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w500,
                            color: Colors.blueGrey.shade600,
                          )),
                      const SizedBox(height: 36),

                      // Form panel
                      LiquidGlassPanel(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Full Name
                            _FieldLabel('Full Name'),
                            const SizedBox(height: 6),
                            _GlassInput(
                              controller: _nameCtrl,
                              focusNode:  _nameFocus,
                              hint:       'Nairit Roy',
                              icon:       Icons.person_outline,
                              next:       _emailFocus,
                            ),
                            const SizedBox(height: 18),

                            // Email
                            _FieldLabel('Email'),
                            const SizedBox(height: 6),
                            _GlassInput(
                              controller:   _emailCtrl,
                              focusNode:    _emailFocus,
                              hint:         'you@example.com',
                              icon:         Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              next:         _passFocus,
                            ),
                            const SizedBox(height: 18),

                            // Password
                            _FieldLabel('Password'),
                            const SizedBox(height: 6),
                            _GlassInput(
                              controller: _passCtrl,
                              focusNode:  _passFocus,
                              hint:       'Min 8 chars, capital, number, sign',
                              icon:       Icons.lock_outline,
                              obscure:    _obscurePass,
                              next:       _confirmFocus,
                              suffix: _EyeButton(
                                obscure:  _obscurePass,
                                onToggle: () => setState(
                                    () => _obscurePass = !_obscurePass),
                              ),
                            ),

                            // Live password rules panel
                            SizeTransition(
                              sizeFactor: _ruleSlide,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: _PasswordRulesPanel(
                                    password: _passCtrl.text),
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Confirm Password
                            _FieldLabel('Confirm Password'),
                            const SizedBox(height: 6),
                            _GlassInput(
                              controller: _confirmCtrl,
                              focusNode:  _confirmFocus,
                              hint:       'Repeat your password',
                              icon:       Icons.lock_outline,
                              obscure:    _obscureConfirm,
                              onSubmit:   (_) => _createAccount(),
                              suffix: _EyeButton(
                                obscure:  _obscureConfirm,
                                onToggle: () => setState(
                                    () => _obscureConfirm = !_obscureConfirm),
                              ),
                            ),

                            // Confirm match indicator
                            if (_confirmCtrl.text.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: _MatchIndicator(
                                  pass:    _passCtrl.text,
                                  confirm: _confirmCtrl.text,
                                ),
                              ),

                            const SizedBox(height: 20),

                            // Terms
                            Text(
                              'By joining, you agree to our Terms of Service.',
                              style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      // Error message
                      if (_errorMsg != null) ...[
                        const SizedBox(height: 16),
                        _ErrorBanner(message: _errorMsg!),
                      ],

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),

              // Create Account button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _loading
                    ? const _LoadingPill()
                    : AppButton(
                        text: 'Create Account',
                        onPressed: _createAccount,
                      ),
              ),
              const SizedBox(height: 20),

              // Go to login
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Already have an account?',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 14)),
                    TextButton(
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const LoginScreen()),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: _kInk,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Log in',
                          style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14)),
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

// ─────────────────────────────────────────────────────────────────────────────
// LIVE PASSWORD RULES PANEL
// ─────────────────────────────────────────────────────────────────────────────
class _PasswordRulesPanel extends StatelessWidget {
  final String password;
  const _PasswordRulesPanel({required this.password});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.60),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.80), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Password requirements',
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: _kSub, letterSpacing: 0.5,
                  )),
              const SizedBox(height: 10),
              ..._passwordRules.map((rule) {
                final passed = rule.check(password);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 18, height: 18,
                        decoration: BoxDecoration(
                          color: passed ? _kGreen : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: passed
                                ? _kGreen
                                : _kSub.withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                        ),
                        child: passed
                            ? const Icon(Icons.check_rounded,
                                size: 11, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: passed
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: passed ? _kGreen : _kSub,
                          ),
                          child: Text(rule.label),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PASSWORD MATCH INDICATOR
// ─────────────────────────────────────────────────────────────────────────────
class _MatchIndicator extends StatelessWidget {
  final String pass;
  final String confirm;
  const _MatchIndicator({required this.pass, required this.confirm});

  @override
  Widget build(BuildContext context) {
    final match = pass == confirm;
    return Row(
      children: [
        Icon(
          match ? Icons.check_circle_rounded : Icons.cancel_rounded,
          size: 15,
          color: match ? _kGreen : _kRed,
        ),
        const SizedBox(width: 6),
        Text(
          match ? 'Passwords match' : 'Passwords do not match',
          style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: match ? _kGreen : _kRed,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ERROR BANNER
// ─────────────────────────────────────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _kRed.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: _kRed.withValues(alpha: 0.35), width: 1),
          ),
          child: Row(
            children: [
              Icon(Icons.error_outline_rounded,
                  color: _kRed, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(message,
                    style: const TextStyle(
                      fontSize: 13, color: _kRed,
                      fontWeight: FontWeight.w600,
                    )),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOADING PILL  — replaces button while loading
// ─────────────────────────────────────────────────────────────────────────────
class _LoadingPill extends StatelessWidget {
  const _LoadingPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: _kInk.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.6), width: 1.5),
      ),
      child: const Center(
        child: SizedBox(
          width: 22, height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.5, color: _kInk),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FIELD LABEL
// ─────────────────────────────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w700,
          color: _kSub, letterSpacing: 0.4,
        ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EYE TOGGLE BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class _EyeButton extends StatelessWidget {
  final bool obscure;
  final VoidCallback onToggle;
  const _EyeButton({required this.obscure, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: IconButton(
        icon: Icon(
          obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: Colors.grey.shade600, size: 20,
        ),
        onPressed: onToggle,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GLASS INPUT  — liquid glass text field with controller + focus node
// ─────────────────────────────────────────────────────────────────────────────
class _GlassInput extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType keyboardType;
  final FocusNode? next;
  final Widget? suffix;
  final void Function(String)? onSubmit;

  const _GlassInput({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.icon,
    this.obscure     = false,
    this.keyboardType = TextInputType.text,
    this.next,
    this.suffix,
    this.onSubmit,
  });

  @override
  State<_GlassInput> createState() => _GlassInputState();
}

class _GlassInputState extends State<_GlassInput> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(() {
      setState(() => _focused = widget.focusNode.hasFocus);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: _focused ? 0.28 : 0.18),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: _focused
              ? _kAmber.withValues(alpha: 0.70)
              : Colors.white.withValues(alpha: 0.85),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _focused
                ? _kAmber.withValues(alpha: 0.18)
                : Colors.black.withValues(alpha: 0.08),
            blurRadius: _focused ? 18 : 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.50),
            blurRadius: 16, spreadRadius: -2,
            offset: const Offset(-2, -2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28.5),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Stack(children: [
            // Top-left specular rim
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28.5),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: const [0.0, 0.15, 0.4, 1.0],
                    colors: [
                      Colors.white.withValues(alpha: 0.95),
                      Colors.white.withValues(alpha: 0.40),
                      Colors.white.withValues(alpha: 0.0),
                      Colors.black.withValues(alpha: 0.03),
                    ],
                  ),
                ),
              ),
            ),
            TextField(
              controller:  widget.controller,
              focusNode:   widget.focusNode,
              obscureText: widget.obscure,
              keyboardType: widget.keyboardType,
              textInputAction: widget.next != null
                  ? TextInputAction.next
                  : TextInputAction.done,
              onSubmitted: widget.onSubmit ??
                  (_) {
                    if (widget.next != null) {
                      FocusScope.of(context).requestFocus(widget.next);
                    }
                  },
              style: const TextStyle(
                color: Color(0xFF1E202A),
                fontWeight: FontWeight.w600,
                fontSize: 16, letterSpacing: 0.3,
              ),
              cursorColor: _kAmber,
              decoration: InputDecoration(
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.white.withValues(alpha: 0.25),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 1),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            offset: const Offset(2, 2),
                            blurRadius: 6),
                        BoxShadow(
                            color: Colors.white.withValues(alpha: 0.6),
                            offset: const Offset(-2, -2),
                            blurRadius: 6),
                      ],
                    ),
                    child: Icon(widget.icon,
                        color: _focused ? _kAmber : const Color(0xFF1E202A),
                        size: 22),
                  ),
                ),
                suffixIcon: widget.suffix,
                hintText: widget.hint,
                hintStyle: TextStyle(
                  color: const Color(0xFF1E202A).withValues(alpha: 0.40),
                  fontWeight: FontWeight.w500,
                  fontSize: 14, letterSpacing: 0.2,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 18),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
