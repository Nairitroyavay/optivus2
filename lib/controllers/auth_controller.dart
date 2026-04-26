import '../repositories/auth_repository.dart';

class AuthController {
  final AuthRepository _repo;

  AuthController(this._repo);

  Future<void> login(String email, String password) async {
    await _repo.signIn(email, password);
  }

  Future<void> register(String email, String password) async {
    await _repo.signUp(email, password);
  }

  Future<void> logout() async {
    await _repo.signOut();
  }
}
