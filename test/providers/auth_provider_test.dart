import 'dart:async';

import 'package:devmob_gestionrepas/models/app_user.dart';
import 'package:devmob_gestionrepas/models/auth_failure.dart';
import 'package:devmob_gestionrepas/models/auth_status.dart';
import 'package:devmob_gestionrepas/providers/auth_provider.dart';
import 'package:devmob_gestionrepas/services/auth/auth_service.dart';
import 'package:devmob_gestionrepas/services/auth/firebase_auth_error_mapper.dart';
import 'package:devmob_gestionrepas/services/auth/user_profile_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeAuthService authService;
  late _FakeUserProfileService userProfileService;

  setUp(() {
    authService = _FakeAuthService();
    userProfileService = _FakeUserProfileService();
  });

  tearDown(() async {
    await authService.dispose();
  });

  test(
    'initialize sets unauthenticated when there is no active user',
    () async {
      final provider = AuthProvider(
        authService: authService,
        userProfileService: userProfileService,
        errorMapper: const _TestErrorMapper(),
      );

      await provider.initialize();
      await _flushAsync();

      expect(provider.status, AuthStatus.unauthenticated);
      expect(provider.currentUser, isNull);
      provider.dispose();
    },
  );

  test(
    'signIn sets authenticated when profile exists and email is verified',
    () async {
      const uid = 'uid-signin';
      authService.signInUid = uid;
      authService.emailVerifiedValue = true;
      userProfileService.users[uid] = _user(
        uid: uid,
        email: 'signin@example.com',
        displayName: 'Sign In User',
        emailVerified: true,
      );

      final provider = AuthProvider(
        authService: authService,
        userProfileService: userProfileService,
        errorMapper: const _TestErrorMapper(),
      );

      await provider.signIn(
        email: 'signin@example.com',
        password: 'password123',
      );

      expect(provider.status, AuthStatus.authenticated);
      expect(provider.currentUser?.uid, uid);
      provider.dispose();
    },
  );

  test('register creates profile and requires email verification', () async {
    const uid = 'uid-register';
    authService.registerUid = uid;
    authService.emailVerifiedValue = false;

    final provider = AuthProvider(
      authService: authService,
      userProfileService: userProfileService,
      errorMapper: const _TestErrorMapper(),
    );

    await provider.register(
      email: 'new@example.com',
      password: 'password123',
      displayName: 'New User',
    );

    expect(provider.status, AuthStatus.emailVerificationRequired);
    expect(userProfileService.users.containsKey(uid), isTrue);
    provider.dispose();
  });

  test(
    'signIn maps errors to failure and keeps unauthenticated status',
    () async {
      authService.signInError = Exception('wrong credentials');
      const mappedFailure = AuthFailure(
        code: AuthFailureCode.wrongPassword,
        message: 'Incorrect email or password.',
      );

      final provider = AuthProvider(
        authService: authService,
        userProfileService: userProfileService,
        errorMapper: const _TestErrorMapper(failure: mappedFailure),
      );

      await provider.signIn(
        email: 'wrong@example.com',
        password: 'wrong-password',
      );

      expect(provider.status, AuthStatus.unauthenticated);
      expect(provider.failure?.code, AuthFailureCode.wrongPassword);
      expect(provider.failure?.message, mappedFailure.message);
      provider.dispose();
    },
  );

  test(
    'refreshVerificationStatus promotes user to authenticated when verified',
    () async {
      const uid = 'uid-verify';
      authService.currentUserIdValue = uid;
      authService.currentUserEmailValue = 'verify@example.com';
      authService.emailVerifiedValue = false;
      authService.reloadSetsEmailVerifiedTo = true;

      userProfileService.users[uid] = _user(
        uid: uid,
        email: 'verify@example.com',
        displayName: 'Verify User',
        emailVerified: false,
      );

      final provider = AuthProvider(
        authService: authService,
        userProfileService: userProfileService,
        errorMapper: const _TestErrorMapper(),
      );

      await provider.refreshVerificationStatus();

      expect(provider.status, AuthStatus.authenticated);
      expect(userProfileService.users[uid]?.emailVerified, isTrue);
      provider.dispose();
    },
  );
}

