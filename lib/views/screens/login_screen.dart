import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:optivus2/widgets/glass_logo.dart';
import 'package:optivus2/widgets/app_button.dart';
import 'package:optivus2/widgets/liquid_glass_panel.dart';
import 'package:optivus2/widgets/wavy_loading_indicator.dart';

// ─────────────────────────────────────────────────────────────────────────────
// COLOUR TOKENS
// ─────────────────────────────────────────────────────────────────────────────
const _kInk   = Color(0xFF0F111A);
const _kSub   = Color(0xFF6B7280);
const _kAmber = Color(0xFFFFB830);
const _kRed   = Color(0xFFEF4444);
const _kCream = Color(0xFFF6E6B4);
const _kBg    = Color(0xFFFCF8EE);

// ─────────────────────────────────────────────────────────────────────────────
// LOGIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();

  final _emailFocus = FocusNode();
  final _passFocus  = FocusNode();

  bool    _obscurePass = true;
  bool    _loading     = false;
  Future<void>? _authOperation;
  String? _errorMsg;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  // ── Validation ────────────────────────────────────────────────────────────

  String? _validate() {
    final email = _emailCtrl.text.trim();
    final pass  = _passCtrl.text;

    if (email.isEmpty) return 'Please enter your email address.';
    if (!RegExp(r'^[\w\.\+\-]+@[\w\-]+\.[a-z]{2,}$', caseSensitive: false)
        .hasMatch(email)) {
      return 'Please enter a valid email address.';
    }
    if (pass.isEmpty)  return 'Please enter your password.';
    if (pass.length < 8) return 'Password must be at least 8 characters.';
    return null;
  }

  // ── Firebase sign in ──────────────────────────────────────────────────────

  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();


    final error = _validate();
    if (error != null) {
      setState(() => _errorMsg = error);
      return;
    }

    final authCall = FirebaseAuth.instance.signInWithEmailAndPassword(
      email:    _emailCtrl.text.trim(),
      password: _passCtrl.text,
    );

    setState(() { 
      _loading = true; 
      _errorMsg = null;
      _authOperation = authCall.then((_) {});
    });

    try {
      await authCall;
      // GoRouter redirect handles navigation after auth state changes.
    } on FirebaseAuthException catch (e) {
      setState(() {
        _loading = false;
        switch (e.code) {
          case 'user-not-found':
            _errorMsg = 'No account found with this email.';
            break;
          case 'wrong-password':
            _errorMsg = 'Incorrect password. Please try again.';
            break;
          case 'invalid-email':
            _errorMsg = 'The email address is not valid.';
            break;
          case 'user-disabled':
            _errorMsg = 'This account has been disabled.';
            break;
          case 'too-many-requests':
            _errorMsg = 'Too many attempts. Please wait and try again.';
            break;
          case 'invalid-credential':
            _errorMsg = 'Email or password is incorrect.';
            break;
          default:
            _errorMsg = 'Sign in failed. Please try again.';
        }
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _errorMsg = 'Something went wrong. Please try again.';
      });
    }
  }

  // ── Forgot password ───────────────────────────────────────────────────────

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();

    if (email.isEmpty) {
      setState(() =>
          _errorMsg = 'Enter your email above to reset your password.');
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset email sent to $email'),
          backgroundColor: const Color(0xFF22C55E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMsg = e.code == 'user-not-found'
            ? 'No account found with this email.'
            : 'Failed to send reset email. Try again.';
      });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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
            stops: [0.0, 0.55],
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
                      const SizedBox(height: 50),

                      // Logo
                      const GlassLogo(),
                      const SizedBox(height: 32),

                      // Welcome back
                      const Text('Welcome back.',
                          style: TextStyle(
                            fontSize: 30, fontWeight: FontWeight.w900,
                            color: _kInk, letterSpacing: -0.8,
                          )),
                      const SizedBox(height: 6),
                      Text('Sign in to your Optivus account.',
                          style: TextStyle(
                            fontSize: 15, color: Colors.blueGrey.shade600,
                            fontWeight: FontWeight.w500,
                          )),
                      const SizedBox(height: 36),

                      // Form
                      LiquidGlassPanel(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                              hint:       'Your password',
                              icon:       Icons.lock_outline,
                              obscure:    _obscurePass,
                              onSubmit:   (_) => _signIn(),
                              suffix: Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: IconButton(
                                  icon: Icon(
                                    _obscurePass
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: Colors.grey.shade600, size: 20,
                                  ),
                                  onPressed: () => setState(
                                      () => _obscurePass = !_obscurePass),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Forgot password
                            Align(
                              alignment: Alignment.centerRight,
                              child: GestureDetector(
                                onTap: _forgotPassword,
                                child: const Text('Forgot Password?',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: _kAmber,
                                    )),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Error
                      if (_errorMsg != null) ...[
                        const SizedBox(height: 16),
                        _ErrorBanner(message: _errorMsg!),
                      ],

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),

              // Sign In button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _loading
                    ? _LoadingButton(operation: _authOperation)
                    : AppButton(
                        text: 'Sign In',
                        onPressed: _signIn,
                      ),
              ),
              const SizedBox(height: 20),

              // Go to signup
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Don't have an account?",
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 14)),
                    TextButton(
                      onPressed: () => context.go('/signup'),
                      style: TextButton.styleFrom(
                        foregroundColor: _kInk,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Sign Up',
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
// SHARED LOCAL WIDGETS
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
          child: Row(children: [
            Icon(Icons.error_outline_rounded, color: _kRed, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: const TextStyle(
                    fontSize: 13, color: _kRed,
                    fontWeight: FontWeight.w600,
                  )),
            ),
          ]),
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// LOADING BUTTON — glass pill with wavy spinner, mirrors AppButton dimensions
// ─────────────────────────────────────────────────────────────────────────────
class _LoadingButton extends StatelessWidget {
  final Future<void>? operation;

  const _LoadingButton({this.operation});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(33),
        color: const Color(0xFFD8E8EF).withValues(alpha: 0.45),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF92E0FF).withValues(alpha: 0.55),
            blurRadius: 22,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.55),
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: Colors.white.withValues(alpha: 0.40),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.75),
              width: 1.5,
            ),
          ),
          child: Center(
            child: WavyLoadingIndicator(size: 36, operation: operation),
          ),
        ),
      ),
    );
  }
}

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
    this.obscure      = false,
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
    widget.focusNode.addListener(
        () => setState(() => _focused = widget.focusNode.hasFocus));
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
                          color: Colors.white.withValues(alpha: 0.5), width: 1),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            offset: const Offset(2, 2), blurRadius: 6),
                        BoxShadow(
                            color: Colors.white.withValues(alpha: 0.6),
                            offset: const Offset(-2, -2), blurRadius: 6),
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
