import 'package:flutter_test/flutter_test.dart';
import 'package:wayfound/features/itinerary/domain/itinerary_logic.dart';
import 'package:wayfound/features/itinerary/domain/itinerary_payload_builders.dart';
import 'package:wayfound/features/itinerary/domain/trip_days.dart';
import 'package:wayfound/features/suggestions/domain/suggestion.dart';

void main() {
  group('Trip Days Pure Logic Tests', () {
    test('tripDays returns 1 for same start and end date', () {
      final start = DateTime(2026, 10, 12);
      final end = DateTime(2026, 10, 12);
      expect(tripDays(start, end), equals(1));
    });

    test('tripDays calculates inclusive days correctly', () {
      final start = DateTime(2026, 10, 12);
      final end = DateTime(2026, 10, 14);
      expect(tripDays(start, end), equals(3));
    });

    test('tripDays handles end date before start date gracefully', () {
      final start = DateTime(2026, 10, 14);
      final end = DateTime(2026, 10, 12);
      expect(tripDays(start, end), equals(1));
    });

    test('tripDays handles month and year boundaries', () {
      final start = DateTime(2026, 12, 30);
      final end = DateTime(2027, 1, 2);
      // Dec 30, Dec 31, Jan 1, Jan 2 -> 4 days
      expect(tripDays(start, end), equals(4));
    });

    test('dayDate calculates date for given index', () {
      final start = DateTime(2026, 10, 12);
      expect(dayDate(start, 0), equals(DateTime(2026, 10, 12)));
      expect(dayDate(start, 2), equals(DateTime(2026, 10, 14)));
    });

    test('formatDayHeader produces formatted string', () {
      final start = DateTime(2026, 10, 12); // Mon Oct 12
      final header0 = formatDayHeader(start, 0);
      expect(header0, equals('Day 1 · Mon 12 Oct'));

      final header2 = formatDayHeader(start, 2);
      expect(header2, equals('Day 3 · Wed 14 Oct'));
    });
  });

  group('Itinerary Logic Grouping & Ordering Tests', () {
    final t1 = DateTime(2026, 10, 10, 10, 0);
    final t2 = DateTime(2026, 10, 10, 11, 0);

    final sPending = Suggestion(
      id: 's_pending',
      tripId: 'trip_1',
      title: 'Pending item',
      note: '',
      category: 'food',
      authorId: 'u1',
      upCount: 0,
      downCount: 0,
      status: 'pending',
      createdAt: t1,
    );

    final sDay0Order0 = Suggestion(
      id: 's_0_0',
      tripId: 'trip_1',
      title: 'Day 0 Item 0',
      note: '',
      category: 'sightseeing',
      authorId: 'u1',
      upCount: 1,
      downCount: 0,
      status: 'scheduled',
      dayIndex: 0,
      order: 0,
      createdAt: t1,
    );

    final sDay0Order1 = Suggestion(
      id: 's_0_1',
      tripId: 'trip_1',
      title: 'Day 0 Item 1',
      note: '',
      category: 'food',
      authorId: 'u2',
      upCount: 2,
      downCount: 0,
      status: 'scheduled',
      dayIndex: 0,
      order: 1,
      createdAt: t2,
    );

    final sDay1Order0 = Suggestion(
      id: 's_1_0',
      tripId: 'trip_1',
      title: 'Day 1 Item 0',
      note: '',
      category: 'stay',
      authorId: 'u1',
      upCount: 0,
      downCount: 0,
      status: 'scheduled',
      dayIndex: 1,
      order: 0,
      createdAt: t1,
    );

    test('groupByDay filters scheduled items and groups by dayIndex', () {
      final suggestions = [sPending, sDay0Order1, sDay0Order0, sDay1Order0];
      final grouped = groupByDay(suggestions);

      expect(grouped.keys, containsAll([0, 1]));
      expect(grouped.containsKey(-1), isFalse);

      // Day 0 items sorted by order (0 then 1)
      expect(grouped[0]!.map((s) => s.id), equals(['s_0_0', 's_0_1']));

      // Day 1 items
      expect(grouped[1]!.map((s) => s.id), equals(['s_1_0']));
    });

    test('groupByDay resolves order ties by createdAt then id', () {
      final tie1 = Suggestion(
        id: 's_b',
        tripId: 'trip_1',
        title: 'Tie B',
        note: '',
        category: 'food',
        authorId: 'u1',
        upCount: 0,
        downCount: 0,
        status: 'scheduled',
        dayIndex: 0,
        order: 0,
        createdAt: t1,
      );
      final tie2 = Suggestion(
        id: 's_a',
        tripId: 'trip_1',
        title: 'Tie A',
        note: '',
        category: 'food',
        authorId: 'u1',
        upCount: 0,
        downCount: 0,
        status: 'scheduled',
        dayIndex: 0,
        order: 0,
        createdAt: t1,
      );

      final grouped = groupByDay([tie1, tie2]);
      // Same order, same createdAt -> sorted by id ascending ('s_a' before 's_b')
      expect(grouped[0]!.map((s) => s.id), equals(['s_a', 's_b']));
    });

    test('nextOrderForDay calculates next order index', () {
      expect(nextOrderForDay([]), equals(0));
      expect(nextOrderForDay([sDay0Order0]), equals(1));
      expect(nextOrderForDay([sDay0Order0, sDay0Order1]), equals(2));
    });

    test('planReorder generates minimal updates when moving item down', () {
      // List: [A(order 0), B(order 1), C(order 2)]
      final a = sDay0Order0.copyWith(id: 'A', order: 0);
      final b = sDay0Order0.copyWith(id: 'B', order: 1);
      final c = sDay0Order0.copyWith(id: 'C', order: 2);
      final items = [a, b, c];

      // ReorderableListView: move A (oldIndex 0) to after B (newIndex 2, which becomes 1)
      final updates = planReorder(items, 0, 2);
      // Resulting list: [B(order 0), A(order 1), C(order 2)]
      expect(
        updates,
        equals([
          const ReorderItemUpdate(suggestionId: 'B', newOrder: 0),
          const ReorderItemUpdate(suggestionId: 'A', newOrder: 1),
        ]),
      );
    });

    test('planReorder generates minimal updates when moving item up', () {
      final a = sDay0Order0.copyWith(id: 'A', order: 0);
      final b = sDay0Order0.copyWith(id: 'B', order: 1);
      final c = sDay0Order0.copyWith(id: 'C', order: 2);
      final items = [a, b, c];

      // Move C (oldIndex 2) to top (newIndex 0)
      final updates = planReorder(items, 2, 0);
      // Resulting list: [C(0), A(1), B(2)]
      expect(
        updates,
        equals([
          const ReorderItemUpdate(suggestionId: 'C', newOrder: 0),
          const ReorderItemUpdate(suggestionId: 'A', newOrder: 1),
          const ReorderItemUpdate(suggestionId: 'B', newOrder: 2),
        ]),
      );
    });

    test(
      'planReorder returns empty list for same index move or invalid bounds',
      () {
        final a = sDay0Order0.copyWith(id: 'A', order: 0);
        final b = sDay0Order0.copyWith(id: 'B', order: 1);
        final items = [a, b];

        expect(planReorder(items, 0, 0), isEmpty);
        expect(planReorder(items, -1, 1), isEmpty);
        expect(planReorder(items, 0, 5), isEmpty);
      },
    );

    test('planMoveToDay plans schedule update to end of target day', () {
      final update = planMoveToDay(sPending, 2, [sDay1Order0]);
      expect(
        update,
        equals(
          const ItineraryScheduleUpdate(
            suggestionId: 's_pending',
            status: 'scheduled',
            dayIndex: 2,
            order: 1,
          ),
        ),
      );
    });

    test('planUnschedule plans unscheduling suggestion back to pending', () {
      final update = planUnschedule(sDay0Order0);
      expect(
        update,
        equals(
          const ItineraryScheduleUpdate(
            suggestionId: 's_0_0',
            status: 'pending',
            dayIndex: null,
            order: null,
          ),
        ),
      );
    });
  });

  group('Itinerary Payload Builders Tests', () {
    test('buildSchedulePayload produces exact key set', () {
      final payload = ItineraryPayloadBuilders.buildSchedulePayload(
        dayIndex: 1,
        order: 2,
      );
      expect(payload.keys, unorderedEquals(['status', 'dayIndex', 'order']));
      expect(payload['status'], equals('scheduled'));
      expect(payload['dayIndex'], equals(1));
      expect(payload['order'], equals(2));
    });

    test('buildUnschedulePayload produces exact key set', () {
      final payload = ItineraryPayloadBuilders.buildUnschedulePayload();
      expect(payload.keys, unorderedEquals(['status', 'dayIndex', 'order']));
      expect(payload['status'], equals('pending'));
      expect(payload['dayIndex'], isNull);
      expect(payload['order'], isNull);
    });
  });
}
