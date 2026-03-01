import '../../models/auth_failure.dart';

abstract interface class FirebaseAuthErrorMapper {
  AuthFailure map(Object exception);
}
