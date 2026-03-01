import 'package:firebase_auth/firebase_auth.dart';

import '../../models/auth_failure.dart';

abstract interface class FirebaseAuthErrorMapper {
  AuthFailure map(Object exception);
}

class DefaultFirebaseAuthErrorMapper implements FirebaseAuthErrorMapper {
  @override
  AuthFailure map(Object exception) {
    if (exception is FirebaseAuthException) {
      return _fromAuthException(exception);
    }

    if (exception is FirebaseException) {
      return _fromFirebaseException(exception);
    }

    return const AuthFailure(
      code: AuthFailureCode.unknown,
      message: 'Unexpected error. Please try again.',
    );
  }

  AuthFailure _fromAuthException(FirebaseAuthException exception) {
    switch (exception.code) {
      case 'invalid-email':
        return const AuthFailure(
          code: AuthFailureCode.invalidEmail,
          message: 'Enter a valid email address.',
        );
      case 'weak-password':
        return const AuthFailure(
          code: AuthFailureCode.weakPassword,
          message: 'Password is too weak.',
        );
      case 'email-already-in-use':
        return const AuthFailure(
          code: AuthFailureCode.emailAlreadyInUse,
          message: 'This email is already in use.',
        );
      case 'user-not-found':
        return const AuthFailure(
          code: AuthFailureCode.userNotFound,
          message: 'No account found for this email.',
        );
      case 'wrong-password':
      case 'invalid-credential':
        return const AuthFailure(
          code: AuthFailureCode.wrongPassword,
          message: 'Incorrect email or password.',
        );
      case 'too-many-requests':
        return const AuthFailure(
          code: AuthFailureCode.tooManyRequests,
          message: 'Too many attempts. Try again later.',
        );
      case 'network-request-failed':
        return const AuthFailure(
          code: AuthFailureCode.networkRequestFailed,
          message: 'Network error. Check your connection.',
        );
      case 'operation-not-allowed':
        return const AuthFailure(
          code: AuthFailureCode.operationNotAllowed,
          message: 'This operation is not enabled.',
        );
      case 'user-disabled':
        return const AuthFailure(
          code: AuthFailureCode.userDisabled,
          message: 'This account has been disabled.',
        );
      default:
        return AuthFailure(
          code: AuthFailureCode.unknown,
          message: exception.message ?? 'Authentication failed.',
        );
    }
  }

  AuthFailure _fromFirebaseException(FirebaseException exception) {
    switch (exception.code) {
      case 'unavailable':
      case 'network-request-failed':
        return const AuthFailure(
          code: AuthFailureCode.networkRequestFailed,
          message: 'Network error. Check your connection.',
        );
      case 'permission-denied':
        return const AuthFailure(
          code: AuthFailureCode.operationNotAllowed,
          message: 'You do not have permission for this action.',
        );
      default:
        return AuthFailure(
          code: AuthFailureCode.unknown,
          message: exception.message ?? 'Unexpected backend error.',
        );
    }
  }
}
