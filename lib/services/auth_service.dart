import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants/event_names.dart';
import '../models/user_model.dart';
import 'event_service.dart';

class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final EventService _eventService;

  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    EventService? eventService,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _eventService = eventService ?? EventService();

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signIn(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;
    if (user != null) {
      await _ensureUserDocument(user);
    }

    return credential;
  }

  Future<UserCredential> signUp(
    String email,
    String password, {
    String? name,
    String? timezone,
  }) async {
    final normalizedEmail = email.trim();
    final credential = await _auth.createUserWithEmailAndPassword(
      email: normalizedEmail,
      password: password,
    );
    final user = credential.user;
    if (user != null) {
      final now = DateTime.now();
      final normalizedName = name?.trim();
      final resolvedName =
          normalizedName?.isEmpty == true ? null : normalizedName;

      // Update Firebase Auth display name.
      if (resolvedName != null) {
        await user.updateDisplayName(resolvedName);
      }

      final userModel = UserModel(
        id: user.uid,
        email: normalizedEmail,
        displayName: resolvedName,
        timezone: timezone ?? now.timeZoneName,
        createdAt: now,
        updatedAt: now,
        hasCompletedOnboarding: false,
        onboardingStep: 0,
        schemaVersion: 1,
        lastDayClosed: null,
        coachName: null,
        coachStyle: null,
        accountabilityMode: null,
        notificationSettings: const NotificationSettings(),
      );

      final batch = _firestore.batch();
      batch.set(
        _firestore.collection('users').doc(user.uid),
        userModel.toFirestore(),
      );

      // Stable per-account event ID guarantees one signup event document even
      // if this method is retried after account creation.
      await _eventService.emit(
        eventName: EventNames.userSignedUp,
        eventId: 'user_signed_up_${user.uid}',
        payload: {
          'uid': user.uid,
          'email': userModel.email,
          'displayName': userModel.displayName,
          'hasCompletedOnboarding': userModel.hasCompletedOnboarding,
          'onboardingStep': userModel.onboardingStep,
          'schemaVersion': userModel.schemaVersion,
        },
        batch: batch,
      );

      await batch.commit();
    }
    return credential;
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> _ensureUserDocument(User user) async {
    final ref = _firestore.collection('users').doc(user.uid);
    final snap = await ref.get();
    final data = snap.data();
    final now = DateTime.now();
    final existingCreatedAt = data?['createdAt'];
    final currentNotificationSettings = data?['notificationSettings'];

    final defaults = <String, dynamic>{
      'uid': user.uid,
      'email': data?['email'] ?? user.email ?? '',
      'displayName': data?['displayName'] ?? user.displayName,
      'createdAt': existingCreatedAt ?? Timestamp.fromDate(now),
      'updatedAt': FieldValue.serverTimestamp(),
      'schemaVersion': data?['schemaVersion'] ?? 1,
      'timezone': data?['timezone'] ?? now.timeZoneName,
      'hasCompletedOnboarding': data?['hasCompletedOnboarding'] ?? false,
      'onboardingStep': data?['onboardingStep'] ?? 0,
      'lastDayClosed': data?['lastDayClosed'],
      'coachName': data?['coachName'],
      'coachStyle': data?['coachStyle'],
      'accountabilityMode': data?['accountabilityMode'],
      'notificationSettings': currentNotificationSettings is Map
          ? Map<String, dynamic>.from(currentNotificationSettings)
          : const NotificationSettings().toMap(),
    };

    await ref.set(defaults, SetOptions(merge: true));
  }
}
