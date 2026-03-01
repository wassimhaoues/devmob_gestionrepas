import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/app_user.dart';
import 'user_profile_service.dart';

class FirestoreUserProfileService implements UserProfileService {
  FirestoreUserProfileService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  FirebaseFirestore get firestore => _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  @override
  Future<AppUser?> fetchUserById(String uid) async {
    final snapshot = await _users.doc(uid).get();
    if (!snapshot.exists) {
      return null;
    }

    final data = snapshot.data();
    if (data == null) {
      return null;
    }

    return AppUser.fromFirestore(
      <String, dynamic>{
        ...data,
        'uid': uid,
      },
    );
  }

  @override
  Future<void> createInitialProfile({
    required String uid,
    required String email,
    required String displayName,
  }) async {
    await _users.doc(uid).set(<String, dynamic>{
      'uid': uid,
      'email': email.trim().toLowerCase(),
      'displayName': displayName.trim(),
      'photoUrl': null,
      'emailVerified': false,
      'onboardingCompleted': false,
      'preferences': const <String, dynamic>{},
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> updateEmailVerificationStatus({
    required String uid,
    required bool emailVerified,
  }) async {
    await _users.doc(uid).set(<String, dynamic>{
      'emailVerified': emailVerified,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> updateLastLogin(String uid) async {
    await _users.doc(uid).set(<String, dynamic>{
      'lastLoginAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
