import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/app_loading.dart';
import '../features/auth/data/auth_provider.dart';
import '../features/auth/presentation/settings_screen.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/auth/presentation/sign_up_screen.dart';
import '../features/auth/presentation/welcome_screen.dart';
import '../features/trips/presentation/home_screen.dart';

/// Helper to bridge Stream to [ChangeNotifier] for GoRouter refresh.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// Provider for the app's [GoRouter] configuration with auth redirect.
final routerProvider = Provider<GoRouter>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);

  return GoRouter(
    initialLocation: '/welcome',
    refreshListenable: GoRouterRefreshStream(authRepository.authStateChanges),
    redirect: (BuildContext context, GoRouterState state) {
      final authState = ref.read(authUserProvider);

      // Show neutral loading while auth state resolves
      if (authState.isLoading) {
        return null;
      }

      final user = authState.asData?.value;
      final isSignedIn = user != null;
      final matched = state.matchedLocation;

      final isAuthRoute =
          matched == '/welcome' ||
          matched == '/sign-in' ||
          matched == '/sign-up';

      // Redirect signed-in users away from auth screens to home
      if (isSignedIn && isAuthRoute) {
        return '/home';
      }

      // Redirect signed-out users away from protected screens to welcome
      if (!isSignedIn && !isAuthRoute) {
        return '/welcome';
      }

      // No redirect needed
      return null;
    },
    routes: [
      // Auth routes (public)
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/sign-up',
        builder: (context, state) => const SignUpScreen(),
      ),

      // Protected routes (require auth)
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
    errorBuilder: (context, state) => const Scaffold(
      body: Center(child: AppLoading(message: 'Resolving auth...')),
    ),
  );
});
