import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../views/screens/welcome_screen.dart';
import '../../views/screens/login_screen.dart';
import '../../views/screens/signup_screen.dart';
import '../../views/screens/onboarding_screen.dart';
import '../../views/screens/home_screen.dart';
import '../../views/screens/loading_screen.dart';
import '../../views/habits/habit_detail_screen.dart';
import '../../views/habits/habit_editor_screen.dart';
import '../../views/streaks/streak_detail_screen.dart';

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
      final bootstrapState = ref.read(bootstrapProvider);
      final loc = state.matchedLocation;

      final isAuthRoute = loc == '/' || loc == '/login' || loc == '/signup';

      switch (bootstrapState) {
        case BootstrapState.initializing:
          if (loc != '/loading') return '/loading';
          return null;

        case BootstrapState.unauthenticated:
          if (!isAuthRoute) return '/';
          return null;

        case BootstrapState.needsOnboarding:
          if (loc != '/onboarding') return '/onboarding';
          return null;

        case BootstrapState.ready:
          if (isAuthRoute || loc == '/loading' || loc == '/onboarding') {
            return '/home';
          }
          return null;
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
      GoRoute(
        path: '/habits/new',
        builder: (_, __) => const HabitEditorScreen(),
      ),
      GoRoute(
        path: '/habits/:habitId',
        builder: (_, state) => HabitDetailScreen(
          habitId: state.pathParameters['habitId']!,
        ),
      ),
      GoRoute(
        path: '/habits/:habitId/edit',
        builder: (_, state) => HabitEditorScreen(
          habitId: state.pathParameters['habitId']!,
        ),
      ),
      GoRoute(
        path: '/streaks/:streakId',
        builder: (_, state) => StreakDetailScreen(
          streakId: state.pathParameters['streakId']!,
        ),
      ),
    ],
  );
});
