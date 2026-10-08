import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfound/features/auth/domain/app_user.dart';
import 'package:wayfound/features/trips/data/trips_providers.dart';
import 'package:wayfound/features/trips/domain/member.dart';
import 'package:wayfound/features/trips/domain/trip.dart';
import 'package:wayfound/features/trips/presentation/trip_dashboard_screen.dart';

import 'helpers/pump_app.dart';

void main() {
  group('TripDashboardScreen', () {
    final mockUser = MockUser(uid: 'user-organizer', email: 'org@example.com');
    final appUser = AppUser(
      uid: 'user-organizer',
      email: 'org@example.com',
      displayName: 'Alice Organizer',
    );

    final trip = Trip(
      id: 'trip-123',
      name: 'Goa Adventure',
      destination: 'Goa, India',
      startDate: DateTime(2026, 8, 1),
      endDate: DateTime(2026, 8, 5),
      currency: 'INR',
      organizerId: 'user-organizer',
      joinCode: 'ABC234',
      memberIds: ['user-organizer'],
      memberCount: 1,
      archived: false,
    );

    final organizer = Member(
      uid: 'user-organizer',
      displayName: 'Alice Organizer',
      role: 'organizer',
      status: 'active',
      joinedAt: DateTime(2026, 8, 1),
    );

    testWidgets('shows loading indicator when tripProvider is loading', (
      tester,
    ) async {
      await tester.pumpApp(
        ProviderScope(
          overrides: [
            tripProvider('trip-123').overrideWithValue(const AsyncLoading()),
          ],
          child: const TripDashboardScreen(tripId: 'trip-123'),
        ),
        authUserValue: AsyncData(mockUser),
        appUserValue: AsyncData(appUser),
      );

      expect(find.text('Loading trip details...'), findsOneWidget);
    });

    testWidgets('shows no access view when user is not a member of trip', (
      tester,
    ) async {
      final nonMemberUser = MockUser(
        uid: 'user-outsider',
        email: 'out@example.com',
      );

      await tester.pumpApp(
        ProviderScope(
          overrides: [
            tripProvider('trip-123').overrideWithValue(AsyncData(trip)),
          ],
          child: const TripDashboardScreen(tripId: 'trip-123'),
        ),
        authUserValue: AsyncData(nonMemberUser),
      );

      expect(find.text('No access to trip'), findsOneWidget);
      expect(
        find.text('This trip does not exist or you are not a member of it.'),
        findsOneWidget,
      );
    });

    testWidgets('renders trip title, destination, and tabs for active member', (
      tester,
    ) async {
      await tester.pumpApp(
        ProviderScope(
          overrides: [
            tripProvider('trip-123').overrideWithValue(AsyncData(trip)),
            tripMembersProvider('trip-123')
                .overrideWithValue(AsyncData([organizer])),
          ],
          child: const TripDashboardScreen(
            tripId: 'trip-123',
            activeTab: 'members',
          ),
        ),
        authUserValue: AsyncData(mockUser),
        appUserValue: AsyncData(appUser),
      );

      expect(find.text('Goa Adventure'), findsOneWidget);
      expect(find.text('Goa, India'), findsOneWidget);

      expect(find.text('Suggestions'), findsOneWidget);
      expect(find.text('Itinerary'), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('Members'), findsNWidgets(2));

      // MembersTab is active
      expect(find.text('Trip Invite Code'), findsOneWidget);
    });
  });
}