Future<void> _flushAsync() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _FakeAuthService implements AuthService {
  final StreamController<String?> _authStateController =
      StreamController<String?>.broadcast();

  String? currentUserIdValue;
  String? currentUserEmailValue;
  String? currentUserDisplayNameValue;
  bool emailVerifiedValue = false;

  String signInUid = 'signed-in-user';
  String registerUid = 'registered-user';
  bool? reloadSetsEmailVerifiedTo;

  Object? signInError;
  Object? createUserError;
  Object? sendVerificationError;
  Object? passwordResetError;
  Object? reloadError;
  Object? signOutError;

  @override
  Stream<String?> authStateChanges() => _authStateController.stream;

  @override
  String? get currentUserId => currentUserIdValue;

  @override
  String? get currentUserEmail => currentUserEmailValue;

  @override
  String? get currentUserDisplayName => currentUserDisplayNameValue;

  @override
  bool get isEmailVerified => emailVerifiedValue;

  @override
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (signInError != null) {
      throw signInError!;
    }

    currentUserIdValue = signInUid;
    currentUserEmailValue = email.trim().toLowerCase();
  }

  @override
  Future<String> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (createUserError != null) {
      throw createUserError!;
    }

    currentUserIdValue = registerUid;
    currentUserEmailValue = email.trim().toLowerCase();
    return registerUid;
  }

  @override
  Future<void> sendEmailVerification() async {
    if (sendVerificationError != null) {
      throw sendVerificationError!;
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    if (passwordResetError != null) {
      throw passwordResetError!;
    }
  }

  @override
  Future<void> reloadCurrentUser() async {
    if (reloadError != null) {
      throw reloadError!;
    }

    final updatedValue = reloadSetsEmailVerifiedTo;
    if (updatedValue != null) {
      emailVerifiedValue = updatedValue;
    }
  }

  @override
  Future<void> signOut() async {
    if (signOutError != null) {
      throw signOutError!;
    }

    currentUserIdValue = null;
    currentUserEmailValue = null;
    currentUserDisplayNameValue = null;
    emailVerifiedValue = false;
    _authStateController.add(null);
  }

  Future<void> dispose() async {
    await _authStateController.close();
  }
}

class _FakeUserProfileService implements UserProfileService {
  final Map<String, AppUser> users = <String, AppUser>{};

  Object? fetchUserError;
  Object? createProfileError;
  Object? updateVerificationError;
  Object? updateLastLoginError;

  @override
  Future<AppUser?> fetchUserById(String uid) async {
    if (fetchUserError != null) {
      throw fetchUserError!;
    }

    return users[uid];
  }

  @override
  Future<void> createInitialProfile({
    required String uid,
    required String email,
    required String displayName,
  }) async {
    if (createProfileError != null) {
      throw createProfileError!;
    }

    final now = DateTime.now();
    users[uid] = AppUser(
      uid: uid,
      email: email.trim().toLowerCase(),
      displayName: displayName.trim(),
      emailVerified: false,
      createdAt: now,
      updatedAt: now,
      lastLoginAt: now,
      onboardingCompleted: false,
      preferences: const <String, dynamic>{},
      photoUrl: null,
    );
  }

  @override
  Future<void> updateEmailVerificationStatus({
    required String uid,
    required bool emailVerified,
  }) async {
    if (updateVerificationError != null) {
      throw updateVerificationError!;
    }

    final user = users[uid];
    if (user == null) {
      return;
    }

    users[uid] = _copyUser(
      user,
      emailVerified: emailVerified,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> updateLastLogin(String uid) async {
    if (updateLastLoginError != null) {
      throw updateLastLoginError!;
    }

    final user = users[uid];
    if (user == null) {
      return;
    }

    users[uid] = _copyUser(
      user,
      lastLoginAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

class _TestErrorMapper implements FirebaseAuthErrorMapper {
  const _TestErrorMapper({
    this.failure = const AuthFailure(
      code: AuthFailureCode.unknown,
      message: 'Unexpected error.',
    ),
  });

  final AuthFailure failure;

  @override
  AuthFailure map(Object exception) => failure;
}

AppUser _user({
  required String uid,
  required String email,
  required String displayName,
  required bool emailVerified,
}) {
  final now = DateTime.now();
  return AppUser(
    uid: uid,
    email: email,
    displayName: displayName,
    emailVerified: emailVerified,
    createdAt: now,
    updatedAt: now,
    lastLoginAt: now,
    onboardingCompleted: false,
    preferences: const <String, dynamic>{},
    photoUrl: null,
  );
}

AppUser _copyUser(
  AppUser original, {
  bool? emailVerified,
  DateTime? updatedAt,
  DateTime? lastLoginAt,
}) {
  return AppUser(
    uid: original.uid,
    email: original.email,
    displayName: original.displayName,
    emailVerified: emailVerified ?? original.emailVerified,
    createdAt: original.createdAt,
    updatedAt: updatedAt ?? original.updatedAt,
    lastLoginAt: lastLoginAt ?? original.lastLoginAt,
    onboardingCompleted: original.onboardingCompleted,
    preferences: original.preferences,
    photoUrl: original.photoUrl,
  );
}
