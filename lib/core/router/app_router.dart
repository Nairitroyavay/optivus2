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
import '../../views/goals/identity_detail_screen.dart';
import '../../views/tabs/routine_settings_screen.dart';
import '../../views/routine/fixed_schedule_setup_screen.dart';
import '../../views/routine/skin_care_setup_screen.dart';
import '../../views/routine/eating_setup_screen.dart';
import '../../views/routine/class_setup_screen.dart';
import '../../views/routine/supplement_setup_screen.dart';
import '../../views/fitness/fitness_dashboard_screen.dart';
import '../../views/fitness/activity_selection_screen.dart';
import '../../views/fitness/activity_pre_start_screen.dart';
import '../../views/fitness/live_activity_tracking_screen.dart';
import '../../views/fitness/activity_summary_screen.dart';
import '../../views/fitness/activity_route_review_screen.dart';
import '../../views/fitness/activity_history_screen.dart';
import '../../views/fitness/activity_detail_screen.dart';
import '../../views/fitness/fitness_stats_screen.dart';
import '../../views/fitness/fitness_goals_screen.dart';
import '../../views/fitness/fitness_settings_screen.dart';
import '../../views/settings/archived_identities_screen.dart';

import '../providers/bootstrap_provider.dart';
import '../../providers/routine_provider.dart';

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
      GoRoute(
        path: '/identities/:goalId',
        builder: (_, state) => IdentityDetailScreen(
          goalId: state.pathParameters['goalId']!,
        ),
      ),
      GoRoute(
        path: '/settings/routine',
        builder: (_, __) => const RoutineSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/archived-identities',
        builder: (_, __) => const ArchivedIdentitiesScreen(),
      ),
      GoRoute(
        path: '/settings/fixed-schedule',
        builder: (context, __) => FixedScheduleSetupScreen(
          onComplete: () => context.pop(),
        ),
      ),
      GoRoute(
        path: '/settings/skin-care',
        builder: (context, __) => SkinCareSetupScreen(
          onComplete: () {
            ref.read(routineProvider.notifier).markSkinCareSetUp();
            context.pop();
          },
        ),
      ),
      GoRoute(
        path: '/settings/eating',
        builder: (context, __) => EatingSetupScreen(
          onComplete: () => context.pop(),
        ),
      ),
      GoRoute(
        path: '/settings/classes',
        builder: (context, __) => ClassSetupScreen(
          onComplete: () => context.pop(),
        ),
      ),
      GoRoute(
        path: '/settings/supplements',
        builder: (context, __) => SupplementSetupScreen(
          onComplete: () => context.pop(),
        ),
      ),
      GoRoute(
        path: '/fitness',
        builder: (_, __) => const FitnessDashboardScreen(),
      ),
      GoRoute(
        path: '/fitness/select',
        builder: (_, __) => const ActivitySelectionScreen(),
      ),
      GoRoute(
        path: '/fitness/stats',
        builder: (_, __) => const FitnessStatsScreen(),
      ),
      GoRoute(
        path: '/fitness/goals',
        builder: (_, __) => const FitnessGoalsScreen(),
      ),
      GoRoute(
        path: '/fitness/settings',
        builder: (_, __) => const FitnessSettingsScreen(),
      ),
      GoRoute(
        path: '/fitness/pre-start',
        builder: (_, state) => ActivityPreStartScreen(
          activityType: state.uri.queryParameters['type'] ?? 'running',
          routineTaskId: state.uri.queryParameters['routineTaskId'],
        ),
      ),
      GoRoute(
        path: '/fitness/live',
        builder: (_, __) => const LiveActivityTrackingScreen(),
      ),
      GoRoute(
        path: '/fitness/history',
        builder: (_, __) => const ActivityHistoryScreen(),
      ),
      GoRoute(
        path: '/fitness/activity/:activityId',
        builder: (_, state) => ActivityDetailScreen(
          activityId: state.pathParameters['activityId']!,
        ),
      ),
      GoRoute(
        path: '/fitness/activity/:activityId/summary',
        builder: (_, state) => ActivitySummaryScreen(
          activityId: state.pathParameters['activityId']!,
        ),
      ),
      GoRoute(
        path: '/fitness/activity/:activityId/route',
        builder: (_, state) => ActivityRouteReviewScreen(
          activityId: state.pathParameters['activityId']!,
        ),
      ),
    ],
  );
});
