/// Validation rules and error message formatting for Auth.
class AuthValidators {
  static const int minNameLength = 1;
  static const int maxNameLength = 50;
  static const int minPasswordLength = 8;

  /// Validates a display name.
  static String? validateDisplayName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your display name';
    }
    final trimmed = value.trim();
    if (trimmed.length < minNameLength) {
      return 'Display name cannot be empty';
    }
    if (trimmed.length > maxNameLength) {
      return 'Display name must be 50 characters or less';
    }
    return null;
  }

  /// Validates an email address.
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email';
    }
    final trimmed = value.trim();
    final emailRegex = RegExp(r'^[\w\+\-\.]+@([\w-]+\.)+[\w-]{2,}$');
    if (!emailRegex.hasMatch(trimmed)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  /// Validates a password.
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (value.length < minPasswordLength) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  /// Validates password confirmation.
  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != password) {
      return 'Passwords do not match';
    }
    return null;
  }

  /// Formats an auth-related error into a user-friendly message.
  static String formatAuthError(Object? error) {
    if (error == null) return '';
    final errorStr = error.toString();

    if (errorStr.contains('user-not-found') ||
        errorStr.contains('wrong-password') ||
        errorStr.contains('invalid-credential')) {
      return 'Incorrect email or password.';
    }
    if (errorStr.contains('email-already-in-use')) {
      return 'An account already exists with this email.';
    }
    if (errorStr.contains('invalid-email')) {
      return 'Please enter a valid email address.';
    }
    if (errorStr.contains('weak-password')) {
      return 'Password must be at least 8 characters.';
    }
    if (errorStr.contains('network-request-failed')) {
      return 'Network error. Please check your connection.';
    }
    if (errorStr.contains('cancelled') ||
        errorStr.contains('GoogleSignInException')) {
      return ''; // Cancelled Google sign-in is not an error
    }
    if (errorStr.contains('user-doc-creation-failed')) {
      return 'Failed to create user profile. Security rules may not be deployed.';
    }
    if (errorStr.contains('Failed to update display name')) {
      return 'Failed to update display name. Please try again.';
    }
    return 'An error occurred. Please try again.';
  }
}
