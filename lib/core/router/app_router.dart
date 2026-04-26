import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../views/screens/welcome_screen.dart';
import '../../views/screens/login_screen.dart';
import '../../views/screens/signup_screen.dart';
import '../../views/screens/onboarding_screen.dart';
import '../../views/screens/home_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AUTH NOTIFIER — triggers GoRouter redirect on auth state changes
// ─────────────────────────────────────────────────────────────────────────────
class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier() {
    _subscription = FirebaseAuth.instance
        .authStateChanges()
        .listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// APP ROUTER — single source of truth for all top-level navigation
// ─────────────────────────────────────────────────────────────────────────────
class AppRouter {
  AppRouter._(); // prevent instantiation

  static final _AuthNotifier _authNotifier = _AuthNotifier();

  /// The app-wide [GoRouter] instance.
  /// Pass this to [MaterialApp.router] via `routerConfig`.
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    refreshListenable: _authNotifier,

    // ── Redirect logic (the brain) ────────────────────────────────────────
    redirect: (BuildContext context, GoRouterState state) {
      final loggedIn = FirebaseAuth.instance.currentUser != null;
      final location = state.matchedLocation;

      // Routes that unauthenticated users are allowed to visit
      final isAuthRoute =
          location == '/' || location == '/login' || location == '/signup';

      // Not logged in → only allow auth routes; otherwise send to welcome
      if (!loggedIn && !isAuthRoute) return '/';

      // Logged in → don't let them sit on auth routes; send to home
      if (loggedIn && isAuthRoute) return '/home';

      // Otherwise, proceed as intended
      return null;
    },

    // ── Route table ───────────────────────────────────────────────────────
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (_, __) => const SignupScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (_, __) => const HomeScreen(),
      ),
    ],
  );
}
