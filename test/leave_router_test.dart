import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfound/app/router.dart';
import 'package:wayfound/features/auth/domain/app_user.dart';
import 'package:wayfound/features/expenses/data/expenses_providers.dart';
import 'package:wayfound/features/settlements/data/settlements_providers.dart';
import 'package:wayfound/features/trips/data/trip_repository.dart';
import 'package:wayfound/features/trips/data/trips_providers.dart';
import 'package:wayfound/features/trips/domain/member.dart';
import 'package:wayfound/features/trips/domain/trip.dart';
import 'package:wayfound/features/trips/presentation/home_screen.dart';
import 'package:wayfound/features/trips/presentation/trip_dashboard_screen.dart';

import 'helpers/pump_app.dart';

void main() {
  final now = DateTime(2026, 11, 1);
  const tripId = 'trip_leave_router';
  const organizerUid = 'org_user';
  const memberUid = 'mem_alice';

  final testTrip = Trip(
    id: tripId,
    name: 'Hawaii Trip',
    destination: 'Hawaii',
    startDate: now,
    endDate: now.add(const Duration(days: 5)),
    currency: 'USD',
    organizerId: organizerUid,
    joinCode: 'HAW123',
    memberIds: const [organizerUid, memberUid],
    memberCount: 2,
    archived: false,
    createdAt: now,
  );

  final orgMember = Member(
    uid: organizerUid,
    displayName: 'Organizer Dan',
    role: 'organizer',
    status: 'active',
    joinedAt: now,
  );

  final aliceMember = Member(
    uid: memberUid,
    displayName: 'Alice Member',
    role: 'member',
    status: 'active',
    joinedAt: now,
  );

  group('Leave Router Navigation Tests (G1)', () {
    testWidgets(
      'G1 Leave flow navigates back to Home upon successful leave, and positive control proves cancel does not redirect',
      (tester) async {
        final fakeFirestore = FakeFirebaseFirestore();
        final tripRepo = TripRepository(firestore: fakeFirestore);

        // Seed trip and member docs into fake firestore
        await fakeFirestore.collection('trips').doc(tripId).set({
          'name': testTrip.name,
          'destination': testTrip.destination,
          'startDate': testTrip.startDate,
          'endDate': testTrip.endDate,
          'currency': testTrip.currency,
          'organizerId': testTrip.organizerId,
          'joinCode': testTrip.joinCode,
          'memberIds': testTrip.memberIds,
          'memberCount': testTrip.memberCount,
          'archived': false,
          'createdAt': now,
        });

        await fakeFirestore
            .collection('trips')
            .doc(tripId)
            .collection('members')
            .doc(memberUid)
            .set({
              'uid': memberUid,
              'displayName': 'Alice Member',
              'role': 'member',
              'status': 'active',
              'joinedAt': now,
            });

        final mockAlice = MockUser(
          uid: memberUid,
          email: 'alice@test.com',
          displayName: 'Alice Member',
          photoURL: '',
        );

        final appUser = AppUser(
          uid: memberUid,
          email: 'alice@test.com',
          displayName: 'Alice Member',
          photoUrl: '',
        );

        final overrides = [
          tripRepositoryProvider.overrideWithValue(tripRepo),
          tripProvider(tripId).overrideWithValue(AsyncData(testTrip)),
          tripMembersProvider(tripId)
              .overrideWithValue(AsyncData([orgMember, aliceMember])),
          tripAllMembersProvider(tripId)
              .overrideWithValue(AsyncData([orgMember, aliceMember])),
          tripBalancesProvider(tripId)
              .overrideWithValue({organizerUid: 0, memberUid: 0}),
          totalTripSpentProvider(tripId).overrideWithValue(0),
          settlementsStreamProvider(tripId)
              .overrideWithValue(const AsyncData([])),
        ];

        await tester.pumpAppRouter(
          authUserValue: AsyncData(mockAlice),
          appUserValue: AsyncData(appUser),
          overrides: overrides,
        );
        await tester.pumpAndSettle();

        // Initially at /home
        expect(find.byType(HomeScreen), findsOneWidget);

        final element = tester.element(find.byType(MaterialApp));
        final container = ProviderScope.containerOf(element);
        final router = container.read(routerProvider);

        // Navigate to /trip/:id/members using router.push
        router.push('/trip/$tripId/members');
        await tester.pumpAndSettle();

        expect(find.byType(TripDashboardScreen), findsOneWidget);
        expect(find.text('Leave Trip'), findsOneWidget);

        // 1. Positive control: Cancel leave does not redirect (remains on trip dashboard)
        await tester.tap(find.text('Leave Trip'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Are you sure you want to leave this trip?'),
          findsOneWidget,
        );
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // Still on TripDashboardScreen, not redirected
        expect(find.byType(TripDashboardScreen), findsOneWidget);
        expect(find.byType(HomeScreen), findsNothing);

        // 2. Confirm leave -> leaves trip and navigates back to HomeScreen
        await tester.tap(find.text('Leave Trip'));
        await tester.pumpAndSettle();

        final leaveConfirmButton = find.widgetWithText(FilledButton, 'Leave');
        expect(leaveConfirmButton, findsOneWidget);
        await tester.tap(leaveConfirmButton);
        await tester.pumpAndSettle();

        // Successfully redirected back to HomeScreen
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.text('My Trips'), findsOneWidget);
        expect(find.text('You have left the trip.'), findsOneWidget);
      },
    );

    testWidgets(
      'G1b Leave flow navigates back to Home upon successful leave when arrived via router.go',
      (tester) async {
        final fakeFirestore = FakeFirebaseFirestore();
        final tripRepo = TripRepository(firestore: fakeFirestore);

        // Seed trip and member docs into fake firestore
        await fakeFirestore.collection('trips').doc(tripId).set({
          'name': testTrip.name,
          'destination': testTrip.destination,
          'startDate': testTrip.startDate,
          'endDate': testTrip.endDate,
          'currency': testTrip.currency,
          'organizerId': testTrip.organizerId,
          'joinCode': testTrip.joinCode,
          'memberIds': testTrip.memberIds,
          'memberCount': testTrip.memberCount,
          'archived': false,
          'createdAt': now,
        });

        await fakeFirestore
            .collection('trips')
            .doc(tripId)
            .collection('members')
            .doc(memberUid)
            .set({
              'uid': memberUid,
              'displayName': 'Alice Member',
              'role': 'member',
              'status': 'active',
              'joinedAt': now,
            });

        final mockAlice = MockUser(
          uid: memberUid,
          email: 'alice@test.com',
          displayName: 'Alice Member',
          photoURL: '',
        );

        final appUser = AppUser(
          uid: memberUid,
          email: 'alice@test.com',
          displayName: 'Alice Member',
          photoUrl: '',
        );

        final overrides = [
          tripRepositoryProvider.overrideWithValue(tripRepo),
          tripProvider(tripId).overrideWithValue(AsyncData(testTrip)),
          tripMembersProvider(tripId)
              .overrideWithValue(AsyncData([orgMember, aliceMember])),
          tripAllMembersProvider(tripId)
              .overrideWithValue(AsyncData([orgMember, aliceMember])),
          tripBalancesProvider(tripId)
              .overrideWithValue({organizerUid: 0, memberUid: 0}),
          totalTripSpentProvider(tripId).overrideWithValue(0),
          settlementsStreamProvider(tripId)
              .overrideWithValue(const AsyncData([])),
        ];

        await tester.pumpAppRouter(
          authUserValue: AsyncData(mockAlice),
          appUserValue: AsyncData(appUser),
          overrides: overrides,
        );
        await tester.pumpAndSettle();

        final element = tester.element(find.byType(MaterialApp));
        final container = ProviderScope.containerOf(element);
        final router = container.read(routerProvider);

        // Navigate to /trip/:id/members using router.go (replaces the stack)
        router.go('/trip/$tripId/members');
        await tester.pumpAndSettle();

        expect(find.byType(TripDashboardScreen), findsOneWidget);
        expect(find.text('Leave Trip'), findsOneWidget);

        // Confirm leave -> leaves trip and navigates back to HomeScreen
        await tester.tap(find.text('Leave Trip'));
        await tester.pumpAndSettle();

        final leaveConfirmButton = find.widgetWithText(FilledButton, 'Leave');
        expect(leaveConfirmButton, findsOneWidget);
        await tester.tap(leaveConfirmButton);
        await tester.pumpAndSettle();

        // Successfully redirected back to HomeScreen
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.text('My Trips'), findsOneWidget);
        expect(find.text('You have left the trip.'), findsOneWidget);
      },
    );
  });
}
