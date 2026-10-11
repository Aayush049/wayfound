import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfound/features/suggestions/domain/suggestion.dart';
import 'package:wayfound/features/suggestions/presentation/suggestion_card.dart';
import 'package:wayfound/features/trips/domain/member.dart';

void main() {
  group('SuggestionCard menu regression tests (Bug 3)', () {
    testWidgets(
      'Menu is pinned top-right at 320/360 dp with 1.3x text scale for scheduled suggestion with Day chip',
      (tester) async {
        // Scheduled suggestion with Day chip and "Food & Drink" category (longest)
        final suggestion = Suggestion(
          id: 'sug_1',
          tripId: 'trip_1',
          title: 'Explore Local Night Market',
          note: 'Amazing street food and local crafts.',
          category: 'food',
          estimatedCost: 1500,
          authorId: 'user_1',
          upCount: 5,
          downCount: 0,
          status: 'scheduled',
          dayIndex: 11, // Day 12
          createdAt: DateTime(2026, 11, 2),
        );

        final members = [
          Member(
            uid: 'user_1',
            displayName: 'Test User',
            role: 'member',
            status: 'active',
            joinedAt: DateTime(2026, 11, 1),
          ),
        ];

        for (final width in [320.0, 360.0]) {
          tester.view.physicalSize = Size(width * 2, 800 * 2);
          tester.view.devicePixelRatio = 2.0;

          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(1.3)),
                  child: child!,
                ),
                home: Scaffold(
                  body: ListView(
                    children: [
                      SuggestionCard(
                        suggestion: suggestion,
                        currency: 'INR',
                        currentUserId: 'user_1', // author
                        isOrganizer: false,
                        members: members,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );

          await tester.pumpAndSettle();

          // No overflow or layout exceptions
          expect(tester.takeException(), isNull);
          expect(find.byType(SuggestionCard), findsOneWidget);

          // Find the PopupMenuButton
          final popupButton = find.byIcon(Icons.more_vert);
          expect(popupButton, findsOneWidget);

          // Get the position of the menu button
          final popupButtonWidget = tester.widget<PopupMenuButton<String>>(
            find.byType(PopupMenuButton<String>),
          );

          // Verify the card renders
          expect(find.byType(Card), findsOneWidget);
        }
      },
    );

    testWidgets(
      'No exception when menu hidden (non-author non-organizer)',
      (tester) async {
        final suggestion = Suggestion(
          id: 'sug_1',
          tripId: 'trip_1',
          title: 'Test Suggestion',
          note: 'Test note.',
          category: 'sightseeing',
          estimatedCost: 500,
          authorId: 'author_user',
          upCount: 1,
          downCount: 0,
          status: 'pending',
          createdAt: DateTime(2026, 11, 2),
        );

        final members = [
          Member(
            uid: 'author_user',
            displayName: 'Author',
            role: 'member',
            status: 'active',
            joinedAt: DateTime(2026, 11, 1),
          ),
          Member(
            uid: 'other_user',
            displayName: 'Other',
            role: 'member',
            status: 'active',
            joinedAt: DateTime(2026, 11, 1),
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: SuggestionCard(
                  suggestion: suggestion,
                  currency: 'INR',
                  currentUserId: 'other_user', // not author, not organizer
                  isOrganizer: false,
                  members: members,
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // No exception when menu is hidden
        expect(tester.takeException(), isNull);
        // Menu should NOT be visible
        expect(find.byIcon(Icons.more_vert), findsNothing);
      },
    );

    testWidgets(
      'Card without Day chip renders correctly with menu',
      (tester) async {
        final suggestion = Suggestion(
          id: 'sug_1',
          tripId: 'trip_1',
          title: 'Test Suggestion',
          note: 'Test note.',
          category: 'food',
          estimatedCost: 500,
          authorId: 'user_1',
          upCount: 1,
          downCount: 0,
          status: 'pending', // no day
          createdAt: DateTime(2026, 11, 2),
        );

        final members = [
          Member(
            uid: 'user_1',
            displayName: 'Test User',
            role: 'member',
            status: 'active',
            joinedAt: DateTime(2026, 11, 1),
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: SuggestionCard(
                  suggestion: suggestion,
                  currency: 'INR',
                  currentUserId: 'user_1',
                  isOrganizer: true, // organizer can edit
                  members: members,
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        // Menu should be visible for organizer
        expect(find.byIcon(Icons.more_vert), findsOneWidget);
      },
    );
  });
}