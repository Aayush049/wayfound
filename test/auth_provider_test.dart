import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfound/features/auth/data/auth_provider.dart';
import 'package:wayfound/features/auth/data/auth_repository.dart';

void main() {
  group('AuthNotifier', () {
    late FakeFirebaseFirestore firestore;
    late MockFirebaseAuth auth;
    late AuthRepository repository;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      auth = MockFirebaseAuth(signedIn: false);
      repository = AuthRepository(auth: auth, firestore: firestore);
    });

    test('isSignedInProvider returns false when signed out', () {
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      expect(container.read(isSignedInProvider), isFalse);
    });

    test('isSignedInProvider returns true when signed in', () {
      auth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'test-uid', email: 'test@example.com'),
      );
      repository = AuthRepository(auth: auth, firestore: firestore);

      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      expect(container.read(isSignedInProvider), isTrue);
    });
  });
}
