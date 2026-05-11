import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:optivus2/core/providers/bootstrap_provider.dart';
import 'package:optivus2/services/event_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late MockFirebaseAuth mockAuth;
  late FakeFirebaseFirestore fakeFirestore;
  late EventService eventService;
  late AppBootstrapNotifier bootstrapNotifier;
  late bool orchestratorInitialized;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockAuth = MockFirebaseAuth();
    fakeFirestore = FakeFirebaseFirestore();
    eventService = EventService(firestore: fakeFirestore, auth: mockAuth);
    orchestratorInitialized = false;
  });

  tearDown(() {
    bootstrapNotifier.dispose();
  });

  group('AppBootstrapNotifier State Transitions', () {
    test('starts initializing and goes to unauthenticated when no user',
        () async {
      bootstrapNotifier = AppBootstrapNotifier(
        eventService: eventService,
        auth: mockAuth,
        firestore: fakeFirestore,
        ensureOrchestratorInitialized: () async {
          orchestratorInitialized = true;
        },
      );

      // Since mockAuth starts with no user, it should emit unauthenticated
      await Future.delayed(const Duration(milliseconds: 50));
      expect(bootstrapNotifier.state, BootstrapState.unauthenticated);
      expect(orchestratorInitialized, isFalse);
    });

    test('goes to needsOnboarding when user document does not exist', () async {
      await mockAuth.signInWithCustomToken('token');

      bootstrapNotifier = AppBootstrapNotifier(
        eventService: eventService,
        auth: mockAuth,
        firestore: fakeFirestore,
        ensureOrchestratorInitialized: () async {
          orchestratorInitialized = true;
        },
      );

      await Future.delayed(const Duration(milliseconds: 50));
      expect(bootstrapNotifier.state, BootstrapState.needsOnboarding);
      expect(orchestratorInitialized, isFalse);
    });

    test('goes to needsOnboarding when hasCompletedOnboarding is false',
        () async {
      await mockAuth.signInWithCustomToken('token');
      final uid = mockAuth.currentUser!.uid;

      await fakeFirestore.collection('users').doc(uid).set({
        'uid': uid,
        'hasCompletedOnboarding': false,
      });

      bootstrapNotifier = AppBootstrapNotifier(
        eventService: eventService,
        auth: mockAuth,
        firestore: fakeFirestore,
        ensureOrchestratorInitialized: () async {
          orchestratorInitialized = true;
        },
      );

      await Future.delayed(const Duration(milliseconds: 50));
      expect(bootstrapNotifier.state, BootstrapState.needsOnboarding);
      expect(orchestratorInitialized, isFalse);
    });

    test(
        'goes to ready and initializes orchestrator when onboarding is complete',
        () async {
      await mockAuth.signInWithCustomToken('token');
      final uid = mockAuth.currentUser!.uid;

      await fakeFirestore.collection('users').doc(uid).set({
        'uid': uid,
        'hasCompletedOnboarding': true,
      });

      bootstrapNotifier = AppBootstrapNotifier(
        eventService: eventService,
        auth: mockAuth,
        firestore: fakeFirestore,
        ensureOrchestratorInitialized: () async {
          orchestratorInitialized = true;
        },
      );

      await Future.delayed(const Duration(milliseconds: 50));
      expect(bootstrapNotifier.state, BootstrapState.ready);
      expect(orchestratorInitialized, isTrue);
    });

    test('reacts to onboarding completion in real-time', () async {
      await mockAuth.signInWithCustomToken('token');
      final uid = mockAuth.currentUser!.uid;

      // Start incomplete
      await fakeFirestore.collection('users').doc(uid).set({
        'uid': uid,
        'hasCompletedOnboarding': false,
      });

      bootstrapNotifier = AppBootstrapNotifier(
        eventService: eventService,
        auth: mockAuth,
        firestore: fakeFirestore,
        ensureOrchestratorInitialized: () async {
          orchestratorInitialized = true;
        },
      );

      await Future.delayed(const Duration(milliseconds: 50));
      expect(bootstrapNotifier.state, BootstrapState.needsOnboarding);
      expect(orchestratorInitialized, isFalse);

      // Simulate completing onboarding
      await fakeFirestore.collection('users').doc(uid).update({
        'hasCompletedOnboarding': true,
      });

      await Future.delayed(const Duration(milliseconds: 50));
      expect(bootstrapNotifier.state, BootstrapState.ready);
      expect(orchestratorInitialized, isTrue);
    });
  });
}
