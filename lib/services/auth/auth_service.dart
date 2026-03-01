abstract interface class AuthService {
  Stream<String?> authStateChanges();

  String? get currentUserId;
  String? get currentUserEmail;
  String? get currentUserDisplayName;
  bool get isEmailVerified;

  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<String> createUserWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<void> sendEmailVerification();

  Future<void> sendPasswordResetEmail(String email);

  Future<void> reloadCurrentUser();

  Future<void> signOut();
}
