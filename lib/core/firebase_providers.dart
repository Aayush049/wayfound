import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const bool kUseEmulators = bool.fromEnvironment(
  'USE_EMULATORS',
  defaultValue: false,
);
const String _kDefaultEmulatorHost = kIsWeb ? 'localhost' : '10.0.2.2';
const String kEmulatorHost = String.fromEnvironment(
  'EMULATOR_HOST',
  defaultValue: _kDefaultEmulatorHost,
);

/// Configures Firebase services to use local emulators if [kUseEmulators] is true.
Future<void> setupFirebaseEmulators() async {
  if (kUseEmulators) {
    final host = (kIsWeb && kEmulatorHost == '10.0.2.2')
        ? 'localhost'
        : kEmulatorHost;
    if (kDebugMode) {
      debugPrint('Connecting to Firebase Emulators at $host');
    }
    // Connect Auth emulator
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);

    // Connect Firestore emulator
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8092);
  }
}

/// Provider for [FirebaseAuth] instance.
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

/// Provider for [FirebaseFirestore] instance.
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});
