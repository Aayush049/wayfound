import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/theme_provider.dart';
import '../../../core/widgets/app_empty.dart';
import '../../../core/widgets/app_error.dart';
import '../../../core/widgets/app_loading.dart';
import '../../auth/data/auth_provider.dart';
import '../data/trips_providers.dart';
import 'trip_card.dart';

/// Home screen showing "My Trips" list and actions to create or join trips.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final appUserAsync = ref.watch(appUserProvider);
    final myTripsAsync = ref.watch(myTripsProvider);
    final authUser = ref.watch(authUserProvider).asData?.value;

    final user = appUserAsync.asData?.value;
    final displayName =
        user?.displayName ??
        (user?.email.isNotEmpty == true ? user!.email.split('@').first : '');
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Trips'),
        actions: [
          // Quick theme toggle button (Section 14.3)
          IconButton(
            key: const Key('home_theme_toggle_button'),
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            tooltip: 'Toggle Theme',
            onPressed: () {
              ref.read(themeProvider.notifier).toggleTheme(theme.brightness);
            },
          ),
          // Action button to Join with code
          IconButton(
            icon: const Icon(Icons.qr_code),
            tooltip: 'Join with code',
            onPressed: () => context.push('/trip/join'),
          ),
          // User Avatar button reaching Settings screen
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              onTap: () => context.go('/settings'),
              child: Tooltip(
                message: 'Settings',
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  backgroundImage:
                      user?.photoUrl != null && user!.photoUrl!.isNotEmpty
                      ? NetworkImage(user.photoUrl!)
                      : null,
                  child: (user?.photoUrl == null || user!.photoUrl!.isEmpty)
                      ? Text(
                          initial,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
      body: myTripsAsync.when(
        loading: () => const AppLoading(message: 'Loading your trips...'),
        error: (err, stack) => AppError(
          message: 'Failed to load trips: ${err.toString()}',
          onRetry: () => ref.invalidate(myTripsProvider),
        ),
        data: (trips) {
          if (trips.isEmpty) {
            return AppEmpty(
              title: 'No trips yet',
              message: 'Create a new trip to invite your friends or join an existing trip with a 6-character code.',
              icon: Icons.luggage_outlined,
              actionLabel: 'Create a Trip',
              onAction: () => context.push('/trip/create'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 88),
            itemCount: trips.length,
            itemBuilder: (context, index) {
              final trip = trips[index];
              return TripCard(
                trip: trip,
                currentUid: authUser?.uid ?? '',
                onTap: () => context.push('/trip/${trip.id}/members'),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/trip/create'),
        icon: const Icon(Icons.add),
        label: const Text('Create Trip'),
      ),
    );
  }
}
