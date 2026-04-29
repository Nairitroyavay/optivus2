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
    return await _auth.signInWithEmailAndPassword(
        email: email, password: password);
  }

  Future<UserCredential> signUp(
    String email,
    String password, {
    String? name,
    String? timezone,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    final user = credential.user;
    if (user != null) {
      final now = DateTime.now();
      final normalizedName = name?.trim();
      final userModel = UserModel(
        id: user.uid,
        email: email,
        name: normalizedName?.isEmpty == true ? null : normalizedName,
        timezone: timezone ?? now.timeZoneName,
        createdAt: now,
        updatedAt: now,
        hasCompletedOnboarding: false,
        onboardingStep: 0,
        schemaVersion: 1,
        lastDayClosed: null,
      );
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(userModel.toFirestore());

      await _eventService.emit(
        eventName: EventNames.userSignedUp,
        payload: {
          'id': user.uid,
          'email': userModel.email,
          'hasCompletedOnboarding': userModel.hasCompletedOnboarding,
          'onboardingStep': userModel.onboardingStep,
          'schemaVersion': userModel.schemaVersion,
        },
      );
    }
    return credential;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
