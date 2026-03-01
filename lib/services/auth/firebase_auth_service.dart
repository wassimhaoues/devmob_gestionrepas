import 'package:firebase_auth/firebase_auth.dart';

import 'auth_service.dart';

class FirebaseAuthService implements AuthService {
  FirebaseAuthService({FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;

  @override
  Stream<String?> authStateChanges() {
    return _firebaseAuth.authStateChanges().map((user) => user?.uid);
  }

  @override
  String? get currentUserId => _firebaseAuth.currentUser?.uid;

  @override
  bool get isEmailVerified => _firebaseAuth.currentUser?.emailVerified ?? false;

  @override
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    throw UnimplementedError(
      'Sign-in implementation is scheduled for the next auth commit.',
    );
  }

  @override
  Future<String> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    throw UnimplementedError(
      'Registration implementation is scheduled for the next auth commit.',
    );
  }

  @override
  Future<void> sendEmailVerification() async {
    throw UnimplementedError(
      'Email verification implementation is scheduled for the next auth commit.',
    );
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    throw UnimplementedError(
      'Password reset implementation is scheduled for the next auth commit.',
    );
  }

  @override
  Future<void> reloadCurrentUser() async {
    throw UnimplementedError(
      'User reload implementation is scheduled for the next auth commit.',
    );
  }

  @override
  Future<void> signOut() async {
    throw UnimplementedError(
      'Sign-out implementation is scheduled for the next auth commit.',
    );
  }
}
