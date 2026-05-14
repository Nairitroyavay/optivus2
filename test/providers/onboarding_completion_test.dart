import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:optivus2/services/firestore_service.dart';
import 'package:optivus2/services/event_service.dart';
import 'package:optivus2/repositories/user_repository.dart';
import 'package:optivus2/providers/onboarding_provider.dart';
import 'package:optivus2/core/constants/event_names.dart';
import 'package:optivus2/core/constants/onboarding_constants.dart';
import 'package:optivus2/models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late MockFirebaseAuth mockAuth;
  late FakeFirebaseFirestore fakeFirestore;
  late FirestoreService firestoreService;
  late EventService eventService;
  late UserRepository userRepository;
  late OnboardingNotifier onboardingNotifier;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    mockAuth = MockFirebaseAuth(signedIn: true);
    fakeFirestore = FakeFirebaseFirestore();

    // Create a mock user
    await mockAuth.createUserWithEmailAndPassword(
        email: 'test@example.com', password: 'password');
    final uid = mockAuth.currentUser!.uid;

    firestoreService = FirestoreService(db: fakeFirestore, auth: mockAuth);
    eventService = EventService(firestore: fakeFirestore, auth: mockAuth);
    userRepository = UserRepository(firestoreService);

    // Seed initial user document so updates don't fail if they expect it
    await fakeFirestore.collection('users').doc(uid).set({
      'uid': uid,
      'email': 'test@example.com',
      'hasCompletedOnboarding': false,
    });

    onboardingNotifier = OnboardingNotifier(
      userRepository,
      eventService,
      firestore: fakeFirestore,
      auth: mockAuth,
    );
  });

  group('Onboarding Completion Hardening', () {
    test(
        'completeOnboarding writes all required documents atomically and idempotently',
        () async {
      final uid = mockAuth.currentUser!.uid;

      // Setup state with standard onboarding flow selections
      onboardingNotifier.updateCategories(['Fitness', 'Productivity']);
      onboardingNotifier.updateGoodHabits(['Drink Water']);
      onboardingNotifier.updateBadHabits(['Scroll Social Media']);
      onboardingNotifier.updateGoals(['Get fit']);
      onboardingNotifier.updateCoachStyle('Supportive');
      onboardingNotifier.updateCoachName('AI Coach');
      onboardingNotifier.updateAccountability('Strict');
      onboardingNotifier.updateAboutYou(const AboutYouProfile(
        bodyBasics: BodyBasics(ageRange: '20-30', wakeTime: '07:00', sleepTime: '23:00'),
        sensitiveContext: SensitiveContext(medicalDisclaimerAcknowledged: true),
      ));
      onboardingNotifier.updateFixedSchedule([
        {
          'templateId': 'block_1',
          'title': 'Morning Block',
          'startTime': '09:00',
          'endTime': '10:00',
        }
      ]);

      // Perform completion
      final success = await onboardingNotifier.completeOnboarding();
      expect(success, isTrue);

      // Verify root user doc
      final rootDoc = await fakeFirestore.collection('users').doc(uid).get();
      expect(rootDoc.data()!['hasCompletedOnboarding'], isTrue);
      expect(rootDoc.data()!['onboardingStep'], kOnboardingFinalPage);

      // Verify onboarding state doc
      final stateDoc = await fakeFirestore
          .collection('users')
          .doc(uid)
          .collection('onboarding')
          .doc('state')
          .get();
      expect(stateDoc.exists, isTrue);
      expect(stateDoc.data()!['status'], 'completed');

      // Verify profile doc
      final profileDoc = await fakeFirestore
          .collection('users')
          .doc(uid)
          .collection('profile')
          .doc('main')
          .get();
      expect(profileDoc.exists, isTrue);
      expect(profileDoc.data()!['hasCompletedOnboarding'], isTrue);

      // Verify identity profile stub
      final identityDoc = await fakeFirestore
          .collection('users')
          .doc(uid)
          .collection('identity_profile')
          .doc('main')
          .get();
      expect(identityDoc.exists, isTrue);
      expect(identityDoc.data()!['status'], 'stub');

      // Verify tasks materialized
      final tasksSnap = await fakeFirestore
          .collection('users')
          .doc(uid)
          .collection('tasks')
          .get();
      expect(tasksSnap.docs.isNotEmpty, isTrue);

      // Verify events emitted correctly
      final eventsSnap = await fakeFirestore
          .collection('users')
          .doc(uid)
          .collection('events')
          .get();
      final eventNames =
          eventsSnap.docs.map((d) => d.data()['eventName']).toSet();
      expect(eventNames.contains(EventNames.onboardingCompleted), isTrue);
      expect(eventNames.contains(EventNames.identityCreated), isTrue);
      expect(eventNames.contains(EventNames.taskScheduled), isTrue);

      final onboardingEvent = await fakeFirestore
          .collection('users')
          .doc(uid)
          .collection('events')
          .doc('onboarding_completed_$uid')
          .get();
      expect(onboardingEvent.exists, isTrue);

      final identityEvent = await fakeFirestore
          .collection('users')
          .doc(uid)
          .collection('events')
          .doc('identity_created_$uid')
          .get();
      expect(identityEvent.exists, isTrue);
      expect(identityEvent.data()!['payload']['identityId'], 'main');
      expect(eventsSnap.docs.any((d) => d.id.contains('_null')), isFalse);

      // Check idempotency by calling completeOnboarding again
      final successAgain = await onboardingNotifier.completeOnboarding();
      expect(successAgain, isTrue);

      // Verify no duplicate tasks were created
      final tasksSnapAfter = await fakeFirestore
          .collection('users')
          .doc(uid)
          .collection('tasks')
          .get();
      expect(tasksSnapAfter.docs.length, tasksSnap.docs.length);

      // Verify singleton event is not duplicated (eventId should be stable)
      final eventsSnapAfter = await fakeFirestore
          .collection('users')
          .doc(uid)
          .collection('events')
          .get();
      final onboardingEvents = eventsSnapAfter.docs.where(
          (d) => d.data()['eventName'] == EventNames.onboardingCompleted);
      expect(onboardingEvents.length, 1);
      expect(eventsSnapAfter.docs.length, eventsSnap.docs.length);
    });

    test('completeOnboarding fails and creates no tasks when required fields are missing', () async {
      final uid = mockAuth.currentUser!.uid;

      // Update with invalid state (empty)
      onboardingNotifier.updateCategories([]);
      onboardingNotifier.updateGoodHabits([]);
      onboardingNotifier.updateBadHabits([]);
      onboardingNotifier.updateGoals([]);
      onboardingNotifier.updateFixedSchedule([]);

      final success = await onboardingNotifier.completeOnboarding();
      expect(success, isFalse);

      final tasksSnap = await fakeFirestore
          .collection('users')
          .doc(uid)
          .collection('tasks')
          .get();
      expect(tasksSnap.docs.isEmpty, isTrue);
    });

    test(
        'completeOnboarding caps materialized writes below Firestore batch limit',
        () async {
      final uid = mockAuth.currentUser!.uid;

      onboardingNotifier.updateGoodHabits(
        List.generate(80, (i) => 'Good habit $i'),
      );
      onboardingNotifier.updateBadHabits(
        List.generate(80, (i) => 'Bad habit $i'),
      );
      onboardingNotifier.updateGoals(
        List.generate(80, (i) => 'Goal $i'),
      );
      onboardingNotifier.updateFixedSchedule(
        List.generate(
          140,
          (i) => {
            'templateId': 'block_$i',
            'title': 'Block $i',
            'startTime': '09:00',
            'endTime': '10:00',
          },
        ),
      );
      onboardingNotifier.updateCategories(['Fitness']);
      onboardingNotifier.updateCoachStyle('Supportive');
      onboardingNotifier.updateCoachName('AI Coach');
      onboardingNotifier.updateAccountability('Strict');
      onboardingNotifier.updateAboutYou(const AboutYouProfile(
        bodyBasics: BodyBasics(ageRange: '20-30', wakeTime: '07:00', sleepTime: '23:00'),
        sensitiveContext: SensitiveContext(medicalDisclaimerAcknowledged: true),
      ));

      final success = await onboardingNotifier.completeOnboarding();
      expect(success, isTrue);

      final habitsSnap = await fakeFirestore
          .collection('users')
          .doc(uid)
          .collection('habits')
          .get();
      final goalsSnap = await fakeFirestore
          .collection('users')
          .doc(uid)
          .collection('goals')
          .get();
      final tasksSnap = await fakeFirestore
          .collection('users')
          .doc(uid)
          .collection('tasks')
          .get();
      final notificationsSnap = await fakeFirestore
          .collection('users')
          .doc(uid)
          .collection('scheduled_notifications')
          .get();
      final eventsSnap = await fakeFirestore
          .collection('users')
          .doc(uid)
          .collection('events')
          .get();

      expect(habitsSnap.docs.length, 48);
      expect(goalsSnap.docs.length, 24);
      expect(tasksSnap.docs.length, 100);
      expect(notificationsSnap.docs.length, 3);
      expect(eventsSnap.docs.length, lessThan(500));
    });

    test(
        'completeOnboarding merges onboarding fixed schedule without clobbering existing routine templates',
        () async {
      final uid = mockAuth.currentUser!.uid;
      final existingTemplateCreatedAt = '2025-01-01T00:00:00.000Z';

      await fakeFirestore
          .collection('users')
          .doc(uid)
          .collection('routine')
          .doc('current')
          .set({
        'templates': {
          'fixed_schedule': [
            {
              'templateId': 'existing_block',
              'title': 'Existing Block',
              'startTime': '06:00',
              'endTime': '07:00',
              'repeatRule': 'daily',
              'category': 'Legacy',
              'createdAt': existingTemplateCreatedAt,
              'updatedAt': existingTemplateCreatedAt,
              'legacyField': 'preserve',
            },
          ],
        },
        'fixedScheduleSetUp': true,
      });

      onboardingNotifier.updateFixedSchedule([
        {
          'templateId': 'existing_block',
          'title': 'Incoming Duplicate',
          'startTime': '08:00',
          'endTime': '09:00',
        },
        {
          'templateId': 'new_onboarding_block',
          'title': 'New Onboarding Block',
          'startTime': '09:30',
          'endTime': '10:00',
        },
      ]);

      onboardingNotifier.updateCategories(['Fitness']);
      onboardingNotifier.updateGoodHabits(['Good Habit']);
      onboardingNotifier.updateBadHabits(['Bad Habit']);
      onboardingNotifier.updateGoals(['Goal 1']);
      onboardingNotifier.updateCoachStyle('Supportive');
      onboardingNotifier.updateCoachName('AI Coach');
      onboardingNotifier.updateAccountability('Strict');
      onboardingNotifier.updateAboutYou(const AboutYouProfile(
        bodyBasics: BodyBasics(ageRange: '20-30', wakeTime: '07:00', sleepTime: '23:00'),
        sensitiveContext: SensitiveContext(medicalDisclaimerAcknowledged: true),
      ));

      final success = await onboardingNotifier.completeOnboarding();
      expect(success, isTrue);

      final routineDoc = await fakeFirestore
          .collection('users')
          .doc(uid)
          .collection('routine')
          .doc('current')
          .get();

      final templates = List<Map<String, dynamic>>.from(
        (routineDoc.data()?['templates']?['fixed_schedule'] as List? ??
                const [])
            .map((item) => Map<String, dynamic>.from(item as Map)),
      );
      expect(templates.length, 2);

      final existing = templates
          .firstWhere((item) => item['templateId'] == 'existing_block');
      expect(existing['title'], 'Existing Block');
      expect(existing['legacyField'], 'preserve');
      expect(existing['createdAt'], existingTemplateCreatedAt);

      final added = templates
          .firstWhere((item) => item['templateId'] == 'new_onboarding_block');
      expect(added['title'], 'New Onboarding Block');
    });
  });
}
