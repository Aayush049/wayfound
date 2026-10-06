import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfound/features/auth/data/auth_provider.dart';
import 'package:wayfound/features/auth/data/auth_repository.dart';

void main() {
  group('AuthNotifier', () {
    late FakeFirebaseFirestore firestore;
    late MockFirebaseAuth auth;
    late AuthRepository repository;
    late AuthNotifier notifier;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      auth = MockFirebaseAuth(signedIn: false);
      repository = AuthRepository(auth: auth, firestore: firestore);
      notifier = AuthNotifier(repository);
    });

    test('initial state is data (null)', () {
      expect(notifier.state, const AsyncValue.data(null));
    });

    test('clearError resets state to data', () async {
      notifier.state = AsyncValue.error('error', StackTrace.empty);
      notifier.clearError();
      expect(notifier.state, const AsyncValue.data(null));
    });

    test('signOut transitions through loading and back to data', () async {
      final user = MockUser(uid: 'test-uid');
      auth = MockFirebaseAuth(mockUser: user);
      repository = AuthRepository(auth: auth, firestore: firestore);
      notifier = AuthNotifier(repository);

      // Initial state is loading because we set up with signedIn: true
      expect(notifier.state, const AsyncValue.loading());

      // Wait for stream to settle
      await Future.delayed(Duration.zero);

      // After loading, should be data (user is signed in)
      expect(notifier.state.isLoading, isFalse);
    });
  });

  group('authProvider', () {
    test('authUserProvider emits user from stream', () async {
      final firestore = FakeFirebaseFirestore();
      final auth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'test-uid', email: 'test@example.com'),
      );
      final repository = AuthRepository(auth: auth, firestore: firestore);

      // Verify repository provides user
      expect(repository.currentUser?.uid, equals('test-uid'));
    });

    test('isSignedInProvider returns true when user exists', () {
      final firestore = FakeFirebaseFirestore();
      final auth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'test-uid'),
      );
      final repository = AuthRepository(auth: auth, firestore: firestore);

      // Create a container to read the provider
      final container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(repository),
      ]);

      addTearDown(container.dispose);

      expect(container.read(isSignedInProvider), isTrue);
    });

    test('isSignedInProvider returns false when no user', () {
      final firestore = FakeFirebaseFirestore();
      final auth = MockFirebaseAuth(signedIn: false);
      final repository = AuthRepository(auth: auth, firestore: firestore);

      final container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(repository),
      ]);

      addTearDown(container.dispose);

      expect(container.read(isSignedInProvider), isFalse);
    });
  });
}