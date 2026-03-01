import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/app_user.dart';
import 'user_profile_service.dart';

class FirestoreUserProfileService implements UserProfileService {
  FirestoreUserProfileService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  FirebaseFirestore get firestore => _firestore;

  @override
  Future<AppUser?> fetchUserById(String uid) async {
    throw UnimplementedError(
      'User profile fetch is scheduled for the next auth commit.',
    );
  }

  @override
  Future<void> createInitialProfile({
    required String uid,
    required String email,
    required String displayName,
  }) async {
    throw UnimplementedError(
      'Initial profile creation is scheduled for the next auth commit.',
    );
  }

  @override
  Future<void> updateEmailVerificationStatus({
    required String uid,
    required bool emailVerified,
  }) async {
    throw UnimplementedError(
      'Verification status sync is scheduled for the next auth commit.',
    );
  }

  @override
  Future<void> updateLastLogin(String uid) async {
    throw UnimplementedError(
      'Last login update is scheduled for the next auth commit.',
    );
  }
}
