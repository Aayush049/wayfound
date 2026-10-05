import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/welcome_screen.dart';
import '../features/trips/presentation/home_screen.dart';

/// Provider for the app's [GoRouter] configuration.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/welcome',
    // TEMP(phase-1): Auth redirect hook will go here.
    // redirect: (BuildContext context, GoRouterState state) {
    //   // Check auth state from provider
    //   // return '/welcome' or null
    //   return null;
    // },
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    ],
  );
});
