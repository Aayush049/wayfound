import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfound/core/firebase_providers.dart';
import 'package:wayfound/features/itinerary/presentation/day_picker_sheet.dart';
import 'package:wayfound/features/itinerary/presentation/itinerary_day_section.dart';
import 'package:wayfound/features/itinerary/presentation/itinerary_item_tile.dart';
import 'package:wayfound/features/itinerary/presentation/itinerary_tab.dart';
import 'package:wayfound/features/suggestions/data/suggestions_providers.dart';
import 'package:wayfound/features/suggestions/domain/suggestion.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
  });

  Suggestion createTestSuggestion({
    required String id,
    required String title,
    required String status,
    int? dayIndex,
    int? order,
    int score = 0,
    int? cost,
  }) {
    return Suggestion(
      id: id,
      tripId: 'trip_123',
      title: title,
      category: 'activity',
      note: 'Note for $title',
      estimatedCost: cost,
      authorId: 'user_1',
      createdAt: DateTime(2026, 10, 1),
      status: status,
      dayIndex: dayIndex,
      order: order,
      upCount: score > 0 ? score : 0,
      downCount: score < 0 ? -score : 0,
    );
  }

  group('Itinerary UI Components Widget Tests', () {
    testWidgets('ItineraryItemTile renders suggestion content correctly', (
      tester,
    ) async {
      final suggestion = createTestSuggestion(
        id: 'sugg_1',
        title: 'Visit Louvre Museum',
        status: 'scheduled',
        dayIndex: 0,
        order: 0,
        cost: 2500,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItineraryItemTile(
              suggestion: suggestion,
              currency: 'USD',
              isOrganizer: true,
              isArchived: false,
            ),
          ),
        ),
      );

      expect(find.text('Visit Louvre Museum'), findsOneWidget);
      expect(find.text('Note for Visit Louvre Museum'), findsOneWidget);
      expect(find.textContaining('25.00'), findsOneWidget);
      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    });

    testWidgets('ItineraryItemTile hides options menu when non-organizer', (
      tester,
    ) async {
      final suggestion = createTestSuggestion(
        id: 'sugg_1',
        title: 'Visit Louvre Museum',
        status: 'scheduled',
        dayIndex: 0,
        order: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItineraryItemTile(
              suggestion: suggestion,
              currency: 'USD',
              isOrganizer: false,
              isArchived: false,
            ),
          ),
        ),
      );

      expect(find.text('Visit Louvre Museum'), findsOneWidget);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
    });

    testWidgets('DayPickerSheet lists all trip days and allows selecting one', (
      tester,
    ) async {
      int? selectedDay;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DayPickerSheet(
              startDate: DateTime(2026, 10, 12),
              totalDays: 3,
              currentDayIndex: 0,
              onDaySelected: (day) {
                selectedDay = day;
              },
            ),
          ),
        ),
      );

      expect(find.text('Select Day'), findsOneWidget);
      expect(find.text('Day 1 · Mon 12 Oct'), findsOneWidget);
      expect(find.text('Day 2 · Tue 13 Oct'), findsOneWidget);
      expect(find.text('Day 3 · Wed 14 Oct'), findsOneWidget);

      await tester.tap(find.text('Day 2 · Tue 13 Oct'));
      await tester.pumpAndSettle();

      expect(selectedDay, equals(1));
    });

    testWidgets('ItineraryDaySection renders header and items', (tester) async {
      final item = createTestSuggestion(
        id: 'sugg_1',
        title: 'Eiffel Tower Tour',
        status: 'scheduled',
        dayIndex: 0,
        order: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ItineraryDaySection(
                dayIndex: 0,
                startDate: DateTime(2026, 10, 12),
                items: [item],
                currency: 'USD',
                isOrganizer: true,
                isArchived: false,
                onAddSuggestion: () {},
                onMoveItem: (_) {},
                onUnscheduleItem: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Day 1 · Mon 12 Oct'), findsOneWidget);
      expect(find.text('1 activity'), findsOneWidget);
      expect(find.text('Eiffel Tower Tour'), findsOneWidget);
    });

    testWidgets('ItineraryTab renders day sections and empty state', (
      tester,
    ) async {
      final startDate = DateTime(2026, 10, 12);
      final endDate = DateTime(2026, 10, 14);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firestoreProvider.overrideWithValue(fakeFirestore),
            suggestionsStreamProvider('trip_123')
                .overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ItineraryTab(
                tripId: 'trip_123',
                startDate: startDate,
                endDate: endDate,
                currency: 'USD',
                isOrganizer: true,
                isArchived: false,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No itinerary items scheduled yet'), findsOneWidget);
      expect(find.text('Day 1 · Mon 12 Oct'), findsOneWidget);
      expect(find.text('Day 2 · Tue 13 Oct'), findsOneWidget);
      expect(find.text('Day 3 · Wed 14 Oct'), findsOneWidget);
    });
  });
}
