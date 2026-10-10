import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/app_loading.dart';
import '../features/auth/data/auth_provider.dart';
import '../features/auth/presentation/settings_screen.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/auth/presentation/sign_up_screen.dart';
import '../features/auth/presentation/welcome_screen.dart';
import '../features/suggestions/presentation/add_edit_suggestion_screen.dart';
import '../features/trips/presentation/create_trip_screen.dart';
import '../features/trips/presentation/home_screen.dart';
import '../features/trips/presentation/join_trip_screen.dart';
import '../features/trips/presentation/trip_dashboard_screen.dart';

/// Provider for the app's [GoRouter] configuration with auth redirect.
final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ValueNotifier<AsyncValue<User?>>(
    const AsyncLoading(),
  );

  ref.listen<AsyncValue<User?>>(authUserProvider, (previous, next) {
    refreshNotifier.value = next;
  }, fireImmediately: true);

  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: '/welcome',
    refreshListenable: refreshNotifier,
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

      // Trip create & join routes (MUST be defined before /trip/:id so they aren't captured as an id!)
      GoRoute(
        path: '/trip/create',
        builder: (context, state) => const CreateTripScreen(),
      ),
      GoRoute(
        path: '/trip/join',
        builder: (context, state) => const JoinTripScreen(),
      ),

      // Trip dashboard routes (/trip/:id and sub-tabs)
      GoRoute(
        path: '/trip/:id',
        redirect: (context, state) {
          final id = state.pathParameters['id'];
          final path = state.uri.path;
          if (path == '/trip/$id' || path == '/trip/$id/') {
            return '/trip/$id/members';
          }
          return null;
        },
        routes: [
          GoRoute(
            path: 'suggestions/add',
            builder: (context, state) =>
                AddEditSuggestionScreen(tripId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'suggestions/:sid/edit',
            builder: (context, state) => AddEditSuggestionScreen(
              tripId: state.pathParameters['id']!,
              suggestionId: state.pathParameters['sid'],
            ),
          ),
          GoRoute(
            path: 'suggestions',
            builder: (context, state) => TripDashboardScreen(
              tripId: state.pathParameters['id']!,
              activeTab: 'suggestions',
            ),
          ),
          GoRoute(
            path: 'itinerary',
            builder: (context, state) => TripDashboardScreen(
              tripId: state.pathParameters['id']!,
              activeTab: 'itinerary',
            ),
          ),
          GoRoute(
            path: 'expenses',
            builder: (context, state) => TripDashboardScreen(
              tripId: state.pathParameters['id']!,
              activeTab: 'expenses',
            ),
          ),
          GoRoute(
            path: 'members',
            builder: (context, state) => TripDashboardScreen(
              tripId: state.pathParameters['id']!,
              activeTab: 'members',
            ),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => const Scaffold(
      body: Center(child: AppLoading(message: 'Resolving auth...')),
    ),
  );
});
