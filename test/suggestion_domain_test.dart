import 'package:flutter_test/flutter_test.dart';
import 'package:wayfound/features/suggestions/domain/suggestion.dart';
import 'package:wayfound/features/suggestions/domain/suggestion_category.dart';
import 'package:wayfound/features/suggestions/domain/suggestion_payload_builders.dart';
import 'package:wayfound/features/suggestions/domain/suggestion_validators.dart';
import 'package:wayfound/features/suggestions/domain/vote_logic.dart';

void main() {
  group('Suggestion Domain Unit Tests', () {
    test('Category list in app matches security rules category list', () {
      expect(
        kSuggestionCategories,
        equals(['food', 'sightseeing', 'stay', 'transport', 'other']),
      );
    });

    test('computeVoteTransition handles all 6 vote transitions correctly', () {
      // 1. No vote (0) + Up (1) -> Vote 1, up +1, down +0
      final t1 = computeVoteTransition(currentVoteValue: 0, targetVoteValue: 1);
      expect(t1.newVoteValue, equals(1));
      expect(t1.upDelta, equals(1));
      expect(t1.downDelta, equals(0));
      expect(t1.computeNewUpCount(0), equals(1));
      expect(t1.computeNewDownCount(0), equals(0));

      // 2. No vote (0) + Down (-1) -> Vote -1, up +0, down +1
      final t2 = computeVoteTransition(
        currentVoteValue: 0,
        targetVoteValue: -1,
      );
      expect(t2.newVoteValue, equals(-1));
      expect(t2.upDelta, equals(0));
      expect(t2.downDelta, equals(1));
      expect(t2.computeNewUpCount(0), equals(0));
      expect(t2.computeNewDownCount(0), equals(1));

      // 3. Up (1) + Down (-1) -> Vote -1, up -1, down +1
      final t3 = computeVoteTransition(
        currentVoteValue: 1,
        targetVoteValue: -1,
      );
      expect(t3.newVoteValue, equals(-1));
      expect(t3.upDelta, equals(-1));
      expect(t3.downDelta, equals(1));
      expect(t3.computeNewUpCount(1), equals(0));
      expect(t3.computeNewDownCount(0), equals(1));

      // 4. Down (-1) + Up (1) -> Vote 1, up +1, down -1
      final t4 = computeVoteTransition(
        currentVoteValue: -1,
        targetVoteValue: 1,
      );
      expect(t4.newVoteValue, equals(1));
      expect(t4.upDelta, equals(1));
      expect(t4.downDelta, equals(-1));
      expect(t4.computeNewUpCount(0), equals(1));
      expect(t4.computeNewDownCount(1), equals(0));

      // 5. Up (1) + Up (1) again -> Delete vote (null), up -1, down 0
      final t5 = computeVoteTransition(currentVoteValue: 1, targetVoteValue: 1);
      expect(t5.newVoteValue, isNull);
      expect(t5.upDelta, equals(-1));
      expect(t5.downDelta, equals(0));
      expect(t5.computeNewUpCount(1), equals(0));

      // 6. Down (-1) + Down (-1) again -> Delete vote (null), up 0, down -1
      final t6 = computeVoteTransition(
        currentVoteValue: -1,
        targetVoteValue: -1,
      );
      expect(t6.newVoteValue, isNull);
      expect(t6.upDelta, equals(0));
      expect(t6.downDelta, equals(-1));
      expect(t6.computeNewDownCount(1), equals(0));
    });

    test('VoteTransitionResult never lets counters drop below zero', () {
      final t = computeVoteTransition(currentVoteValue: 1, targetVoteValue: 1);
      // Attempting to decrease count from 0 stays 0
      expect(t.computeNewUpCount(0), equals(0));
    });

    test('sortSuggestions sorts by score descending, ties broken by oldest createdAt first', () {
      final now = DateTime(2026, 10, 8, 12, 0, 0);
      final s1 = Suggestion(
        id: '1',
        tripId: 't1',
        title: 'Idea 1',
        note: '',
        category: 'food',
        authorId: 'u1',
        upCount: 2,
        downCount: 1, // score = 1
        status: 'pending',
        createdAt: now.add(const Duration(minutes: 10)),
      );

      final s2 = Suggestion(
        id: '2',
        tripId: 't1',
        title: 'Idea 2',
        note: '',
        category: 'sightseeing',
        authorId: 'u2',
        upCount: 5,
        downCount: 0, // score = 5
        status: 'pending',
        createdAt: now,
      );

      final s3 = Suggestion(
        id: '3',
        tripId: 't1',
        title: 'Idea 3',
        note: '',
        category: 'stay',
        authorId: 'u3',
        upCount: 2,
        downCount: 1, // score = 1, but created earlier than s1
        status: 'pending',
        createdAt: now.add(const Duration(minutes: 2)),
      );

      final sorted = sortSuggestions([s1, s2, s3]);
      expect(sorted.map((s) => s.id).toList(), equals(['2', '3', '1']));
    });

    test(
      'SuggestionValidators validates title, note, category and cost properly',
      () {
        expect(
          SuggestionValidators.validateTitle(''),
          equals('Please enter a title.'),
        );
        expect(
          SuggestionValidators.validateTitle('   '),
          equals('Please enter a title.'),
        );
        expect(
          SuggestionValidators.validateTitle('A' * 81),
          equals('Title must be 80 characters or fewer.'),
        );
        expect(SuggestionValidators.validateTitle('Valid Title'), isNull);

        expect(
          SuggestionValidators.validateNote('A' * 501),
          equals('Note must be 500 characters or fewer.'),
        );
        expect(SuggestionValidators.validateNote('Valid note'), isNull);

        expect(
          SuggestionValidators.validateCategory('invalid_cat'),
          equals('Please select a valid category.'),
        );
        expect(SuggestionValidators.validateCategory('food'), isNull);

        expect(
          SuggestionValidators.validateCostInput('-10', 'INR'),
          equals('Amount cannot be negative.'),
        );
        expect(SuggestionValidators.validateCostInput('100', 'INR'), isNull);
      },
    );

    test('SuggestionPayloadBuilders produces exact key sets for create, update, and votes', () {
      final createMap = SuggestionPayloadBuilders.buildSuggestionCreatePayload(
        title: 'Visit Beach',
        note: 'Sunset view',
        estimatedCost: 1000,
        category: 'sightseeing',
        authorId: 'user_123',
      );

      expect(
        createMap.keys.toSet(),
        equals({
          'title',
          'note',
          'estimatedCost',
          'category',
          'authorId',
          'upCount',
          'downCount',
          'status',
          'dayIndex',
          'order',
          'createdAt',
        }),
      );
      expect(createMap['upCount'], equals(0));
      expect(createMap['downCount'], equals(0));
      expect(createMap['status'], equals('pending'));
      expect(createMap['dayIndex'], isNull);
      expect(createMap['order'], isNull);

      final updateMap = SuggestionPayloadBuilders.buildSuggestionUpdatePayload(
        title: 'New Title',
        note: 'New Note',
        estimatedCost: 2000,
        category: 'food',
      );
      expect(
        updateMap.keys.toSet(),
        equals({'title', 'note', 'estimatedCost', 'category'}),
      );

      final voteMap = SuggestionPayloadBuilders.buildVotePayload(value: 1);
      expect(voteMap.keys.toSet(), equals({'value', 'updatedAt'}));
      expect(voteMap['value'], equals(1));
    });
  });
}
