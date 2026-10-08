import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfound/app/theme/app_theme.dart';
import 'package:wayfound/features/auth/data/auth_provider.dart';
import 'package:wayfound/features/suggestions/data/suggestion_repository.dart';
import 'package:wayfound/features/suggestions/data/suggestions_providers.dart';
import 'package:wayfound/features/suggestions/domain/suggestion.dart';
import 'package:wayfound/features/suggestions/presentation/add_edit_suggestion_screen.dart';
import 'package:wayfound/features/suggestions/presentation/suggestion_card.dart';
import 'package:wayfound/features/trips/data/trips_providers.dart';
import 'package:wayfound/features/trips/domain/trip.dart';

import 'helpers/pump_app.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockUser mockUser;
  late SuggestionRepository repository;

  const tripId = 'trip_ui_test';
  const authorUid = 'user_author';
  const memberUid = 'user_member';

  final testTrip = Trip(
    id: tripId,
    name: 'Goa Trip',
    destination: 'Goa',
    startDate: DateTime(2026, 11, 1),
    endDate: DateTime(2026, 11, 5),
    currency: 'INR',
    organizerId: authorUid,
    joinCode: 'GOA123',
    memberIds: const [authorUid],
    memberCount: 1,
    archived: false,
    createdAt: DateTime(2026, 10, 8),
  );

  final suggestion = Suggestion(
    id: 's1',
    tripId: tripId,
    title: 'Visit Fort Aguada',
    note: 'Great sunset spot',
    estimatedCost: 500,
    category: 'sightseeing',
    authorId: authorUid,
    upCount: 2,
    downCount: 0,
    status: 'pending',
    createdAt: DateTime(2026, 10, 8, 12, 0),
  );

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockUser = MockUser(
      uid: authorUid,
      email: 'author@example.com',
      displayName: 'Alice Author',
    );
    repository = SuggestionRepository(firestore: fakeFirestore);
  });

  group('Suggestions UI Widget Tests', () {
    testWidgets(
      'SuggestionsTab renders empty state when suggestions list is empty',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              suggestionRepositoryProvider.overrideWithValue(repository),
              suggestionsStreamProvider(tripId)
                  .overrideWithValue(const AsyncData([])),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const Scaffold(
                body: Center(child: Text('No suggestions yet')),
              ),
            ),
          ),
        );

        expect(find.text('No suggestions yet'), findsOneWidget);
      },
    );

    testWidgets(
      'SuggestionCard renders title, category, cost, and vote controls',
      (tester) async {
        await tester.pumpApp(
          Scaffold(
            body: SuggestionCard(
              suggestion: suggestion,
              currency: 'INR',
              currentUserId: authorUid,
              isOrganizer: true,
              members: const [],
            ),
          ),
          authUserValue: AsyncData(mockUser),
        );

        expect(find.text('Visit Fort Aguada'), findsOneWidget);
        expect(find.text('Great sunset spot'), findsOneWidget);
        expect(find.text('Sightseeing'), findsOneWidget);
        expect(find.textContaining('5.00'), findsOneWidget);
        expect(find.text('By Former member'), findsOneWidget);
        expect(find.text('Score: +2'), findsOneWidget);

        // Overflow menu should be visible for author/organizer
        expect(find.byIcon(Icons.more_vert), findsOneWidget);
      },
    );

    testWidgets(
      'SuggestionCard hides overflow menu for non-author non-organizer member',
      (tester) async {
        final nonAuthorUser = MockUser(
          uid: memberUid,
          email: 'member@example.com',
          displayName: 'Bob Member',
        );

        await tester.pumpApp(
          Scaffold(
            body: SuggestionCard(
              suggestion: suggestion,
              currency: 'INR',
              currentUserId: memberUid,
              isOrganizer: false,
              members: const [],
            ),
          ),
          authUserValue: AsyncData(nonAuthorUser),
        );

        expect(find.byIcon(Icons.more_vert), findsNothing);
      },
    );

    testWidgets(
      'Tapping vote button calls repository and renders vote highlights',
      (tester) async {
        await fakeFirestore
            .collection('trips')
            .doc(tripId)
            .collection('suggestions')
            .doc('s1')
            .set(suggestion.toFirestore());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              suggestionRepositoryProvider.overrideWithValue(repository),
              myVoteStreamProvider((
                tripId: tripId,
                suggestionId: 's1',
                userUid: authorUid,
              )).overrideWithValue(const AsyncData(null)),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: Scaffold(
                body: SuggestionCard(
                  suggestion: suggestion,
                  currency: 'INR',
                  currentUserId: authorUid,
                  isOrganizer: true,
                  members: const [],
                ),
              ),
            ),
          ),
        );

        final upvoteButton = find.byTooltip('Upvote');
        expect(upvoteButton, findsOneWidget);

        await tester.tap(upvoteButton);
        await tester.pumpAndSettle();

        final voteDoc = await fakeFirestore
            .collection('trips')
            .doc(tripId)
            .collection('suggestions')
            .doc('s1')
            .collection('votes')
            .doc(authorUid)
            .get();

        expect(voteDoc.exists, isTrue);
        expect(voteDoc.data()!['value'], equals(1));
      },
    );

    testWidgets(
      'AddEditSuggestionScreen shows validation errors for empty title',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              suggestionRepositoryProvider.overrideWithValue(repository),
              tripProvider(tripId).overrideWithValue(AsyncData(testTrip)),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: AddEditSuggestionScreen(tripId: tripId),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final submitButton = find.widgetWithText(
          FilledButton,
          'Add Suggestion',
        );
        expect(submitButton, findsOneWidget);

        await tester.tap(submitButton);
        await tester.pumpAndSettle();

        expect(find.text('Please enter a title.'), findsOneWidget);
      },
    );

    testWidgets('AddEditSuggestionScreen submits new suggestion successfully', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            suggestionRepositoryProvider.overrideWithValue(repository),
            tripProvider(tripId).overrideWithValue(AsyncData(testTrip)),
            authUserProvider.overrideWithValue(AsyncData(mockUser)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: AddEditSuggestionScreen(tripId: tripId),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title *'),
        'Beach Volleyball',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Estimated Cost (Optional)'),
        '100',
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Add Suggestion'));
      await tester.pumpAndSettle();

      final suggestions = await fakeFirestore
          .collection('trips')
          .doc(tripId)
          .collection('suggestions')
          .get();

      expect(suggestions.docs.length, equals(1));
      expect(
        suggestions.docs.first.data()['title'],
        equals('Beach Volleyball'),
      );
      expect(suggestions.docs.first.data()['estimatedCost'], equals(10000));
    });

    testWidgets('Light and Dark mode smoke test for SuggestionCard', (
      tester,
    ) async {
      for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
        await tester.pumpApp(
          Scaffold(
            body: SuggestionCard(
              suggestion: suggestion,
              currency: 'INR',
              currentUserId: authorUid,
              isOrganizer: true,
              members: const [],
            ),
          ),
          authUserValue: AsyncData(mockUser),
          themeMode: themeMode,
        );

        expect(find.text('Visit Fort Aguada'), findsOneWidget);
      }
    });
  });
}
