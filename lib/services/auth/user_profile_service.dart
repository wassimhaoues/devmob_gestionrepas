import '../../models/app_user.dart';

abstract interface class UserProfileService {
  Future<AppUser?> fetchUserById(String uid);

  Future<void> createInitialProfile({
    required String uid,
    required String email,
    required String displayName,
  });

  Future<void> updateEmailVerificationStatus({
    required String uid,
    required bool emailVerified,
  });

  Future<void> updateLastLogin(String uid);
}
