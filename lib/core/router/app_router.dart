import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../views/screens/welcome_screen.dart';
import '../../views/screens/login_screen.dart';
import '../../views/screens/signup_screen.dart';
import '../../views/screens/onboarding_screen.dart';
import '../../views/screens/home_screen.dart';
import '../../views/screens/loading_screen.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AUTH NOTIFIER — triggers GoRouter redirect on auth state changes
// ─────────────────────────────────────────────────────────────────────────────
class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      _userDocSub?.cancel();

      if (user != null) {
        // Mark loading until the first Firestore snapshot arrives
        _isLoading = true;

        _userDocSub = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots()
            .listen((doc) {
          if (doc.exists) {
            userModel = UserModel.fromFirestore(doc);
          } else {
            // 🚨 Auto-create user document (failsafe) — prevents null userModel
            final currentUser = FirebaseAuth.instance.currentUser!;
            final newUser = UserModel(
              id: currentUser.uid,
              email: currentUser.email ?? '',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              hasCompletedOnboarding: false,
              onboardingStep: 0,
            );

            FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .set(newUser.toMap());

            userModel = newUser;
          }

          // First snapshot received — loading complete
          _isLoading = false;
          notifyListeners();
        });
      } else {
        // Logged out — immediately resolved (no doc to wait for)
        userModel = null;
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  late final StreamSubscription<User?> _authSub;
  StreamSubscription<DocumentSnapshot>? _userDocSub;

  UserModel? userModel;

  /// True while we are waiting for the first Firestore userModel snapshot.
  /// During this window we show [LoadingScreen] to avoid premature redirects.
  bool _isLoading = true;
  bool get isLoading => _isLoading;

  @override
  void dispose() {
    _authSub.cancel();
    _userDocSub?.cancel();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// APP ROUTER — single source of truth for all top-level navigation
// ─────────────────────────────────────────────────────────────────────────────
class AppRouter {
  AppRouter._(); // prevent instantiation

  static final _AuthNotifier _authNotifier = _AuthNotifier();

  static UserModel? get currentUserModel => _authNotifier.userModel;

  /// The app-wide [GoRouter] instance.
  /// Pass this to [MaterialApp.router] via `routerConfig`.
  static final GoRouter router = GoRouter(
    initialLocation: '/loading',
    refreshListenable: _authNotifier,

    // ── Redirect logic (the brain) ────────────────────────────────────────
    redirect: (BuildContext context, GoRouterState state) {
      final loading = _authNotifier.isLoading;
      final loggedIn = FirebaseAuth.instance.currentUser != null;
      final location = state.matchedLocation;

      // ── Loading gate ──────────────────────────────────────────────────
      // Hold all traffic on /loading until userModel resolves.
      if (loading) {
        return location == '/loading' ? null : '/loading';
      }

      // Past this point, userModel has resolved (may still be null if logged out).

      // Routes that unauthenticated users are allowed to visit
      final isAuthRoute =
          location == '/' || location == '/login' || location == '/signup';

      // Not logged in → only allow auth routes; otherwise send to welcome
      if (!loggedIn && !isAuthRoute) return '/';

      // Leave /loading as soon as resolved
      if (location == '/loading') {
        if (!loggedIn) return '/';
        // Fall through to logged-in checks below
      }

      if (loggedIn) {
        final userModel = _authNotifier.userModel;

        // Treat unresolved doc as new user (extra safety net)
        if (userModel == null) return '/onboarding';

        if (userModel.hasCompletedOnboarding) {
          // Onboarding done → send to home
          if (isAuthRoute ||
              location == '/onboarding' ||
              location == '/loading') {
            return '/home';
          }
        } else {
          // Onboarding pending → keep on /onboarding
          if (location != '/onboarding') return '/onboarding';
        }
      }

      // Otherwise, proceed as intended
      return null;
    },

    // ── Route table ───────────────────────────────────────────────────────
    routes: [
      GoRoute(
        path: '/loading',
        builder: (_, __) => const LoadingScreen(),
      ),
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
