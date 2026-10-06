import 'package:flutter_test/flutter_test.dart';
import 'package:wayfound/features/auth/domain/auth_validators.dart';

void main() {
  group('AuthValidators', () {
    group('validateDisplayName', () {
      test('returns error when null or empty', () {
        expect(AuthValidators.validateDisplayName(null), isNotNull);
        expect(AuthValidators.validateDisplayName(''), isNotNull);
        expect(AuthValidators.validateDisplayName('   '), isNotNull);
      });

      test('returns error when longer than 50 characters', () {
        final longName = 'A' * 51;
        expect(AuthValidators.validateDisplayName(longName), isNotNull);
      });

      test('returns null for valid display names', () {
        expect(AuthValidators.validateDisplayName('Aayush'), isNull);
        expect(AuthValidators.validateDisplayName('A' * 50), isNull);
      });
    });

    group('validateEmail', () {
      test('returns error when null or empty', () {
        expect(AuthValidators.validateEmail(null), isNotNull);
        expect(AuthValidators.validateEmail(''), isNotNull);
      });

      test('returns error for invalid email formats', () {
        expect(AuthValidators.validateEmail('invalidemail'), isNotNull);
        expect(AuthValidators.validateEmail('user@'), isNotNull);
        expect(AuthValidators.validateEmail('@domain.com'), isNotNull);
      });

      test('returns null for valid email address', () {
        expect(AuthValidators.validateEmail('test@example.com'), isNull);
        expect(
          AuthValidators.validateEmail('user.name+tag@domain.co.uk'),
          isNull,
        );
      });
    });

    group('validatePassword', () {
      test('returns error when null or empty', () {
        expect(AuthValidators.validatePassword(null), isNotNull);
        expect(AuthValidators.validatePassword(''), isNotNull);
      });

      test('returns error when password is less than 8 chars', () {
        expect(AuthValidators.validatePassword('1234567'), isNotNull);
      });

      test('returns null when password is 8 or more chars', () {
        expect(AuthValidators.validatePassword('12345678'), isNull);
        expect(AuthValidators.validatePassword('strongPassword123!'), isNull);
      });
    });

    group('validateConfirmPassword', () {
      test('returns error when null or empty', () {
        expect(
          AuthValidators.validateConfirmPassword(null, 'password123'),
          isNotNull,
        );
        expect(
          AuthValidators.validateConfirmPassword('', 'password123'),
          isNotNull,
        );
      });

      test('returns error when passwords do not match', () {
        expect(
          AuthValidators.validateConfirmPassword('different', 'password123'),
          isNotNull,
        );
      });

      test('returns null when passwords match', () {
        expect(
          AuthValidators.validateConfirmPassword('password123', 'password123'),
          isNull,
        );
      });
    });

    group('formatAuthError', () {
      test('returns empty string for null error', () {
        expect(AuthValidators.formatAuthError(null), equals(''));
      });

      test('maps user-not-found to friendly message', () {
        expect(
          AuthValidators.formatAuthError('user-not-found'),
          contains('Incorrect email or password'),
        );
      });

      test('maps wrong-password to friendly message', () {
        expect(
          AuthValidators.formatAuthError('wrong-password'),
          contains('Incorrect email or password'),
        );
      });

      test('maps email-already-in-use to friendly message', () {
        expect(
          AuthValidators.formatAuthError('email-already-in-use'),
          contains('already exists'),
        );
      });

      test('maps weak-password to friendly message', () {
        expect(
          AuthValidators.formatAuthError('weak-password'),
          contains('at least 8 characters'),
        );
      });

      test('maps cancelled Google sign-in to empty string', () {
        expect(AuthValidators.formatAuthError('cancelled'), equals(''));
        expect(
          AuthValidators.formatAuthError('GoogleSignInException'),
          equals(''),
        );
      });

      test('maps user-doc-creation-failed to friendly message', () {
        expect(
          AuthValidators.formatAuthError('user-doc-creation-failed'),
          contains('Security rules may not be deployed'),
        );
      });
    });
  });
}
