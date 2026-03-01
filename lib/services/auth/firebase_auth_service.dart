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
  String? get currentUserEmail => _firebaseAuth.currentUser?.email;

  @override
  String? get currentUserDisplayName => _firebaseAuth.currentUser?.displayName;

  @override
  bool get isEmailVerified => _firebaseAuth.currentUser?.emailVerified ?? false;

  @override
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    await _firebaseAuth.signInWithEmailAndPassword(
      email: _normalizeEmail(email),
      password: password,
    );
  }

  @override
  Future<String> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final credentials = await _firebaseAuth.createUserWithEmailAndPassword(
      email: _normalizeEmail(email),
      password: password,
    );
    final user = credentials.user;
    if (user == null) {
      throw StateError('Firebase did not return a user after registration.');
    }
    return user.uid;
  }

  @override
  Future<void> sendEmailVerification() async {
    final user = _requireCurrentUser();
    if (user.emailVerified) {
      return;
    }
    await user.sendEmailVerification();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _firebaseAuth.sendPasswordResetEmail(
      email: _normalizeEmail(email),
    );
  }

  @override
  Future<void> reloadCurrentUser() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      return;
    }
    await user.reload();
  }

  @override
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  User _requireCurrentUser() {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw StateError('No authenticated Firebase user available.');
    }
    return user;
  }
}
