import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../models/auth_failure.dart';
import '../models/auth_status.dart';
import '../services/auth/auth_service.dart';
import '../services/auth/user_profile_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    required AuthService authService,
    required UserProfileService userProfileService,
  }) : _authService = authService,
       _userProfileService = userProfileService;

  final AuthService _authService;
  final UserProfileService _userProfileService;
  StreamSubscription<String?>? _authSubscription;

  AuthStatus _status = AuthStatus.initial;
  AppUser? _currentUser;
  AuthFailure? _failure;
  bool _isLoading = false;

  AuthStatus get status => _status;
  AppUser? get currentUser => _currentUser;
  AuthFailure? get failure => _failure;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  AuthService get authService => _authService;
  UserProfileService get userProfileService => _userProfileService;

  Future<void> initialize() async {
    throw UnimplementedError(
      'Session bootstrap will be implemented in the auth provider phase.',
    );
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    throw UnimplementedError('Sign-in flow will be implemented next.');
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    throw UnimplementedError('Registration flow will be implemented next.');
  }

  Future<void> sendPasswordReset(String email) async {
    throw UnimplementedError('Password reset flow will be implemented next.');
  }

  Future<void> resendVerificationEmail() async {
    throw UnimplementedError(
      'Verification email flow will be implemented next.',
    );
  }

  Future<void> signOut() async {
    throw UnimplementedError('Sign-out flow will be implemented next.');
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
