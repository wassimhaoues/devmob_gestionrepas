class AuthValidators {
  static final RegExp _emailRegex = RegExp(
    r'^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$',
    caseSensitive: false,
  );

  static String? validateEmail(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return 'Email is required.';
    }
    if (!_emailRegex.hasMatch(normalized)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  static String? validatePassword(String value) {
    if (value.isEmpty) {
      return 'Password is required.';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters.';
    }
    return null;
  }

  static String? validateConfirmPassword({
    required String password,
    required String confirmPassword,
  }) {
    if (confirmPassword.isEmpty) {
      return 'Confirm password is required.';
    }
    if (password != confirmPassword) {
      return 'Passwords do not match.';
    }
    return null;
  }

  static String? validateDisplayName(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return 'Display name is required.';
    }
    if (normalized.length < 2 || normalized.length > 40) {
      return 'Display name must be between 2 and 40 characters.';
    }
    return null;
  }
}
