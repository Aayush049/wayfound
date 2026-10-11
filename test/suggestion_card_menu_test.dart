import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfound/features/suggestions/domain/suggestion.dart';
import 'package:wayfound/features/suggestions/presentation/suggestion_card.dart';
import 'package:wayfound/features/trips/domain/member.dart';

void main() {
  group('SuggestionCard header layout and positioning tests', () {
    final members = [
      Member(
        uid: 'user_1',
        displayName: 'Test User',
        role: 'member',
        status: 'active',
        joinedAt: DateTime(2026, 11, 1),
      ),
    ];

    for (final isScheduled in [true, false]) {
      for (final canManage in [true, false]) {
        for (final width in [320.0, 360.0]) {
          for (final textScale in [1.0, 1.3]) {
            testWidgets(
              'scheduled:$isScheduled, canManage:$canManage, width:$width, scale:$textScale',
              (tester) async {
                final suggestion = Suggestion(
                  id: 'sug_1',
                  tripId: 'trip_1',
                  title: 'Explore Local Night Market',
                  note: 'Amazing street food and local crafts.',
                  category: 'food', // Food & Drink is the longest label
                  estimatedCost: 1500,
                  authorId: canManage ? 'user_1' : 'other_user',
                  upCount: 5,
                  downCount: 0,
                  status: isScheduled ? 'scheduled' : 'pending',
                  dayIndex: isScheduled ? 11 : null, // Day 12
                  createdAt: DateTime(2026, 11, 2),
                );

                tester.view.physicalSize = Size(width * 2, 900 * 2);
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
                            .copyWith(textScaler: TextScaler.linear(textScale)),
                        child: child!,
                      ),
                      home: Scaffold(
                        body: ListView(
                          children: [
                            SuggestionCard(
                              suggestion: suggestion,
                              currency: 'INR',
                              currentUserId: 'user_1',
                              isOrganizer: canManage,
                              members: members,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );

                await tester.pumpAndSettle();

                // 1. tester.takeException() is null (no overflow)
                expect(tester.takeException(), isNull);
                expect(find.byType(SuggestionCard), findsOneWidget);

                // 2. Score badge verification (on its own row, left-aligned)
                final scoreFinder = find.textContaining('Score:');
                expect(scoreFinder, findsOneWidget);
                final scoreRect = tester.getRect(scoreFinder);
                final categoryFinder = find.text('Food & Drink');
                expect(categoryFinder, findsOneWidget);
                final categoryRect = tester.getRect(categoryFinder);

                // Score badge top must be below the category chip bottom (on its own row)
                expect(scoreRect.top >= categoryRect.bottom - 2, isTrue);

                // Score badge left edge should be left-aligned (near the card content start, around 24-32 dp)
                expect(scoreRect.left < 45.0, isTrue);

                // 3. Menu verification when canManage is true
                if (canManage) {
                  final menuButtonFinder = find.byIcon(Icons.more_vert);
                  expect(menuButtonFinder, findsOneWidget);
                  final menuRect = tester.getRect(menuButtonFinder);
                  // Menu top is within the first row (same top band as category chip)
                  expect(
                    (menuRect.top - categoryRect.top).abs() < 24.0,
                    isTrue,
                  );
                } else {
                  expect(find.byIcon(Icons.more_vert), findsNothing);
                }
              },
            );
          }
        }
      }
    }
  });
}
