import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class AuthRepository {
  final AuthService _authService;

  AuthRepository(this._authService);

  Stream<User?> get authStateChanges => _authService.authStateChanges;

  Future<UserCredential> signIn(String email, String password) {
    return _authService.signIn(email, password);
  }

  /// Signs up a new user. Forwards optional [name] and [timezone] so that
  /// the full schema document is written to Firestore on first registration.
  Future<UserCredential> signUp(
    String email,
    String password, {
    String? name,
    String? timezone,
  }) {
    return _authService.signUp(email, password, name: name, timezone: timezone);
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _authService.sendPasswordResetEmail(email);
  }

  Future<void> signOut() {
    return _authService.signOut();
  }
}
