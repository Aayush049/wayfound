import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Repository for Firebase Authentication operations.
/// All Firebase Auth calls must go through this layer (Section 9 architecture).
class AuthRepository {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final FirebaseFirestore _firestore;

  AuthRepository({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
        _firestore = firestore ?? FirebaseFirestore.instance {
    // Initialize GoogleSignIn if not already initialized
    _googleSignIn.initialize();
  }

  /// Stream of authentication state changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Current authenticated user, or null if signed out.
  User? get currentUser => _auth.currentUser;

  /// Creates or updates a user document in Firestore.
  /// Called on first sign-in and on profile updates.
  Future<void> createOrUpdateUserDoc({
    required String uid,
    required String email,
    String? displayName,
    String? photoUrl,
  }) async {
    final userRef = _firestore.collection('users').doc(uid);
    final now = FieldValue.serverTimestamp();

    await userRef.set({
      'uid': uid,
      'email': email,
      'displayName': displayName ?? email.split('@').first,
      'photoUrl': photoUrl,
      'createdAt': now,
      'updatedAt': now,
    }, SetOptions(merge: true));
  }

  /// Fetches the user document from Firestore.
  Future<Map<String, dynamic>?> getUserDoc(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  /// Signs in with email and password.
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    // Ensure user document exists
    if (credential.user != null) {
      await createOrUpdateUserDoc(
        uid: credential.user!.uid,
        email: credential.user!.email ?? email,
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
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    // Create user document
    if (credential.user != null) {
      await createOrUpdateUserDoc(
        uid: credential.user!.uid,
        email: credential.user!.email ?? email,
        displayName: credential.user!.displayName,
        photoUrl: credential.user!.photoURL,
      );
    }
    return credential;
  }

  /// Signs in with Google.
  /// Requires SHA-1 fingerprint registered in Firebase Console.
  Future<UserCredential> signInWithGoogle() async {
    // Trigger the authentication flow using the 7.x API
    final GoogleSignInAccount account;
    try {
      account = await _googleSignIn.authenticate();
    } on GoogleSignInException {
      throw Exception('Google sign-in was cancelled');
    }

    // Get the ID token for Firebase Auth
    final authentication = account.authentication;
    final idToken = authentication.idToken;

    if (idToken == null) {
      throw Exception('Google sign-in failed to get ID token');
    }

    // Create Firebase credential
    final credential = GoogleAuthProvider.credential(
      idToken: idToken,
      accessToken: null,
    );

    // Sign in with credential
    final userCredential = await _auth.signInWithCredential(credential);

    // Create user document on first sign-in
    if (userCredential.user != null) {
      await createOrUpdateUserDoc(
        uid: userCredential.user!.uid,
        email: userCredential.user!.email ?? account.email,
        displayName: userCredential.user!.displayName ?? account.displayName,
        photoUrl: userCredential.user!.photoURL ?? account.photoUrl,
      );
    }

    return userCredential;
  }

  /// Signs out from all providers.
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  /// Sends a password reset email.
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Deletes the current user's account.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user != null) {
      // Delete user document
      await _firestore.collection('users').doc(user.uid).delete();
      // Delete auth account
      await user.delete();
    }
  }
}