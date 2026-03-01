class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.emailVerified,
    required this.createdAt,
    required this.updatedAt,
    this.lastLoginAt,
    this.photoUrl,
    this.onboardingCompleted = false,
    this.preferences = const <String, dynamic>{},
  });

  final String uid;
  final String email;
  final String displayName;
  final bool emailVerified;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLoginAt;
  final String? photoUrl;
  final bool onboardingCompleted;
  final Map<String, dynamic> preferences;

  factory AppUser.fromFirestore(Map<String, dynamic> data) {
    throw UnimplementedError(
      'fromFirestore will be added in the auth service implementation phase.',
    );
  }

  Map<String, dynamic> toFirestore() {
    throw UnimplementedError(
      'toFirestore will be added in the auth service implementation phase.',
    );
  }
}
