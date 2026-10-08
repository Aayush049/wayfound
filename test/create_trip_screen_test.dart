import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfound/features/auth/domain/app_user.dart';
import 'package:wayfound/features/trips/data/trip_repository.dart';
import 'package:wayfound/features/trips/data/trips_providers.dart';
import 'package:wayfound/features/trips/presentation/create_trip_screen.dart';

import 'helpers/pump_app.dart';

void main() {
  group('CreateTripScreen', () {
    late FakeFirebaseFirestore firestore;
    late TripRepository repository;
    final mockUser = MockUser(uid: 'user-123', email: 'test@example.com');
    final appUser = AppUser(
      uid: 'user-123',
      email: 'test@example.com',
      displayName: 'Test Organizer',
    );

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = TripRepository(firestore: firestore);
    });

    testWidgets('renders all form fields and submit button', (tester) async {
      await tester.pumpApp(
        ProviderScope(
          overrides: [tripRepositoryProvider.overrideWithValue(repository)],
          child: const CreateTripScreen(),
        ),
        authUserValue: AsyncData(mockUser),
        appUserValue: AsyncData(appUser),
      );

      expect(find.text('Create New Trip'), findsOneWidget);
      expect(find.text('Trip Name *'), findsOneWidget);
      expect(find.text('Destination *'), findsOneWidget);
      expect(find.text('Trip Dates *'), findsOneWidget);
      expect(find.text('Currency *'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Create Trip'), findsOneWidget);
    });

    testWidgets('shows validation errors when fields are empty', (
      tester,
    ) async {
      await tester.pumpApp(
        ProviderScope(
          overrides: [tripRepositoryProvider.overrideWithValue(repository)],
          child: const CreateTripScreen(),
        ),
        authUserValue: AsyncData(mockUser),
        appUserValue: AsyncData(appUser),
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Create Trip'));
      await tester.pumpAndSettle();

      expect(find.text('Trip name is required'), findsOneWidget);
      expect(find.text('Destination is required'), findsOneWidget);
    });

    testWidgets('successfully submits valid trip creation form', (
      tester,
    ) async {
      await tester.pumpApp(
        ProviderScope(
          overrides: [tripRepositoryProvider.overrideWithValue(repository)],
          child: const CreateTripScreen(),
        ),
        authUserValue: AsyncData(mockUser),
        appUserValue: AsyncData(appUser),
      );

      // Fill trip name
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Trip Name *'),
        'Goa Beach Vacation',
      );

      // Fill destination
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Destination *'),
        'Goa, India',
      );

      // Select dates using date picker
      await tester.tap(find.text('Trip Dates *'), warnIfMissed: false);
      await tester.pumpAndSettle();
      final saveBtn = find.text('Save');
      if (saveBtn.evaluate().isNotEmpty) {
        await tester.tap(saveBtn);
      } else {
        await tester.tap(find.text('OK'));
      }
      await tester.pumpAndSettle();

      // Select Currency
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('INR').last);
      await tester.pumpAndSettle();

      // Submit form
      await tester.tap(find.widgetWithText(FilledButton, 'Create Trip'));
      await tester.pumpAndSettle();

      // Verify trip document in fake firestore
      final tripsDocs = await firestore.collection('trips').get();
      expect(tripsDocs.docs.length, equals(1));
      expect(tripsDocs.docs.first.data()['name'], equals('Goa Beach Vacation'));
      expect(tripsDocs.docs.first.data()['currency'], equals('INR'));
    });
  });
}
