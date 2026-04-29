import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../views/screens/welcome_screen.dart';
import '../../views/screens/login_screen.dart';
import '../../views/screens/signup_screen.dart';
import '../../views/screens/onboarding_screen.dart';
import '../../views/screens/home_screen.dart';
import '../../views/screens/loading_screen.dart';

import '../providers/bootstrap_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // A ValueNotifier used solely as a refresh signal for GoRouter.
  // Whenever the bootstrap state changes, the notifier fires and GoRouter
  // re-evaluates the redirect function.
  final listenable = ValueNotifier<BootstrapState>(BootstrapState.initializing);

  ref.listen<BootstrapState>(
    bootstrapProvider,
    (_, next) => listenable.value = next,
    fireImmediately: true,
  );

  ref.onDispose(listenable.dispose);

  return GoRouter(
    initialLocation: '/loading',
    refreshListenable: listenable,
    redirect: (context, state) {
      // Pure state machine: the router reads the bootstrap state and
      // unconditionally returns the canonical route for that state.
      // All async resolution (auth, Firestore checks) is owned exclusively
      // by AppBootstrapNotifier — never performed here.
      final bootstrapState = ref.read(bootstrapProvider);

      switch (bootstrapState) {
        case BootstrapState.initializing:
          return '/loading';
        case BootstrapState.unauthenticated:
          return '/login';
        case BootstrapState.needsOnboarding:
          return '/onboarding';
        case BootstrapState.ready:
          return '/home';
      }
    },
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
});

