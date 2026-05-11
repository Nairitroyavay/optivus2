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
import '../../views/settings/notification_settings_screen.dart';
import '../../views/settings/mvp_info_screen.dart';
import '../../views/notifications/notification_center_screen.dart';

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
        path: '/home/routine',
        builder: (_, __) => const HomeScreen(initialIndex: 1),
      ),
      GoRoute(
        path: '/home/tracker',
        builder: (_, __) => const HomeScreen(initialIndex: 2),
      ),
      GoRoute(
        path: '/home/coach',
        builder: (_, __) => const HomeScreen(initialIndex: 3),
      ),
      GoRoute(
        path: '/home/goals',
        builder: (_, __) => const HomeScreen(initialIndex: 4),
      ),
      GoRoute(
        path: '/home/profile',
        builder: (_, __) => const HomeScreen(initialIndex: 5),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotificationCenterScreen(),
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
        path: '/identities/new',
        builder: (_, __) => const MvpInfoScreen(
          title: 'Add Identity',
          icon: Icons.person_add_alt_1_rounded,
          accentColor: Color(0xFFC48E33),
          statusLabel: 'Identity creation is handled in onboarding',
          body:
              'Editing identities post-onboarding is deferred for MVP testing. This ensures focus on core tracker mechanics.',
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
        path: '/settings/notifications',
        builder: (_, __) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/subscription',
        builder: (_, __) => const MvpInfoScreen(
          title: 'Subscription',
          icon: Icons.workspace_premium_outlined,
          accentColor: Color(0xFFC48E33),
          statusLabel: 'Free internal testing build',
          body:
              'Subscriptions and AI usage caps are deferred for MVP testing. All enabled features remain usable without a payment step in this build.',
        ),
      ),
      GoRoute(
        path: '/settings/security',
        builder: (_, __) => const MvpInfoScreen(
          title: 'Security',
          icon: Icons.lock_outline_rounded,
          accentColor: Color(0xFFD66A3D),
          statusLabel: 'Account security is handled by Firebase Auth',
          body:
              'Email and password changes are deferred for this internal build. Sign out and delete-account controls remain available from Profile.',
        ),
      ),
      GoRoute(
        path: '/support/report-bug',
        builder: (_, __) => const MvpInfoScreen(
          title: 'Report Bug',
          icon: Icons.bug_report_outlined,
          accentColor: Color(0xFFD66A3D),
          statusLabel: 'Bug reporting page pending',
          body:
              'Cloudflare Pages support forms ship in the release-readiness task. For internal testing, report issues through the tester feedback channel with your device model and steps to reproduce.',
        ),
      ),
      GoRoute(
        path: '/support/help',
        builder: (_, __) => const MvpInfoScreen(
          title: 'Help Center',
          icon: Icons.help_outline_rounded,
          accentColor: Color(0xFF4B8EE3),
          statusLabel: 'Help center page pending',
          body:
              'The public support page will be hosted on Cloudflare Pages before Play Store submission. Core in-app flows remain reachable from the bottom tabs and Profile settings.',
        ),
      ),
      GoRoute(
        path: '/legal/terms',
        builder: (_, __) => const MvpInfoScreen(
          title: 'Terms of Use',
          icon: Icons.description_outlined,
          accentColor: Color(0xFF4DB685),
          statusLabel: 'Terms page pending',
          body:
              'The final legal page will be a Cloudflare Pages URL before release. This internal build keeps the entry point visible without using Firebase Hosting.',
        ),
      ),
      GoRoute(
        path: '/legal/privacy',
        builder: (_, __) => const MvpInfoScreen(
          title: 'Privacy Policy',
          icon: Icons.privacy_tip_outlined,
          accentColor: Color(0xFF5E4B9C),
          statusLabel: 'Privacy page pending',
          body:
              'The final privacy policy will be hosted on Cloudflare Pages and aligned with Play Store Data Safety. The app stores user data under the signed-in user document in Firestore and uses Cloudflare Workers/R2 for enabled backend and file flows.',
        ),
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
