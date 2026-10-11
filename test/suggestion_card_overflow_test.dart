import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfound/features/suggestions/domain/suggestion.dart';
import 'package:wayfound/features/suggestions/presentation/suggestion_card.dart';
import 'package:wayfound/features/itinerary/presentation/itinerary_item_tile.dart';
import 'package:wayfound/features/trips/domain/member.dart';

void main() {
  testWidgets(
    'SuggestionCard does not overflow at widths 320 and 360 dp with text scale 1.3',
    (tester) async {
      final suggestion = Suggestion(
        id: 'sug_1',
        tripId: 'trip_1',
        title: 'Explore Local Night Market and Food & Drink Stalls',
        note: 'Amazing street food and local crafts.',
        category: 'food',
        estimatedCost: 1500,
        authorId: 'user_1',
        upCount: 5,
        downCount: 0,
        status: 'scheduled',
        dayIndex: 11,
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
                      currentUserId: 'user_2',
                      isOrganizer: true,
                      members: members,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(SuggestionCard), findsOneWidget);
      }
    },
  );

  testWidgets(
    'ItineraryItemTile does not overflow at widths 320 and 360 dp with text scale 1.3',
    (tester) async {
      final suggestion = Suggestion(
        id: 'sug_1',
        tripId: 'trip_1',
        title: 'Explore Local Night Market and Food & Drink Stalls',
        note: 'Amazing street food and local crafts.',
        category: 'food',
        estimatedCost: 1500,
        authorId: 'user_1',
        upCount: 5,
        downCount: 0,
        status: 'scheduled',
        dayIndex: 11,
        createdAt: DateTime(2026, 11, 2),
      );

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
                    ItineraryItemTile(
                      suggestion: suggestion,
                      currency: 'INR',
                      isOrganizer: true,
                      isArchived: false,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(ItineraryItemTile), findsOneWidget);
      }
    },
  );
}
