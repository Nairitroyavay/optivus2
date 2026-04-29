import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Centralized error handler for the Optivus app.
///
/// Call [initialize] at the very top of [main] — before [Firebase.initializeApp]
/// — so that even errors during Firebase bootstrap are captured.
///
/// Once Firebase is confirmed healthy, call [setCrashlyticsEnabled] to start
/// piping errors to Firebase Crashlytics. Until that point all errors are
/// safely logged locally only, preventing any crash caused by accessing an
/// uninitialized Crashlytics instance.
class GlobalErrorHandler {
  GlobalErrorHandler._();

  /// Whether Crashlytics has been confirmed available.
  /// Set to true only after [setCrashlyticsEnabled] is called.
  static bool _crashlyticsEnabled = false;

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Hooks into [FlutterError.onError] and [PlatformDispatcher.instance.onError].
  /// Must be the first call inside [main], before [WidgetsFlutterBinding.ensureInitialized]
  /// is NOT required here — both hooks are safe to set at any point.
  static void initialize() {
    _hookFlutterErrors();
    _hookDartAsyncErrors();
  }

  /// Call this after [Firebase.initializeApp] succeeds to enable the
  /// Crashlytics pipe. Until this is called, errors are only logged locally.
  static void setCrashlyticsEnabled() {
    _crashlyticsEnabled = true;
    debugPrint('✅ [GlobalErrorHandler] Crashlytics reporting enabled.');
  }

  // ─── Private Hooks ─────────────────────────────────────────────────────────

  static void _hookFlutterErrors() {
    // Preserve the default handler so Flutter's red-box still appears in debug.
    final FlutterExceptionHandler? defaultHandler = FlutterError.onError;

    FlutterError.onError = (FlutterErrorDetails details) {
      // ── Structured log ──────────────────────────────────────────────────────
      debugPrint(
        '\n🔴 [Flutter Error] ───────────────────────────────────────────\n'
        '  Exception : ${details.exceptionAsString()}\n'
        '  Library   : ${details.library ?? "unknown"}\n'
        '  Context   : ${details.context?.toDescription() ?? "none"}\n'
        '──────────────────────────────────────────────────────────────',
      );
      if (details.stack != null) {
        debugPrint('  Stack Trace:\n${details.stack}');
      }

      // ── In debug: still show the red-box overlay ─────────────────────────
      if (!kReleaseMode) {
        defaultHandler?.call(details);
      }

      // ── In release: pipe to Crashlytics (non-fatal by default) ───────────
      if (_crashlyticsEnabled) {
        FirebaseCrashlytics.instance.recordFlutterError(details);
      }
    };
  }

  static void _hookDartAsyncErrors() {
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      // ── Structured log ──────────────────────────────────────────────────────
      debugPrint(
        '\n🔴 [Dart Async Error] ────────────────────────────────────────\n'
        '  Error : $error\n'
        '──────────────────────────────────────────────────────────────',
      );
      debugPrint('  Stack Trace:\n$stack');

      // ── Pipe to Crashlytics as a fatal error ──────────────────────────────
      if (_crashlyticsEnabled) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      }

      // Return true → tells Flutter we have handled this error.
      return true;
    };
  }
}
