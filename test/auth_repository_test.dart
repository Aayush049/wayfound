import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
        googleSignIn = MockGoogleSignIn();
        repository = AuthRepository(
          auth: auth,
          googleSignIn: googleSignIn,
          firestore: firestore,
        );

        expect(repository.currentUser?.uid, equals('test-uid'));
        expect(repository.currentUser?.email, equals('test@example.com'));
      });
    });

    group('authStateChanges', () {
      test('emits null initially when no user', () async {
        final stream = repository.authStateChanges;
        expect(stream, emits(isNull));
      });

      test('emits user after sign-in', () async {
        final user = MockUser(uid: 'test-uid', email: 'test@example.com');
        auth = MockFirebaseAuth(mockUser: user);
        repository = AuthRepository(
          auth: auth,
          googleSignIn: googleSignIn,
          firestore: firestore,
        );

        expect(repository.authStateChanges, emits(user));
      });
    });

    group('createOrUpdateUserDoc', () {
      test('creates user document with correct fields', () async {
        await repository.createOrUpdateUserDoc(
          uid: 'user-123',
          email: 'test@example.com',
          displayName: 'Test User',
          photoUrl: 'https://example.com/photo.jpg',
        );

        final doc = await firestore.collection('users').doc('user-123').get();
        expect(doc.exists, isTrue);
        expect(doc.data()?['uid'], equals('user-123'));
        expect(doc.data()?['email'], equals('test@example.com'));
        expect(doc.data()?['displayName'], equals('Test User'));
        expect(
          doc.data()?['photoUrl'],
          equals('https://example.com/photo.jpg'),
        );
        expect(doc.data()?['createdAt'], isNotNull);
        expect(doc.data()?['updatedAt'], isNotNull);
      });

      test('merges with existing document', () async {
        await firestore.collection('users').doc('user-123').set({
          'uid': 'user-123',
          'email': 'old@example.com',
        });

        await repository.createOrUpdateUserDoc(
          uid: 'user-123',
          email: 'new@example.com',
          displayName: 'Updated User',
        );

        final doc = await firestore.collection('users').doc('user-123').get();
        expect(doc.data()?['email'], equals('new@example.com'));
        expect(doc.data()?['displayName'], equals('Updated User'));
      });
    });

    group('getUserDoc', () {
      test('returns null when document does not exist', () async {
        final doc = await repository.getUserDoc('non-existent');
        expect(doc, isNull);
      });

      test('returns document data when exists', () async {
        await firestore.collection('users').doc('user-123').set({
          'uid': 'user-123',
          'email': 'test@example.com',
          'displayName': 'Test',
        });

        final doc = await repository.getUserDoc('user-123');
        expect(doc, isNotNull);
        expect(doc?['uid'], equals('user-123'));
        expect(doc?['email'], equals('test@example.com'));
      });
    });

    group('signInWithEmailAndPassword', () {
      test('creates user document on successful sign-in', () async {
        auth = MockFirebaseAuth(signedIn: false);
        googleSignIn = MockGoogleSignIn();
        repository = AuthRepository(
          auth: auth,
          googleSignIn: googleSignIn,
          firestore: firestore,
        );

        // Mock sign-in creates the user
        auth = MockFirebaseAuth(
          mockUser: MockUser(uid: 'new-user-uid', email: 'new@example.com'),
        );
        repository = AuthRepository(
          auth: auth,
          googleSignIn: googleSignIn,
          firestore: firestore,
        );

        // Sign in and verify doc is created
        await repository.signInWithEmailAndPassword(
          email: 'new@example.com',
          password: 'password123',
        );

        final doc = await firestore
            .collection('users')
            .doc('new-user-uid')
            .get();
        expect(doc.exists, isTrue);
      });
    });

    group('signOut', () {
      test('signs out from Firebase Auth', () async {
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