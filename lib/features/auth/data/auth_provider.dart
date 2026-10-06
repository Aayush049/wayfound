import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/riverpod.dart';

import 'auth_repository.dart';

/// Provider for [AuthRepository] instance.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

/// Provider for the current authenticated [User].
final authUserProvider = StreamProvider<User?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository.authStateChanges;
});

/// Provider for auth state: true if user is signed in.
final isSignedInProvider = Provider<bool>((ref) {
  final authUser = ref.watch(authUserProvider);
  return authUser.when(
    data: (user) => user != null,
    loading: () => false,
    error: (_, __) => false,
  );
});

/// Notifier for auth actions (sign-in, sign-up, sign-out).
/// Uses AsyncNotifier for flutter_riverpod 3.x compatibility.
class AuthNotifier extends AsyncNotifier<void> {
  final AuthRepository _repository;

  AuthNotifier({AuthRepository? repository})
      : _repository = repository ?? AuthRepository();

  @override
  Future<void> build() async {
    // Initial state is data(null)
    return;
  }

  /// Signs in with email and password.
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    try {
      await _repository.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Signs up with email and password.
  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    try {
      await _repository.signUpWithEmailAndPassword(
        email: email,
        password: password,
      );
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Signs in with Google.
  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    try {
      await _repository.signInWithGoogle();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Signs out.
  Future<void> signOut() async {
    state = const AsyncLoading();
    try {
      await _repository.signOut();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Sends password reset email.
  Future<void> sendPasswordReset(String email) async {
    state = const AsyncLoading();
    try {
      await _repository.sendPasswordResetEmail(email);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Clears the error state after user has handled it.
  void clearError() {
    state = const AsyncData(null);
  }
}

/// Provider for auth actions using AsyncNotifier.
final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, void>(
  AuthNotifier.new,
);