import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wayfound/app/theme/app_theme.dart';
import 'package:wayfound/features/auth/data/auth_provider.dart';
import 'package:wayfound/features/auth/domain/app_user.dart';
import 'package:wayfound/features/trips/data/trips_providers.dart';
import 'package:wayfound/features/trips/domain/trip.dart';
import 'package:wayfound/features/trips/presentation/home_screen.dart';

import 'helpers/pump_app.dart';

void main() {
  group('HomeScreen', () {
    final mockUser = MockUser(uid: 'user-123', email: 'test@example.com');
    final appUser = AppUser(
      uid: 'user-123',
      email: 'test@example.com',
      displayName: 'Test User',
    );

    Widget buildRouterHomeScreen({required AsyncValue<List<Trip>> tripsValue}) {
      SharedPreferences.setMockInitialValues({});
      return ProviderScope(
        overrides: [
          myTripsProvider.overrideWithValue(tripsValue),
          authUserProvider.overrideWithValue(AsyncData(mockUser)),
          appUserProvider.overrideWithValue(AsyncData(appUser)),
        ],
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          routerConfig: GoRouter(
            initialLocation: '/',
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreen(),
              ),
              GoRoute(
                path: '/trip/create',
                builder: (context, state) =>
                    const Scaffold(body: Text('Create Trip Screen Target')),
              ),
              GoRoute(
                path: '/trip/join',
                builder: (context, state) =>
                    const Scaffold(body: Text('Join Trip Screen Target')),
              ),
            ],
          ),
        ),
      );
    }

    testWidgets('renders loading state when myTripsProvider is loading', (
      tester,
    ) async {
      await tester.pumpApp(
        ProviderScope(
          overrides: [myTripsProvider.overrideWithValue(const AsyncLoading())],
          child: const HomeScreen(),
        ),
        authUserValue: AsyncData(mockUser),
        appUserValue: AsyncData(appUser),
      );

      expect(find.text('Loading your trips...'), findsOneWidget);
    });

    testWidgets('a. empty state shows "Create a Trip" and "Join with Code"', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildRouterHomeScreen(tripsValue: const AsyncData([])),
      );
      await tester.pumpAndSettle();

      expect(find.text('No trips yet'), findsOneWidget);
      expect(find.text('Create a Trip'), findsOneWidget);
      expect(find.text('Join with Code'), findsOneWidget);
    });

    testWidgets(
      'b. empty-state "Join with Code" opens existing Join Trip screen',
      (tester) async {
        await tester.pumpWidget(
          buildRouterHomeScreen(tripsValue: const AsyncData([])),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Join with Code'));
        await tester.pumpAndSettle();

        expect(find.text('Join Trip Screen Target'), findsOneWidget);
      },
    );

    testWidgets(
      'c. empty-state "Create a Trip" opens existing Create Trip screen',
      (tester) async {
        await tester.pumpWidget(
          buildRouterHomeScreen(tripsValue: const AsyncData([])),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Create a Trip'));
        await tester.pumpAndSettle();

        expect(find.text('Create Trip Screen Target'), findsOneWidget);
      },
    );

    testWidgets(
      'd. empty-state buttons are absent when trips exist, and absent during loading and error states',
      (tester) async {
        // Loading state
        await tester.pumpWidget(
          buildRouterHomeScreen(tripsValue: const AsyncLoading()),
        );
        await tester.pump();
        expect(find.text('Create a Trip'), findsNothing);
        expect(find.text('Join with Code'), findsNothing);

        // Error state
        await tester.pumpWidget(
          buildRouterHomeScreen(
            tripsValue: AsyncError('Network error', StackTrace.empty),
          ),
        );
        await tester.pump();
        expect(find.text('Create a Trip'), findsNothing);
        expect(find.text('Join with Code'), findsNothing);

        // Trips exist state
        final trip1 = Trip(
          id: 'trip-1',
          name: 'Summer in Goa',
          destination: 'Goa, India',
          startDate: DateTime.now().add(const Duration(days: 2)),
          endDate: DateTime.now().add(const Duration(days: 5)),
          currency: 'INR',
          organizerId: 'user-123',
          joinCode: 'ABC234',
          memberIds: ['user-123'],
          memberCount: 1,
          archived: false,
        );
        await tester.pumpWidget(
          buildRouterHomeScreen(tripsValue: AsyncData([trip1])),
        );
        await tester.pumpAndSettle();

        expect(find.text('Summer in Goa'), findsOneWidget);
        expect(find.text('Create a Trip'), findsNothing);
        expect(find.text('Join with Code'), findsNothing);
      },
    );

    testWidgets('e. FAB expands to show "Create Trip" and "Join Trip"', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildRouterHomeScreen(tripsValue: const AsyncData([])),
      );
      await tester.pumpAndSettle();

      // Action buttons not visible before expansion
      expect(find.byKey(const Key('fab_action_create_trip')), findsNothing);
      expect(find.byKey(const Key('fab_action_join_trip')), findsNothing);

      // Tap main FAB
      await tester.tap(find.byKey(const Key('home_fab_menu_button')));
      await tester.pumpAndSettle();

      // Action buttons visible after expansion
      expect(find.byKey(const Key('fab_action_create_trip')), findsOneWidget);
      expect(find.byKey(const Key('fab_action_join_trip')), findsOneWidget);
      expect(find.text('Create Trip'), findsOneWidget);
      expect(find.text('Join Trip'), findsOneWidget);
    });

    testWidgets(
      'f. FAB Create Trip opens create flow and menu closes; FAB Join Trip opens join flow',
      (tester) async {
        // Test Create Trip from FAB menu
        await tester.pumpWidget(
          buildRouterHomeScreen(tripsValue: const AsyncData([])),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('home_fab_menu_button')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('fab_action_create_trip')));
        await tester.pumpAndSettle();

        expect(find.text('Create Trip Screen Target'), findsOneWidget);

        // Test Join Trip from FAB menu
        await tester.pumpWidget(
          buildRouterHomeScreen(tripsValue: const AsyncData([])),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('home_fab_menu_button')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('fab_action_join_trip')));
        await tester.pumpAndSettle();

        expect(find.text('Join Trip Screen Target'), findsOneWidget);
      },
    );

    testWidgets('g. tapping outside the menu (scrim) closes it', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildRouterHomeScreen(tripsValue: const AsyncData([])),
      );
      await tester.pumpAndSettle();

      // Open menu
      await tester.tap(find.byKey(const Key('home_fab_menu_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fab_action_create_trip')), findsOneWidget);

      // Tap scrim outside
      await tester.tap(find.byKey(const Key('home_fab_scrim')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fab_action_create_trip')), findsNothing);
    });

    testWidgets('h. QR icon is no longer present in the Home app bar', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildRouterHomeScreen(tripsValue: const AsyncData([])),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.qr_code), findsNothing);
    });

    testWidgets('i. semantic labels and tooltips exist', (tester) async {
      await tester.pumpWidget(
        buildRouterHomeScreen(tripsValue: const AsyncData([])),
      );
      await tester.pumpAndSettle();

      // Tooltip/Semantics on main FAB when collapsed
      final collapsedFab = tester.widget<FloatingActionButton>(
        find.byKey(const Key('home_fab_menu_button')),
      );
      expect(collapsedFab.tooltip, equals('Trip actions'));

      // Expand menu
      await tester.tap(find.byKey(const Key('home_fab_menu_button')));
      await tester.pumpAndSettle();

      // Tooltip/Semantics on main FAB when expanded
      final expandedFab = tester.widget<FloatingActionButton>(
        find.byKey(const Key('home_fab_menu_button')),
      );
      expect(expandedFab.tooltip, equals('Close trip actions'));

      // Tooltips on small FAB actions
      final createSmallFab = tester.widget<FloatingActionButton>(
        find.byKey(const Key('fab_action_create_trip')),
      );
      expect(createSmallFab.tooltip, equals('Create Trip'));

      final joinSmallFab = tester.widget<FloatingActionButton>(
        find.byKey(const Key('fab_action_join_trip')),
      );
      expect(joinSmallFab.tooltip, equals('Join Trip'));
    });

    testWidgets('toggles theme when theme toggle button is tapped', (
      tester,
    ) async {
      await tester.pumpApp(
        ProviderScope(
          overrides: [myTripsProvider.overrideWithValue(const AsyncData([]))],
          child: const HomeScreen(),
        ),
        authUserValue: AsyncData(mockUser),
        appUserValue: AsyncData(appUser),
      );

      final themeToggleBtn = find.byKey(const Key('home_theme_toggle_button'));
      expect(themeToggleBtn, findsOneWidget);
      await tester.tap(themeToggleBtn);
      await tester.pumpAndSettle();
    });
  });
}
