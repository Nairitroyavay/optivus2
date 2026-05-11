import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:optivus2/services/auth_service.dart';
import 'package:optivus2/services/event_service.dart';
import 'package:optivus2/core/constants/event_names.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late MockFirebaseAuth mockAuth;
  late FakeFirebaseFirestore fakeFirestore;
  late EventService eventService;
  late AuthService authService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockAuth = MockFirebaseAuth();
    fakeFirestore = FakeFirebaseFirestore();
    eventService = EventService(firestore: fakeFirestore, auth: mockAuth);
    authService = AuthService(
      auth: mockAuth,
      firestore: fakeFirestore,
      eventService: eventService,
    );
  });

  group('AuthService - First Run & Bootstrap Hardening', () {
    test(
        'signUp creates user document and emits user_signed_up event atomically',
        () async {
      final credential = await authService
          .signUp('test@example.com', 'password', name: 'Test User');
      final uid = credential.user!.uid;

      // Verify user document exists and has correct first-run state
      final userDoc = await fakeFirestore.collection('users').doc(uid).get();
      expect(userDoc.exists, isTrue);
      final data = userDoc.data()!;
      expect(data['email'], 'test@example.com');
      expect(data['displayName'], 'Test User');
      expect(data['hasCompletedOnboarding'], isFalse);
      expect(data['onboardingStep'], 0);
      expect(data['schemaVersion'], 1);
      expect(data['createdAt'], isNotNull);
      expect(data['notificationSettings'], isA<Map>());

      // Verify event was emitted and batched
      final eventDoc = await fakeFirestore
          .collection('users')
          .doc(uid)
          .collection('events')
          .doc('user_signed_up_$uid')
          .get();

      expect(eventDoc.exists, isTrue);
      final eventData = eventDoc.data()!;
      expect(eventData['eventName'], EventNames.userSignedUp);
      expect(eventData['payload']['uid'], uid);
      expect(eventData['payload']['email'], 'test@example.com');
      expect(eventData['payload']['hasCompletedOnboarding'], false);
    });

    test(
        'signIn merges defaults without overriding existing completed onboarding state',
        () async {
      // 1. Manually create a user in MockAuth
      final authResult = await mockAuth.createUserWithEmailAndPassword(
          email: 'existing@example.com', password: 'password');
      final uid = authResult.user!.uid;

      // 2. Pre-populate a user document mimicking an existing user who finished onboarding
      await fakeFirestore.collection('users').doc(uid).set({
        'uid': uid,
        'email': 'existing@example.com',
        'hasCompletedOnboarding': true,
        'onboardingStep': 10,
        'customField': 'should_be_preserved',
      });

      // 3. Sign out so we can sign in properly through the service
      await mockAuth.signOut();

      // 4. Perform sign in, which calls _ensureUserDocument
      await authService.signIn('existing@example.com', 'password');

      // 5. Verify the merge
      final userDoc = await fakeFirestore.collection('users').doc(uid).get();
      expect(userDoc.exists, isTrue);
      final data = userDoc.data()!;

      // Existing data preserved
      expect(data['hasCompletedOnboarding'], isTrue);
      expect(data['onboardingStep'], 10);
      expect(data['customField'], 'should_be_preserved');

      // Missing defaults added
      expect(data['schemaVersion'], 1);
      expect(data['notificationSettings'], isNotNull);
    });
  });
}
