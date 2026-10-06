import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_mocks/google_sign_in_mocks.dart';
import 'package:wayfound/features/auth/data/auth_repository.dart';

void main() {
  group('AuthRepository', () {
    late FakeFirebaseFirestore firestore;
    late MockFirebaseAuth auth;
    late MockGoogleSignIn googleSignIn;
    late AuthRepository repository;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      auth = MockFirebaseAuth();
      googleSignIn = MockGoogleSignIn();
      repository = AuthRepository(
        auth: auth,
        googleSignIn: googleSignIn,
        firestore: firestore,
      );
    });

    group('currentUser', () {
      test('returns null when no user is signed in', () {
        expect(repository.currentUser, isNull);
      });

      test('returns user when signed in', () async {
        final user = MockUser(uid: 'test-uid', email: 'test@example.com');
        auth = MockFirebaseAuth(mockUser: user);
        repository = AuthRepository(
          auth: auth,
          googleSignIn: googleSignIn,
          firestore: firestore,
        );

        expect(repository.currentUser?.uid, equals('test-uid'));
        expect(repository.currentUser?.email, equals('test@example.com'));
      });
    });

    group('createOnceUserDoc', () {
      test('creates user document on first call with correct fields', () async {
        await repository.createOnceUserDoc(
          uid: 'user-123',
          email: 'test@example.com',
          displayName: 'Test User',
          photoUrl: 'https://example.com/photo.jpg',
        );

        final doc = await firestore.collection('users').doc('user-123').get();
        expect(doc.exists, isTrue);
        expect(doc.data()?['email'], equals('test@example.com'));
        expect(doc.data()?['displayName'], equals('Test User'));
        expect(
          doc.data()?['photoUrl'],
          equals('https://example.com/photo.jpg'),
        );
        expect(doc.data()?['createdAt'], isNotNull);
        // Ensure extraneous fields are not present
        expect(doc.data()?.containsKey('uid'), isFalse);
      });

      test(
        'does not overwrite existing user document on second call',
        () async {
          final initialTimestamp = DateTime(2026, 1, 1);
          await firestore.collection('users').doc('user-123').set({
            'displayName': 'Initial Name',
            'email': 'initial@example.com',
            'photoUrl': null,
            'createdAt': initialTimestamp.toIso8601String(),
          });

          // Second call should preserve initial document
          await repository.createOnceUserDoc(
            uid: 'user-123',
            email: 'new@example.com',
            displayName: 'New Name',
          );

          final doc = await firestore.collection('users').doc('user-123').get();
          expect(doc.data()?['displayName'], equals('Initial Name'));
          expect(doc.data()?['email'], equals('initial@example.com'));
        },
      );
    });

    group('getUserDoc', () {
      test('returns null when document does not exist', () async {
        final doc = await repository.getUserDoc('non-existent');
        expect(doc, isNull);
      });

      test('returns document data when exists', () async {
        await firestore.collection('users').doc('user-123').set({
          'displayName': 'Test',
          'email': 'test@example.com',
        });

        final doc = await repository.getUserDoc('user-123');
        expect(doc, isNotNull);
        expect(doc?['displayName'], equals('Test'));
        expect(doc?['email'], equals('test@example.com'));
      });
    });

    group('signOut', () {
      test('signs out from providers without errors', () async {
        final user = MockUser(uid: 'test-uid');
        auth = MockFirebaseAuth(mockUser: user);
        repository = AuthRepository(
          auth: auth,
          googleSignIn: googleSignIn,
          firestore: firestore,
        );

        await repository.signOut();
        expect(repository.currentUser, isNull);
      });
    });
  });
}
