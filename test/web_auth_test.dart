import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_mocks/google_sign_in_mocks.dart';
import 'package:wayfound/features/auth/data/auth_repository.dart';

class TrackingAuth extends MockFirebaseAuth {
  TrackingAuth({super.mockUser});

  bool signInWithPopupCalled = false;
  bool signInWithCredentialCalled = false;

  @override
  Future<UserCredential> signInWithPopup(AuthProvider provider) async {
    signInWithPopupCalled = true;
    return super.signInWithPopup(provider);
  }

  @override
  Future<UserCredential> signInWithCredential(
    AuthCredential? credential,
  ) async {
    signInWithCredentialCalled = true;
    return super.signInWithCredential(credential);
  }
}

class FakeGoogleSignInAccount extends MockGoogleSignInAccount {
  @override
  String get email => 'google-user@example.com';

  @override
  String? get displayName => 'Google User';

  @override
  String? get photoUrl => null;
}

class FakeGoogleSignIn extends MockGoogleSignIn {
  @override
  Future<GoogleSignInAccount> authenticate({
    List<String> scopeHint = const <String>[],
  }) async {
    return FakeGoogleSignInAccount();
  }
}

void main() {
  group('AuthRepository Web vs Mobile Sign-In (T2)', () {
    late FakeFirebaseFirestore firestore;
    late FakeGoogleSignIn googleSignIn;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      googleSignIn = FakeGoogleSignIn();
    });

    test('chooses web popup path when isWeb is true and does not use mobile credential flow', () async {
      final auth = TrackingAuth(
        mockUser: MockUser(uid: 'web-user', email: 'web@example.com'),
      );
      final repo = AuthRepository(
        auth: auth,
        googleSignIn: googleSignIn,
        firestore: firestore,
        isWeb: true,
      );

      final result = await repo.signInWithGoogle();

      expect(result, isNotNull);
      expect(auth.signInWithPopupCalled, isTrue);
      expect(auth.signInWithCredentialCalled, isFalse);
    });

    test('chooses mobile credential path when isWeb is false and does not use web popup flow', () async {
      final auth = TrackingAuth(
        mockUser: MockUser(uid: 'mobile-user', email: 'mobile@example.com'),
      );
      final repo = AuthRepository(
        auth: auth,
        googleSignIn: googleSignIn,
        firestore: firestore,
        isWeb: false,
      );

      final result = await repo.signInWithGoogle();

      expect(result, isNotNull);
      expect(auth.signInWithPopupCalled, isFalse);
      expect(auth.signInWithCredentialCalled, isTrue);
    });
  });
}
