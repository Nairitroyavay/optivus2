import '../repositories/user_repository.dart';

class OnboardingController {
  final UserRepository _userRepo;

  OnboardingController(this._userRepo);

  Future<void> completeOnboarding(String userId, Map<String, dynamic> data) async {
    final user = await _userRepo.getUser(userId);
    if (user != null) {
      // update logic here
    }
  }
}
