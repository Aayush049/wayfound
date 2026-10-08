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

/// Home screen showing "My Trips" list and expandable FAB menu to create or join trips.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isExpanded = false;

  void _toggleMenu() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  void _closeMenu() {
    if (_isExpanded) {
      setState(() {
        _isExpanded = false;
      });
    }
  }

  void _navigateToCreate() {
    _closeMenu();
    context.push('/trip/create');
  }

  void _navigateToJoin() {
    _closeMenu();
    context.push('/trip/join');
  }

  @override
  Widget build(BuildContext context) {
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

    return PopScope(
      canPop: !_isExpanded,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isExpanded) {
          _closeMenu();
        }
      },
      child: Scaffold(
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
        body: Stack(
          children: [
            myTripsAsync.when(
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
                    onAction: _navigateToCreate,
                    secondaryActionLabel: 'Join with Code',
                    onSecondaryAction: _navigateToJoin,
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 120),
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
            if (_isExpanded)
              Positioned.fill(
                child: GestureDetector(
                  key: const Key('home_fab_scrim'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _closeMenu,
                  child: Container(
                    color: theme.colorScheme.scrim.withValues(alpha: 0.32),
                  ),
                ),
              ),
          ],
        ),
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (_isExpanded) ...[
              // Action 1: Create Trip
              GestureDetector(
                onTap: _navigateToCreate,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Material(
                      elevation: 3,
                      borderRadius: BorderRadius.circular(8),
                      color: theme.colorScheme.surface,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Text(
                          'Create Trip',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Semantics(
                      label: 'Create Trip',
                      button: true,
                      child: FloatingActionButton.small(
                        key: const Key('fab_action_create_trip'),
                        heroTag: 'fab_action_create_trip',
                        tooltip: 'Create Trip',
                        backgroundColor: theme.colorScheme.secondaryContainer,
                        foregroundColor: theme.colorScheme.onSecondaryContainer,
                        onPressed: _navigateToCreate,
                        child: const Icon(Icons.add),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Action 2: Join Trip
              GestureDetector(
                onTap: _navigateToJoin,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Material(
                      elevation: 3,
                      borderRadius: BorderRadius.circular(8),
                      color: theme.colorScheme.surface,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Text(
                          'Join Trip',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Semantics(
                      label: 'Join Trip',
                      button: true,
                      child: FloatingActionButton.small(
                        key: const Key('fab_action_join_trip'),
                        heroTag: 'fab_action_join_trip',
                        tooltip: 'Join Trip',
                        backgroundColor: theme.colorScheme.secondaryContainer,
                        foregroundColor: theme.colorScheme.onSecondaryContainer,
                        onPressed: _navigateToJoin,
                        child: const Icon(Icons.group_add_outlined),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Semantics(
              label: _isExpanded ? 'Close trip actions' : 'Trip actions',
              button: true,
              child: FloatingActionButton(
                key: const Key('home_fab_menu_button'),
                heroTag: 'home_fab_menu_button',
                tooltip: _isExpanded ? 'Close trip actions' : 'Trip actions',
                onPressed: _toggleMenu,
                child: Icon(_isExpanded ? Icons.close : Icons.add),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
