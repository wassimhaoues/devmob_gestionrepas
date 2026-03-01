enum AuthFailureCode {
  invalidEmail,
  weakPassword,
  emailAlreadyInUse,
  userNotFound,
  wrongPassword,
  tooManyRequests,
  networkRequestFailed,
  operationNotAllowed,
  userDisabled,
  unknown,
}

class AuthFailure {
  const AuthFailure({
    required this.code,
    required this.message,
  });

  final AuthFailureCode code;
  final String message;
}
