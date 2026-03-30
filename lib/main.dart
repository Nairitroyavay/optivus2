import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'welcome_screen.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import 'onboarding_screen.dart';
import 'home_screen.dart';

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

late final GoRouterRefreshStream _authRefreshStream;
late final GoRouter _router;

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
    } catch (e) {
      debugPrint('Firebase init failed: $e');
    }

    _authRefreshStream = GoRouterRefreshStream(
      FirebaseAuth.instance.authStateChanges(),
    );
    _router = GoRouter(
      initialLocation: '/',
      refreshListenable: _authRefreshStream,
      redirect: (context, state) {
        final user = FirebaseAuth.instance.currentUser;
        final isAuthRoute = state.uri.path == '/' ||
            state.uri.path == '/login' ||
            state.uri.path == '/signup';

        // Enforce auth: block non-auth routes when signed out
        if (user == null && !isAuthRoute) return '/';
        if (user != null) {
          if (state.uri.path == '/signup') {
            return '/onboarding';
          } else if (isAuthRoute) {
            return '/home';
          }
        }
        return null;
      },
      routes: [
        GoRoute(path: '/', builder: (_, __) => const WelcomeScreen()),
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
        GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
        GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      ],
    );

    runApp(const ProviderScope(child: OptivusApp()));
  }, (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
}

class OptivusApp extends StatelessWidget {
  const OptivusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Optivus',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFFB830)),
      ),
      routerConfig: _router,
    );
  }
}
