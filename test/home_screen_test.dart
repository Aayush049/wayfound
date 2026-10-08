import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

    testWidgets('renders empty state when user has no trips', (tester) async {
      await tester.pumpApp(
        ProviderScope(
          overrides: [myTripsProvider.overrideWithValue(const AsyncData([]))],
          child: const HomeScreen(),
        ),
        authUserValue: AsyncData(mockUser),
        appUserValue: AsyncData(appUser),
      );

      expect(find.text('No trips yet'), findsOneWidget);
      expect(find.text('Create a Trip'), findsOneWidget);
      expect(find.byTooltip('Join with code'), findsOneWidget);
    });

    testWidgets('renders trip cards when trips exist', (tester) async {
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

      await tester.pumpApp(
        ProviderScope(
          overrides: [
            myTripsProvider.overrideWithValue(AsyncData([trip1])),
          ],
          child: const HomeScreen(),
        ),
        authUserValue: AsyncData(mockUser),
        appUserValue: AsyncData(appUser),
      );

      expect(find.text('Summer in Goa'), findsOneWidget);
      expect(find.text('Goa, India'), findsOneWidget);
      expect(find.text('Create Trip'), findsOneWidget);
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
