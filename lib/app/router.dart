import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/data/auth_provider.dart';
import '../features/auth/presentation/settings_screen.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/auth/presentation/welcome_screen.dart';
import '../features/trips/presentation/home_screen.dart';

/// Provider for the app's [GoRouter] configuration with auth redirect.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/welcome',
    redirect: (BuildContext context, GoRouterState state) {
      final isSignedIn = ref.read(isSignedInProvider);
      final isOnAuthScreen = state.matchedLocation.startsWith('/welcome') ||
          state.matchedLocation.startsWith('/signin');

      // Redirect signed-in users away from auth screens
      if (isSignedIn && isOnAuthScreen) {
        return '/home';
      }

      // Redirect signed-out users to welcome from protected screens
      if (!isSignedIn && !isOnAuthScreen) {
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
        path: '/signin',
        builder: (context, state) => const SignInScreen(),
      ),

      // Protected routes (require auth)
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});
