import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> signUp(String email, String password) async {
    final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    final user = credential.user;
    if (user != null) {
      final userModel = UserModel(
        id: user.uid,
        email: email,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        hasCompletedOnboarding: false,
        schemaVersion: 1,
      );
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(userModel.toFirestore());
    }
    return credential;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
