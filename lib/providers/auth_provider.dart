import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../models/auth_failure.dart';
import '../models/auth_status.dart';
import '../services/auth/auth_service.dart';
import '../services/auth/firebase_auth_error_mapper.dart';
import '../services/auth/user_profile_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    required AuthService authService,
    required UserProfileService userProfileService,
    FirebaseAuthErrorMapper? errorMapper,
  }) : _authService = authService,
       _userProfileService = userProfileService,
       _errorMapper = errorMapper ?? DefaultFirebaseAuthErrorMapper();

  final AuthService _authService;
  final UserProfileService _userProfileService;
  final FirebaseAuthErrorMapper _errorMapper;
  StreamSubscription<String?>? _authSubscription;
  bool _disposed = false;
  int _sessionResolutionVersion = 0;

  AuthStatus _status = AuthStatus.initial;
  AppUser? _currentUser;
  AuthFailure? _failure;
  bool _isLoading = false;

  AuthStatus get status => _status;
  AppUser? get currentUser => _currentUser;
  AuthFailure? get failure => _failure;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  Future<void> initialize() async {
    _setLoadingStatus(AuthStatus.checkingSession);
    await _authSubscription?.cancel();
    _authSubscription = _authService.authStateChanges().listen(
      (uid) => unawaited(_resolveSession(uid)),
      onError: (Object error, StackTrace _) {
        _applyFailure(
          _errorMapper.map(error),
          fallbackStatus: AuthStatus.error,
        );
      },
    );

    unawaited(_resolveSession(_authService.currentUserId));
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    _setLoadingStatus(AuthStatus.authenticating);
    try {
      await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _resolveSession(_authService.currentUserId);
    } catch (error) {
      _applyFailure(
        _errorMapper.map(error),
        fallbackStatus: AuthStatus.unauthenticated,
      );
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _setLoadingStatus(AuthStatus.authenticating);

    String? createdUid;
    try {
      createdUid = await _authService.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _userProfileService.createInitialProfile(
        uid: createdUid,
        email: email,
        displayName: displayName,
      );
      await _authService.sendEmailVerification();
      await _resolveSession(createdUid);
    } catch (error) {
      if (createdUid != null && _authService.currentUserId == createdUid) {
        try {
          await _authService.signOut();
        } catch (_) {}
      }
      _applyFailure(
        _errorMapper.map(error),
        fallbackStatus: AuthStatus.unauthenticated,
      );
    }
  }

  Future<void> sendPasswordReset(String email) async {
    final previousStatus = _status;
    _isLoading = true;
    _failure = null;
    _safeNotify();

    try {
      await _authService.sendPasswordResetEmail(email);
      _isLoading = false;
      _safeNotify();
    } catch (error) {
      _applyFailure(
        _errorMapper.map(error),
        fallbackStatus: previousStatus,
      );
    }
  }

  Future<void> resendVerificationEmail() async {
    final previousStatus = _status;
    _isLoading = true;
    _failure = null;
    _safeNotify();

    try {
      await _authService.reloadCurrentUser();

      final uid = _authService.currentUserId;
      if (uid == null) {
        _setUnauthenticated();
        return;
      }

      if (_authService.isEmailVerified) {
        await _userProfileService.updateEmailVerificationStatus(
          uid: uid,
          emailVerified: true,
        );
        await _resolveSession(uid);
        return;
      }

      await _authService.sendEmailVerification();
      _status = AuthStatus.emailVerificationRequired;
      _isLoading = false;
      _safeNotify();
    } catch (error) {
      _applyFailure(
        _errorMapper.map(error),
        fallbackStatus: previousStatus,
      );
    }
  }

  Future<void> signOut() async {
    final previousStatus = _status;
    _isLoading = true;
    _failure = null;
    _safeNotify();

    try {
      await _authService.signOut();
      _setUnauthenticated();
    } catch (error) {
      _applyFailure(
        _errorMapper.map(error),
        fallbackStatus: previousStatus,
      );
    }
  }

  Future<void> _resolveSession(String? uid) async {
    final requestVersion = ++_sessionResolutionVersion;

    if (uid == null) {
      _setUnauthenticated();
      return;
    }

    _status = AuthStatus.checkingSession;
    _isLoading = true;
    _failure = null;
    _safeNotify();

    try {
      AppUser? profile = await _userProfileService.fetchUserById(uid);

      if (profile == null) {
        final email = _authService.currentUserEmail;
        if (email != null && email.trim().isNotEmpty) {
          await _userProfileService.createInitialProfile(
            uid: uid,
            email: email,
            displayName: _resolveDisplayName(
              email: email,
              displayName: _authService.currentUserDisplayName,
            ),
          );
          profile = await _userProfileService.fetchUserById(uid);
        }
      }

      if (_isStale(requestVersion)) {
        return;
      }

      if (profile == null) {
        _applyFailure(
          const AuthFailure(
            code: AuthFailureCode.unknown,
            message: 'Unable to load user profile.',
          ),
          fallbackStatus: AuthStatus.error,
        );
        return;
      }

      if (profile.emailVerified != _authService.isEmailVerified) {
        await _userProfileService.updateEmailVerificationStatus(
          uid: uid,
          emailVerified: _authService.isEmailVerified,
        );
        profile = await _userProfileService.fetchUserById(uid) ?? profile;
      }

      await _userProfileService.updateLastLogin(uid);
      profile = await _userProfileService.fetchUserById(uid) ?? profile;

      if (_isStale(requestVersion)) {
        return;
      }

      _currentUser = profile;
      _failure = null;
      _isLoading = false;
      _status = _authService.isEmailVerified
          ? AuthStatus.authenticated
          : AuthStatus.emailVerificationRequired;
      _safeNotify();
    } catch (error) {
      if (_isStale(requestVersion)) {
        return;
      }
      _applyFailure(
        _errorMapper.map(error),
        fallbackStatus: AuthStatus.error,
      );
    }
  }

  String _resolveDisplayName({
    required String email,
    required String? displayName,
  }) {
    final normalizedDisplayName = displayName?.trim() ?? '';
    if (normalizedDisplayName.isNotEmpty) {
      return normalizedDisplayName;
    }
    final localPart = email.split('@').first.trim();
    return localPart.isEmpty ? 'User' : localPart;
  }

  bool _isStale(int requestVersion) =>
      _disposed || requestVersion != _sessionResolutionVersion;

  void _setLoadingStatus(AuthStatus status) {
    _status = status;
    _isLoading = true;
    _failure = null;
    _safeNotify();
  }

  void _applyFailure(AuthFailure failure, {required AuthStatus fallbackStatus}) {
    _failure = failure;
    _isLoading = false;
    _status = fallbackStatus;
    _safeNotify();
  }

  void _setUnauthenticated() {
    _currentUser = null;
    _failure = null;
    _isLoading = false;
    _status = AuthStatus.unauthenticated;
    _safeNotify();
  }

  void _safeNotify() {
    if (_disposed) {
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _authSubscription?.cancel();
    super.dispose();
  }
}
