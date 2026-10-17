import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfound/app/router.dart';
import 'package:wayfound/features/suggestions/data/suggestion_repository.dart';
import 'package:wayfound/features/suggestions/data/suggestions_providers.dart';
import 'package:wayfound/features/suggestions/domain/suggestion.dart';
import 'package:wayfound/features/suggestions/presentation/add_edit_suggestion_screen.dart';
import 'package:wayfound/features/trips/data/trips_providers.dart';
import 'package:wayfound/features/trips/domain/member.dart';
import 'package:wayfound/features/trips/domain/trip.dart';

import 'helpers/pump_app.dart';

void main() {
  late MockUser mockUser;
  late FakeFirebaseFirestore fakeFirestore;
  late SuggestionRepository repository;

  const tripId = 'trip_nav_test';
  const userUid = 'user_nav_1';

  final testTrip = Trip(
    id: tripId,
    name: 'Goa Trip',
    destination: 'Goa',
    startDate: DateTime(2026, 11, 1),
    endDate: DateTime(2026, 11, 5),
    currency: 'INR',
    organizerId: userUid,
    joinCode: 'GOA123',
    memberIds: const [userUid],
    memberCount: 1,
    archived: false,
    createdAt: DateTime(2026, 10, 8),
  );

  final member = Member(
    uid: userUid,
    displayName: 'Test User',
    role: 'organizer',
    status: 'active',
    joinedAt: DateTime(2026, 10, 8),
  );

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repository = SuggestionRepository(firestore: fakeFirestore);
    mockUser = MockUser(
      uid: userUid,
      email: 'test@example.com',
      displayName: 'Test User',
      photoURL: '',
    );
  });

  group('Add & Edit Suggestion Navigation Tests (Real Router)', () {
    testWidgets('Tapping floating Add button opens AddEditSuggestionScreen', (
      tester,
    ) async {
      final overrides = [
        tripProvider(tripId).overrideWithValue(AsyncData(testTrip)),
        suggestionsStreamProvider(tripId).overrideWithValue(
          AsyncData([
            Suggestion(
              id: 's1',
              tripId: tripId,
              title: 'Visit Fort',
              note: 'Fun',
              estimatedCost: 100,
              category: 'sightseeing',
              authorId: userUid,
              upCount: 0,
              downCount: 0,
              status: 'pending',
              createdAt: DateTime(2026, 10, 8),
            ),
          ]),
        ),
        tripMembersProvider(tripId).overrideWithValue(AsyncData([member])),
      ];

      await tester.pumpAppRouter(
        authUserValue: AsyncData(mockUser),
        overrides: overrides,
      );
      await tester.pumpAndSettle();

      final Element context = tester.element(find.byType(MaterialApp));
      final container = ProviderScope.containerOf(context);
      final router = container.read(routerProvider);

      router.go('/trip/$tripId/suggestions');
      await tester.pumpAndSettle();

      expect(find.text('Visit Fort'), findsOneWidget);

      final fab = find.byType(FloatingActionButton);
      expect(fab, findsOneWidget);

      await tester.tap(fab);
      await tester.pumpAndSettle();

      expect(find.byType(AddEditSuggestionScreen), findsOneWidget);
    });

    testWidgets('Tapping empty-state action opens AddEditSuggestionScreen', (
      tester,
    ) async {
      final overrides = [
        tripProvider(tripId).overrideWithValue(AsyncData(testTrip)),
        suggestionsStreamProvider(tripId)
            .overrideWithValue(const AsyncData([])),
        tripMembersProvider(tripId).overrideWithValue(AsyncData([member])),
      ];

      await tester.pumpAppRouter(
        authUserValue: AsyncData(mockUser),
        overrides: overrides,
      );
      await tester.pumpAndSettle();

      final Element context = tester.element(find.byType(MaterialApp));
      final container = ProviderScope.containerOf(context);
      final router = container.read(routerProvider);

      router.go('/trip/$tripId/suggestions');
      await tester.pumpAndSettle();

      expect(find.text('No suggestions yet'), findsOneWidget);

      final emptyActionButton = find.widgetWithText(
        FilledButton,
        'Add Suggestion',
      );
      expect(emptyActionButton, findsOneWidget);

      await tester.tap(emptyActionButton);
      await tester.pumpAndSettle();

      expect(find.byType(AddEditSuggestionScreen), findsOneWidget);
    });

    testWidgets(
      'Saving returns to Suggestions tab and new suggestion is visible in list',
      (tester) async {
        final overrides = [
          suggestionRepositoryProvider.overrideWithValue(repository),
          tripProvider(tripId).overrideWithValue(AsyncData(testTrip)),
          tripMembersProvider(tripId).overrideWithValue(AsyncData([member])),
        ];

        await tester.pumpAppRouter(
          authUserValue: AsyncData(mockUser),
          overrides: overrides,
        );
        await tester.pumpAndSettle();

        final Element context = tester.element(find.byType(MaterialApp));
        final container = ProviderScope.containerOf(context);
        final router = container.read(routerProvider);

        router.go('/trip/$tripId/suggestions');
        await tester.pumpAndSettle();

        final emptyActionButton = find.widgetWithText(
          FilledButton,
          'Add Suggestion',
        );
        await tester.tap(emptyActionButton);
        await tester.pumpAndSettle();

        expect(find.byType(AddEditSuggestionScreen), findsOneWidget);

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Title *'),
          'Scuba Diving',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Note (Optional)'),
          'At Calangute',
        );

        final submitButton = find.widgetWithText(
          FilledButton,
          'Add Suggestion',
        );
        await tester.tap(submitButton);
        await tester.pumpAndSettle();

        expect(find.byType(AddEditSuggestionScreen), findsNothing);
        expect(find.text('Scuba Diving'), findsOneWidget);
      },
    );

    testWidgets(
      'Back button returns to Suggestions tab with dashboard still mounted',
      (tester) async {
        final overrides = [
          tripProvider(tripId).overrideWithValue(AsyncData(testTrip)),
          suggestionsStreamProvider(tripId)
              .overrideWithValue(const AsyncData([])),
          tripMembersProvider(tripId).overrideWithValue(AsyncData([member])),
        ];

        await tester.pumpAppRouter(
          authUserValue: AsyncData(mockUser),
          overrides: overrides,
        );
        await tester.pumpAndSettle();

        final Element context = tester.element(find.byType(MaterialApp));
        final container = ProviderScope.containerOf(context);
        final router = container.read(routerProvider);

        router.go('/trip/$tripId/suggestions');
        await tester.pumpAndSettle();

        final fab = find.byType(FloatingActionButton);
        await tester.tap(fab);
        await tester.pumpAndSettle();

        expect(find.byType(AddEditSuggestionScreen), findsOneWidget);

        final backButton = find.byIcon(Icons.arrow_back);
        await tester.tap(backButton);
        await tester.pumpAndSettle();

        expect(find.byType(AddEditSuggestionScreen), findsNothing);
        expect(find.text('No suggestions yet'), findsOneWidget);
        expect(find.text('Goa Trip'), findsOneWidget);
      },
    );

    testWidgets(
      'Overflow Edit action opens Edit form with prefilled data and returns correctly',
      (tester) async {
        await repository.createSuggestion(
          tripId: tripId,
          title: 'Sunset Cruise',
          note: 'Mandovi River',
          estimatedCost: 500,
          category: 'sightseeing',
          authorId: userUid,
        );

        final overrides = [
          suggestionRepositoryProvider.overrideWithValue(repository),
          tripProvider(tripId).overrideWithValue(AsyncData(testTrip)),
          tripMembersProvider(tripId).overrideWithValue(AsyncData([member])),
        ];

        await tester.pumpAppRouter(
          authUserValue: AsyncData(mockUser),
          overrides: overrides,
        );
        await tester.pumpAndSettle();

        final Element context = tester.element(find.byType(MaterialApp));
        final container = ProviderScope.containerOf(context);
        final router = container.read(routerProvider);

        router.go('/trip/$tripId/suggestions');
        await tester.pumpAndSettle();

        expect(find.text('Sunset Cruise'), findsOneWidget);

        final overflowButton = find.byIcon(Icons.more_vert).first;
        await tester.tap(overflowButton);
        await tester.pumpAndSettle();

        final editOption = find.text('Edit');
        await tester.tap(editOption);
        await tester.pumpAndSettle();

        expect(find.byType(AddEditSuggestionScreen), findsOneWidget);
        expect(find.text('Edit Suggestion'), findsOneWidget);
        expect(find.text('Sunset Cruise'), findsOneWidget);

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Title *'),
          'Luxury Sunset Cruise',
        );

        final saveButton = find.widgetWithText(FilledButton, 'Save Changes');
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        expect(find.byType(AddEditSuggestionScreen), findsNothing);
        expect(find.text('Luxury Sunset Cruise'), findsOneWidget);
      },
    );

    testWidgets('Members and Itinerary tabs still switch correctly', (
      tester,
    ) async {
      final overrides = [
        tripProvider(tripId).overrideWithValue(AsyncData(testTrip)),
        suggestionsStreamProvider(tripId)
            .overrideWithValue(const AsyncData([])),
        tripMembersProvider(tripId).overrideWithValue(AsyncData([member])),
      ];

      await tester.pumpAppRouter(
        authUserValue: AsyncData(mockUser),
        overrides: overrides,
      );
      await tester.pumpAndSettle();

      final Element context = tester.element(find.byType(MaterialApp));
      final container = ProviderScope.containerOf(context);
      final router = container.read(routerProvider);

      router.go('/trip/$tripId/suggestions');
      await tester.pumpAndSettle();

      expect(find.text('No suggestions yet'), findsOneWidget);

      final itineraryTab = find.text('Itinerary');
      await tester.tap(itineraryTab);
      await tester.pumpAndSettle();

      expect(find.text('No itinerary items scheduled yet'), findsOneWidget);
      expect(
        router.routeInformationProvider.value.uri.path,
        '/trip/$tripId/itinerary',
      );

      final membersTab = find.text('Members');
      await tester.tap(membersTab);
      await tester.pumpAndSettle();

      expect(find.text('Trip Invite Code'), findsOneWidget);
      expect(
        router.routeInformationProvider.value.uri.path,
        '/trip/$tripId/members',
      );
    });

    testWidgets('Tab listener does not navigate when a form is pushed on top', (
      tester,
    ) async {
      final overrides = [
        tripProvider(tripId).overrideWithValue(AsyncData(testTrip)),
        suggestionsStreamProvider(tripId)
            .overrideWithValue(const AsyncData([])),
        tripMembersProvider(tripId).overrideWithValue(AsyncData([member])),
      ];

      await tester.pumpAppRouter(
        authUserValue: AsyncData(mockUser),
        overrides: overrides,
      );
      await tester.pumpAndSettle();

      final Element context = tester.element(find.byType(MaterialApp));
      final container = ProviderScope.containerOf(context);
      final router = container.read(routerProvider);

      router.go('/trip/$tripId/suggestions');
      await tester.pumpAndSettle();

      final fab = find.byType(FloatingActionButton);
      await tester.tap(fab);
      await tester.pumpAndSettle();

      expect(find.byType(AddEditSuggestionScreen), findsOneWidget);

      // Ensure AddEditSuggestionScreen remains mounted and visible on top
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(AddEditSuggestionScreen), findsOneWidget);
    });
  });
}
