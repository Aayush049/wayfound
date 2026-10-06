import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfound/features/auth/data/auth_provider.dart';

void main() {
  group('AuthNotifier', () {
    test('isSignedInProvider returns false when signed out', () {
      final container = ProviderContainer(
        overrides: [authUserProvider.overrideWithValue(const AsyncData(null))],
      );
      addTearDown(container.dispose);

      expect(container.read(isSignedInProvider), isFalse);
    });

    test('isSignedInProvider returns true when signed in', () {
      final mockUser = MockUser(uid: 'test-uid', email: 'test@example.com');
      final container = ProviderContainer(
        overrides: [authUserProvider.overrideWithValue(AsyncData(mockUser))],
      );
      addTearDown(container.dispose);

      expect(container.read(isSignedInProvider), isTrue);
    });
  });
}
