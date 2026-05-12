import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'config/firebase_options.dart';
import 'core/router/app_router.dart';
import 'core/providers.dart';
import 'services/global_error_handler.dart';
import 'services/remote_config_service.dart';

void main() async {
  // Ensure WidgetsFlutterBinding.ensureInitialized() runs first.
  WidgetsFlutterBinding.ensureInitialized();

  const mapboxAccessToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');

  if (mapboxAccessToken.isNotEmpty) {
    mapbox.MapboxOptions.setAccessToken(mapboxAccessToken);
    debugPrint('[Mapbox] access token configured');
  } else {
    debugPrint('[Mapbox] MAPBOX_ACCESS_TOKEN missing; Mapbox map will not load');
  }

  // ① Hook error handlers early so no error slips
  // through during the Firebase / plugin bootstrap sequence.
  GlobalErrorHandler.initialize();

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  RemoteConfigService? remoteConfigService;
  var appRemoteConfig = AppRemoteConfig.defaults();
  bool initFailed = false;

  try {
    // ② Initialize Firebase before any Firebase service is created.
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Now it's safe to create RemoteConfigService
    remoteConfigService = RemoteConfigService();

    await FirebaseAppCheck.instance.activate(
      providerAndroid: kReleaseMode
          ? const AndroidPlayIntegrityProvider()
          : const AndroidDebugProvider(),
    );
    debugPrint(
        '[AppCheck] activated provider=${kReleaseMode ? "play_integrity" : "debug"}');

    FirebaseFirestore.instance.settings =
        const Settings(persistenceEnabled: true);
    appRemoteConfig = await remoteConfigService.initialize();

    // ③ Firebase is healthy — enable the Crashlytics pipe.
    GlobalErrorHandler.setCrashlyticsEnabled();
  } catch (e) {
    debugPrint('🔴 [main] Firebase init failed: $e');
    initFailed = true;
  }

  if (initFailed) {
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Startup Error: Failed to initialize Firebase.\nPlease check your connection and restart the app.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }

  runApp(
    ProviderScope(
      overrides: [
        remoteConfigServiceProvider.overrideWithValue(remoteConfigService!),
        appRemoteConfigProvider.overrideWithValue(appRemoteConfig),
      ],
      child: const OptivusApp(),
    ),
  );
}

class OptivusApp extends ConsumerStatefulWidget {
  const OptivusApp({super.key});

  @override
  ConsumerState<OptivusApp> createState() => _OptivusAppState();
}

class _OptivusAppState extends ConsumerState<OptivusApp> {
  @override
  void initState() {
    super.initState();
    ref.read(eventOrchestratorProvider);
    final notificationService = ref.read(notificationServiceProvider);
    final routineService = ref.read(routineServiceProvider);
    Future.microtask(() async {
      await notificationService.reRegisterAllOnAppStart();
      await routineService.runDayCloseIfNeeded();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.read(appRemoteConfigProvider);

    return MaterialApp.router(
      title: 'Optivus',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFFB830)),
      ),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
