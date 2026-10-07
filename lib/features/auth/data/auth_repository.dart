import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../domain/app_user.dart';

/// Repository for Firebase Authentication operations.
/// All Firebase Auth calls must go through this layer (Section 9 architecture).
class AuthRepository {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final FirebaseFirestore _firestore;
  bool _googleInitialized = false;

  AuthRepository({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    FirebaseFirestore? firestore,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  void _ensureGoogleInitialized() {
    if (!_googleInitialized) {
      _googleInitialized = true;
      _googleSignIn.initialize();
    }
  }

  /// Stream of authentication state changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Current authenticated user, or null if signed out.
  User? get currentUser => _auth.currentUser;

  /// Creates a user document in Firestore ONCE on first sign-in or sign-up.
  /// Never overwrites an existing document's createdAt.
  /// If creation fails, signs out to avoid half-signed-in state.
  Future<void> createOnceUserDoc({
    required String uid,
    required String email,
    String? displayName,
    String? photoUrl,
  }) async {
    final userRef = _firestore.collection('users').doc(uid);

    try {
      final doc = await userRef.get();
      if (!doc.exists) {
        final fallbackName =
            displayName != null && displayName.trim().isNotEmpty
            ? displayName.trim()
            : email.split('@').first;

        final userObj = AppUser(
          uid: uid,
          email: email.trim().toLowerCase(),
          displayName: fallbackName,
          photoUrl: photoUrl,
        );

        await userRef.set(userObj.toFirestoreCreate());
      }
    } catch (e) {
      // If user document creation fails (e.g. security rules not deployed),
      // clean up auth state so we never leave a half-signed-in state.
      await signOut();
      throw Exception('user-doc-creation-failed: $e');
    }
  }

  /// Fetches the user document from Firestore.
  Future<Map<String, dynamic>?> getUserDoc(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  /// Stream of user profile document from Firestore `users/{uid}`.
  Stream<AppUser?> userStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return AppUser.fromFirestore(snapshot);
      }
      final user = _auth.currentUser;
      if (user != null && user.uid == uid) {
        return AppUser(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName ?? user.email?.split('@').first ?? '',
          photoUrl: user.photoURL,
        );
      }
      return null;
    });
  }

  /// Updates the user's display name in both FirebaseAuth and Firestore users/{uid}.
  /// If Firestore update fails, rolls back Auth profile to avoid silent divergence.
  Future<void> updateDisplayName(String displayName) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found');
    }

    final trimmedName = displayName.trim();
    if (trimmedName.isEmpty || trimmedName.length > 50) {
      throw Exception('Display name must be between 1 and 50 characters');
    }

    final oldAuthDisplayName = user.displayName;

    // Update Firebase Auth profile
    await user.updateDisplayName(trimmedName);

    try {
      // Update Firestore users/{uid} document
      await _firestore.collection('users').doc(user.uid).update({
        'displayName': trimmedName,
      });
    } catch (e) {
      // Revert Auth display name if Firestore update fails to prevent silent divergence
      if (oldAuthDisplayName != null) {
        await user.updateDisplayName(oldAuthDisplayName);
      }
      rethrow;
    }
  }

  /// Signs in with email and password.
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final credential = await _auth.signInWithEmailAndPassword(
      email: normalizedEmail,
      password: password,
    );

    if (credential.user != null) {
      await createOnceUserDoc(
        uid: credential.user!.uid,
        email: credential.user!.email ?? normalizedEmail,
        displayName: credential.user!.displayName,
        photoUrl: credential.user!.photoURL,
      );
    }
    return credential;
  }

  /// Signs up with email and password.
  Future<UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final trimmedDisplayName = displayName.trim();

    final credential = await _auth.createUserWithEmailAndPassword(
      email: normalizedEmail,
      password: password,
    );

    if (credential.user != null) {
      await credential.user!.updateDisplayName(trimmedDisplayName);
      await createOnceUserDoc(
        uid: credential.user!.uid,
        email: credential.user!.email ?? normalizedEmail,
        displayName: trimmedDisplayName,
        photoUrl: null,
      );
    }
    return credential;
  }

  /// Signs in with Google using 7.x API.
  Future<UserCredential?> signInWithGoogle() async {
    _ensureGoogleInitialized();

    final GoogleSignInAccount account;
    try {
      account = await _googleSignIn.authenticate();
    } on GoogleSignInException {
      // User cancelled sign-in or google sign-in was cancelled
      return null;
    } catch (e) {
      if (e.toString().contains('cancelled')) {
        return null;
      }
      rethrow;
    }

    final authentication = account.authentication;
    final idToken = authentication.idToken;

    if (idToken == null) {
      throw Exception('Google sign-in failed to get ID token');
    }

    final credential = GoogleAuthProvider.credential(
      idToken: idToken,
      accessToken: null,
    );

    final userCredential = await _auth.signInWithCredential(credential);

    if (userCredential.user != null) {
      await createOnceUserDoc(
        uid: userCredential.user!.uid,
        email: userCredential.user!.email ?? account.email,
        displayName: userCredential.user!.displayName ?? account.displayName,
        photoUrl: userCredential.user!.photoURL ?? account.photoUrl,
      );
    }

    return userCredential;
  }

  /// Signs out from all providers (FirebaseAuth and GoogleSignIn).
  Future<void> signOut() async {
    await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
  }
}
