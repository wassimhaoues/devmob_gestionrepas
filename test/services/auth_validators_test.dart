import 'package:devmob_gestionrepas/services/auth/auth_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthValidators.validateEmail', () {
    test('returns error when email is empty', () {
      expect(AuthValidators.validateEmail('   '), 'Email is required.');
    });

    test('returns error for invalid email format', () {
      expect(AuthValidators.validateEmail('invalid-email'), isNotNull);
    });

    test('accepts a valid email', () {
      expect(AuthValidators.validateEmail('user@example.com'), isNull);
    });
  });

  group('AuthValidators.validatePassword', () {
    test('returns error when password is empty', () {
      expect(AuthValidators.validatePassword(''), 'Password is required.');
    });

    test('returns error for short password', () {
      expect(
        AuthValidators.validatePassword('abc123'),
        'Password must be at least 8 characters.',
      );
    });

    test('accepts valid password length', () {
      expect(AuthValidators.validatePassword('abc12345'), isNull);
    });
  });

  group('AuthValidators.validateConfirmPassword', () {
    test('returns error when confirm password is empty', () {
      expect(
        AuthValidators.validateConfirmPassword(
          password: 'abc12345',
          confirmPassword: '',
        ),
        'Confirm password is required.',
      );
    });

    test('returns error when passwords mismatch', () {
      expect(
        AuthValidators.validateConfirmPassword(
          password: 'abc12345',
          confirmPassword: 'abc123456',
        ),
        'Passwords do not match.',
      );
    });

    test('accepts matching passwords', () {
      expect(
        AuthValidators.validateConfirmPassword(
          password: 'abc12345',
          confirmPassword: 'abc12345',
        ),
        isNull,
      );
    });
  });

  group('AuthValidators.validateDisplayName', () {
    test('returns error when display name is empty', () {
      expect(
        AuthValidators.validateDisplayName('   '),
        'Display name is required.',
      );
    });

    test('returns error when display name is too short', () {
      expect(
        AuthValidators.validateDisplayName('a'),
        'Display name must be between 2 and 40 characters.',
      );
    });

    test('accepts valid display name', () {
      expect(AuthValidators.validateDisplayName('Wassim'), isNull);
    });
  });
}
