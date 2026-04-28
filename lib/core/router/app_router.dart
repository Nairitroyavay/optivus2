import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../views/screens/welcome_screen.dart';
import '../../views/screens/login_screen.dart';
import '../../views/screens/signup_screen.dart';
import '../../views/screens/onboarding_screen.dart';
import '../../views/screens/home_screen.dart';

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
        _userDocSub = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots()
            .listen((doc) {
          if (doc.exists) {
            userModel = UserModel.fromFirestore(doc);
          } else {
            userModel = null;
          }
          notifyListeners();
        });
      } else {
        userModel = null;
        notifyListeners();
      }
    });
  }

  late final StreamSubscription<User?> _authSub;
  StreamSubscription<DocumentSnapshot>? _userDocSub;
  UserModel? userModel;

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

      if (loggedIn) {
        final userModel = _authNotifier.userModel;
        
        // If we just logged in but userModel hasn't arrived yet from Firestore
        // return null to stay on the current loading screen until the doc loads.
        if (userModel == null) return null;

        if (userModel.hasCompletedOnboarding) {
          // If completed onboarding, go to home
          if (isAuthRoute || location == '/onboarding') return '/home';
        } else {
          // If not completed onboarding, go to onboarding
          if (location != '/onboarding') return '/onboarding';
        }
      }

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
