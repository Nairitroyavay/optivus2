import '../services/firestore_service.dart';
import '../models/user_model.dart';

class UserRepository {
  final FirestoreService _service;

  UserRepository(this._service);

  Future<void> saveUser(UserModel user) async {
    await _service.saveUserProfile(user.toMap());
  }

  Future<UserModel?> getUser(String uid) async {
    final data = await _service.getUserProfile();
    if (data != null) {
      return UserModel.fromMap(data);
    }
    return null;
  }
}
