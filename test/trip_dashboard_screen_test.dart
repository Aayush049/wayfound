import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfound/features/auth/domain/app_user.dart';
import 'package:wayfound/features/trips/data/trip_repository.dart';
import 'package:wayfound/features/trips/data/trips_providers.dart';
import 'package:wayfound/features/trips/domain/member.dart';
import 'package:wayfound/features/trips/domain/trip.dart';
import 'package:wayfound/features/trips/presentation/trip_card.dart';
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

    Trip createTestTrip({
      String id = 'trip-123',
      String name = 'Goa Adventure',
      String destination = 'Goa, India',
      DateTime? startDate,
      DateTime? endDate,
      String currency = 'INR',
      String organizerId = 'user-organizer',
      String joinCode = 'ABC234',
      List<String>? memberIds,
      int memberCount = 1,
      bool archived = false,
    }) {
      return Trip(
        id: id,
        name: name,
        destination: destination,
        startDate: startDate ?? DateTime(2026, 8, 1),
        endDate: endDate ?? DateTime(2026, 8, 5),
        currency: currency,
        organizerId: organizerId,
        joinCode: joinCode,
        memberIds: memberIds ?? [organizerId],
        memberCount: memberCount,
        archived: archived,
      );
    }

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

    testWidgets('organizer sees archive trip option on active trip', (
      tester,
    ) async {
      await tester.pumpApp(
        ProviderScope(
          overrides: [
            tripProvider('trip-123').overrideWithValue(AsyncData(trip)),
            tripMembersProvider('trip-123')
                .overrideWithValue(AsyncData([organizer])),
          ],
          child: const TripDashboardScreen(tripId: 'trip-123'),
        ),
        authUserValue: AsyncData(mockUser),
        appUserValue: AsyncData(appUser),
      );

      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Archive trip'), findsOneWidget);
    });

    testWidgets('plain member does not see archive trip option', (
      tester,
    ) async {
      final memberUser = MockUser(
        uid: 'user-member',
        email: 'member@example.com',
      );
      final memberAppUser = AppUser(
        uid: 'user-member',
        email: 'member@example.com',
        displayName: 'Bob Member',
      );
      final memberTrip = createTestTrip(
        memberIds: ['user-organizer', 'user-member'],
        memberCount: 2,
      );

      await tester.pumpApp(
        ProviderScope(
          overrides: [
            tripProvider('trip-123').overrideWithValue(AsyncData(memberTrip)),
            tripMembersProvider('trip-123')
                .overrideWithValue(AsyncData([organizer])),
          ],
          child: const TripDashboardScreen(tripId: 'trip-123'),
        ),
        authUserValue: AsyncData(memberUser),
        appUserValue: AsyncData(memberAppUser),
      );

      expect(find.byIcon(Icons.more_vert), findsNothing);
      expect(find.text('Archive trip'), findsNothing);
    });

    testWidgets(
      'archived trip does not show archive trip option and displays persistent indicators',
      (tester) async {
        final archivedTrip = createTestTrip(archived: true);

        await tester.pumpApp(
          ProviderScope(
            overrides: [
              tripProvider('trip-123')
                  .overrideWithValue(AsyncData(archivedTrip)),
              tripMembersProvider('trip-123')
                  .overrideWithValue(AsyncData([organizer])),
            ],
            child: const TripDashboardScreen(tripId: 'trip-123'),
          ),
          authUserValue: AsyncData(mockUser),
          appUserValue: AsyncData(appUser),
        );

        // Action menu hidden
        expect(find.byIcon(Icons.more_vert), findsNothing);
        expect(find.text('Archive trip'), findsNothing);

        // Persistent chip and banner visible
        expect(find.text('Archived'), findsWidgets);
        expect(
          find.text('This trip is archived and read-only.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('dialog Cancel changes nothing', (tester) async {
      final fakeFirestore = FakeFirebaseFirestore();
      await fakeFirestore.collection('trips').doc('trip-123').set({
        'name': 'Goa Adventure',
        'destination': 'Goa, India',
        'startDate': DateTime(2026, 8, 1),
        'endDate': DateTime(2026, 8, 5),
        'currency': 'INR',
        'organizerId': 'user-organizer',
        'joinCode': 'ABC234',
        'memberIds': ['user-organizer'],
        'memberCount': 1,
        'archived': false,
      });

      final repo = TripRepository(firestore: fakeFirestore);

      await tester.pumpApp(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(repo),
            tripProvider('trip-123').overrideWithValue(AsyncData(trip)),
            tripMembersProvider('trip-123')
                .overrideWithValue(AsyncData([organizer])),
          ],
          child: const TripDashboardScreen(tripId: 'trip-123'),
        ),
        authUserValue: AsyncData(mockUser),
        appUserValue: AsyncData(appUser),
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Archive trip'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'The trip becomes read-only for everyone and this cannot be undone in this version.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      final doc = await fakeFirestore.collection('trips').doc('trip-123').get();
      expect(doc.data()?['archived'], isFalse);
      expect(find.text('Trip archived.'), findsNothing);
    });

    testWidgets(
      'dialog Confirm calls repository, sets archived true in Firestore, and shows snackbar',
      (tester) async {
        final fakeFirestore = FakeFirebaseFirestore();
        await fakeFirestore.collection('trips').doc('trip-123').set({
          'name': 'Goa Adventure',
          'destination': 'Goa, India',
          'startDate': DateTime(2026, 8, 1),
          'endDate': DateTime(2026, 8, 5),
          'currency': 'INR',
          'organizerId': 'user-organizer',
          'joinCode': 'ABC234',
          'memberIds': ['user-organizer'],
          'memberCount': 1,
          'archived': false,
        });

        final repo = TripRepository(firestore: fakeFirestore);

        await tester.pumpApp(
          ProviderScope(
            overrides: [
              tripRepositoryProvider.overrideWithValue(repo),
              tripProvider('trip-123').overrideWithValue(AsyncData(trip)),
              tripMembersProvider('trip-123')
                  .overrideWithValue(AsyncData([organizer])),
            ],
            child: const TripDashboardScreen(tripId: 'trip-123'),
          ),
          authUserValue: AsyncData(mockUser),
          appUserValue: AsyncData(appUser),
        );

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Archive trip'));
        await tester.pumpAndSettle();

        // Tap Confirm (filled button labeled 'Archive trip')
        final archiveButtons = find.widgetWithText(
          FilledButton,
          'Archive trip',
        );
        await tester.tap(archiveButtons);
        await tester.pumpAndSettle();

        expect(find.text('Trip archived.'), findsOneWidget);

        final doc = await fakeFirestore
            .collection('trips')
            .doc('trip-123')
            .get();
        expect(doc.data()?['archived'], isTrue);
      },
    );

    testWidgets('error path shows readable message on permission-denied', (
      tester,
    ) async {
      final repo = _ThrowingPermissionDeniedTripRepo();

      await tester.pumpApp(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(repo),
            tripProvider('trip-123').overrideWithValue(AsyncData(trip)),
            tripMembersProvider('trip-123')
                .overrideWithValue(AsyncData([organizer])),
          ],
          child: const TripDashboardScreen(tripId: 'trip-123'),
        ),
        authUserValue: AsyncData(mockUser),
        appUserValue: AsyncData(appUser),
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Archive trip'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Archive trip'));
      await tester.pumpAndSettle();

      expect(find.text("You can't archive this trip."), findsOneWidget);
    });

    testWidgets('error path shows readable message on generic error', (
      tester,
    ) async {
      final repo = _ThrowingGenericTripRepo();

      await tester.pumpApp(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(repo),
            tripProvider('trip-123').overrideWithValue(AsyncData(trip)),
            tripMembersProvider('trip-123')
                .overrideWithValue(AsyncData([organizer])),
          ],
          child: const TripDashboardScreen(tripId: 'trip-123'),
        ),
        authUserValue: AsyncData(mockUser),
        appUserValue: AsyncData(appUser),
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Archive trip'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Archive trip'));
      await tester.pumpAndSettle();

      expect(
        find.text("Couldn't archive the trip. Please try again."),
        findsOneWidget,
      );
    });

    testWidgets(
      'TripCard shows Archived chip when trip is archived and hides when active',
      (tester) async {
        await tester.pumpApp(
          TripCard(trip: trip, currentUid: 'user-organizer', onTap: () {}),
          authUserValue: AsyncData(mockUser),
          appUserValue: AsyncData(appUser),
        );

        expect(find.text('Archived'), findsNothing);

        await tester.pumpApp(
          TripCard(
            trip: createTestTrip(archived: true),
            currentUid: 'user-organizer',
            onTap: () {},
          ),
          authUserValue: AsyncData(mockUser),
          appUserValue: AsyncData(appUser),
        );

        expect(find.text('Archived'), findsOneWidget);
      },
    );
  });
}

class _ThrowingPermissionDeniedTripRepo extends TripRepository {
  _ThrowingPermissionDeniedTripRepo()
    : super(firestore: FakeFirebaseFirestore());

  @override
  Future<void> archiveTrip(String tripId) async {
    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
      message: 'Missing or insufficient permissions.',
    );
  }
}

class _ThrowingGenericTripRepo extends TripRepository {
  _ThrowingGenericTripRepo() : super(firestore: FakeFirebaseFirestore());

  @override
  Future<void> archiveTrip(String tripId) async {
    throw Exception('Connection failed');
  }
}
