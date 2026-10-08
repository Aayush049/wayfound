import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfound/features/auth/domain/app_user.dart';
import 'package:wayfound/features/trips/data/trip_repository.dart';
import 'package:wayfound/features/trips/data/trips_providers.dart';
import 'package:wayfound/features/trips/presentation/join_trip_screen.dart';

import 'helpers/pump_app.dart';

void main() {
  group('JoinTripScreen', () {
    late FakeFirebaseFirestore firestore;
    late TripRepository repository;
    final mockUser = MockUser(uid: 'user-joiner', email: 'joiner@example.com');
    final appUser = AppUser(
      uid: 'user-joiner',
      email: 'joiner@example.com',
      displayName: 'Joiner User',
    );

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = TripRepository(firestore: firestore);
    });

    testWidgets('shows error when invalid join code format is searched', (
      tester,
    ) async {
      await tester.pumpApp(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(repository),
            myTripsProvider.overrideWithValue(const AsyncData([])),
          ],
          child: const JoinTripScreen(),
        ),
        authUserValue: AsyncData(mockUser),
        appUserValue: AsyncData(appUser),
      );

      await tester.enterText(find.byType(TextFormField), '1234'); // invalid
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Invalid join code format. Must be 6 characters (letters and numbers).',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows trip preview when valid join code is searched', (
      tester,
    ) async {
      final createResult = await repository.createTrip(
        name: 'Himalayan Trek',
        destination: 'Manali, India',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 10),
        currency: 'INR',
        userUid: 'user-organizer',
        displayName: 'Organizer Name',
      );

      await tester.pumpApp(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(repository),
            myTripsProvider.overrideWithValue(const AsyncData([])),
          ],
          child: const JoinTripScreen(),
        ),
        authUserValue: AsyncData(mockUser),
        appUserValue: AsyncData(appUser),
      );

      await tester.enterText(find.byType(TextFormField), createResult.joinCode);
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      expect(find.text('Trip Preview'), findsOneWidget);
      expect(find.text('Himalayan Trek'), findsOneWidget);
      expect(find.text('Manali, India'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Join Trip'), findsOneWidget);
    });

    testWidgets('joins trip successfully when Join Trip button is tapped', (
      tester,
    ) async {
      final createResult = await repository.createTrip(
        name: 'Himalayan Trek',
        destination: 'Manali, India',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 10),
        currency: 'INR',
        userUid: 'user-organizer',
        displayName: 'Organizer Name',
      );

      await tester.pumpApp(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(repository),
            myTripsProvider.overrideWithValue(const AsyncData([])),
          ],
          child: const JoinTripScreen(),
        ),
        authUserValue: AsyncData(mockUser),
        appUserValue: AsyncData(appUser),
      );

      await tester.enterText(find.byType(TextFormField), createResult.joinCode);
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Join Trip'));
      await tester.pumpAndSettle();

      final tripDoc = await firestore
          .collection('trips')
          .doc(createResult.tripId)
          .get();
      final memberIds = List<String>.from(tripDoc.data()?['memberIds']);
      expect(memberIds, contains('user-joiner'));
      expect(tripDoc.data()?['memberCount'], equals(2));
    });
  });
}
