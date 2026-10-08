import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfound/features/suggestions/data/suggestion_repository.dart';
import 'package:wayfound/features/suggestions/domain/suggestion_payload_builders.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late SuggestionRepository repository;

  const tripId = 'trip_repo_test';
  const userUid = 'user_123';
  const suggId = 'sugg_repo_1';

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repository = SuggestionRepository(firestore: fakeFirestore);
  });

  group('SuggestionRepository Unit Tests', () {
    test('createSuggestion adds a document to Firestore', () async {
      await repository.createSuggestion(
        tripId: tripId,
        title: 'Visit Beach',
        note: 'Bring towels',
        estimatedCost: 200,
        category: 'sightseeing',
        authorId: userUid,
      );

      final snapshot = await fakeFirestore
          .collection('trips')
          .doc(tripId)
          .collection('suggestions')
          .get();

      expect(snapshot.docs.length, equals(1));
      final data = snapshot.docs.first.data();
      expect(data['title'], equals('Visit Beach'));
      expect(data['note'], equals('Bring towels'));
      expect(data['estimatedCost'], equals(200));
      expect(data['category'], equals('sightseeing'));
      expect(data['authorId'], equals(userUid));
      expect(data['upCount'], equals(0));
      expect(data['downCount'], equals(0));
      expect(data['status'], equals('pending'));
    });

    test('updateSuggestion updates content fields', () async {
      final docRef = fakeFirestore
          .collection('trips')
          .doc(tripId)
          .collection('suggestions')
          .doc(suggId);

      await docRef.set(
        SuggestionPayloadBuilders.buildSuggestionCreatePayload(
          title: 'Old Title',
          note: 'Old Note',
          estimatedCost: 100,
          category: 'food',
          authorId: userUid,
        ),
      );

      await repository.updateSuggestion(
        tripId: tripId,
        suggestionId: suggId,
        title: 'New Title',
        note: 'New Note',
        estimatedCost: 500,
        category: 'stay',
      );

      final updatedDoc = await docRef.get();
      final data = updatedDoc.data()!;
      expect(data['title'], equals('New Title'));
      expect(data['note'], equals('New Note'));
      expect(data['estimatedCost'], equals(500));
      expect(data['category'], equals('stay'));
      expect(data['upCount'], equals(0)); // Unchanged
    });

    test('deleteSuggestion removes suggestion document', () async {
      final docRef = fakeFirestore
          .collection('trips')
          .doc(tripId)
          .collection('suggestions')
          .doc(suggId);

      await docRef.set({'title': 'To delete'});

      await repository.deleteSuggestion(tripId: tripId, suggestionId: suggId);

      final doc = await docRef.get();
      expect(doc.exists, isFalse);
    });

    test('castVote handles all 6 vote transitions in transactions', () async {
      final suggRef = fakeFirestore
          .collection('trips')
          .doc(tripId)
          .collection('suggestions')
          .doc(suggId);

      await suggRef.set(
        SuggestionPayloadBuilders.buildSuggestionCreatePayload(
          title: 'Vote Test',
          note: 'Note',
          estimatedCost: null,
          category: 'other',
          authorId: userUid,
        ),
      );

      final voteRef = suggRef.collection('votes').doc(userUid);

      // 1. No vote -> Up (+1 upCount, vote doc set)
      await repository.castVote(
        tripId: tripId,
        suggestionId: suggId,
        userUid: userUid,
        targetVoteValue: 1,
      );

      var suggDoc = await suggRef.get();
      var voteDoc = await voteRef.get();
      expect(suggDoc.data()!['upCount'], equals(1));
      expect(suggDoc.data()!['downCount'], equals(0));
      expect(voteDoc.exists, isTrue);
      expect(voteDoc.data()!['value'], equals(1));

      // 2. Up -> Down (flip: upCount 0, downCount 1, vote doc set to -1)
      await repository.castVote(
        tripId: tripId,
        suggestionId: suggId,
        userUid: userUid,
        targetVoteValue: -1,
      );

      suggDoc = await suggRef.get();
      voteDoc = await voteRef.get();
      expect(suggDoc.data()!['upCount'], equals(0));
      expect(suggDoc.data()!['downCount'], equals(1));
      expect(voteDoc.exists, isTrue);
      expect(voteDoc.data()!['value'], equals(-1));

      // 3. Down -> Up (flip back: upCount 1, downCount 0, vote doc set to 1)
      await repository.castVote(
        tripId: tripId,
        suggestionId: suggId,
        userUid: userUid,
        targetVoteValue: 1,
      );

      suggDoc = await suggRef.get();
      voteDoc = await voteRef.get();
      expect(suggDoc.data()!['upCount'], equals(1));
      expect(suggDoc.data()!['downCount'], equals(0));
      expect(voteDoc.exists, isTrue);
      expect(voteDoc.data()!['value'], equals(1));

      // 4. Up -> Up again (remove up vote: upCount 0, downCount 0, vote doc deleted)
      await repository.castVote(
        tripId: tripId,
        suggestionId: suggId,
        userUid: userUid,
        targetVoteValue: 1,
      );

      suggDoc = await suggRef.get();
      voteDoc = await voteRef.get();
      expect(suggDoc.data()!['upCount'], equals(0));
      expect(suggDoc.data()!['downCount'], equals(0));
      expect(voteDoc.exists, isFalse);

      // 5. No vote -> Down (+1 downCount, vote doc set to -1)
      await repository.castVote(
        tripId: tripId,
        suggestionId: suggId,
        userUid: userUid,
        targetVoteValue: -1,
      );

      suggDoc = await suggRef.get();
      voteDoc = await voteRef.get();
      expect(suggDoc.data()!['upCount'], equals(0));
      expect(suggDoc.data()!['downCount'], equals(1));
      expect(voteDoc.exists, isTrue);
      expect(voteDoc.data()!['value'], equals(-1));

      // 6. Down -> Down again (remove down vote: upCount 0, downCount 0, vote doc deleted)
      await repository.castVote(
        tripId: tripId,
        suggestionId: suggId,
        userUid: userUid,
        targetVoteValue: -1,
      );

      suggDoc = await suggRef.get();
      voteDoc = await voteRef.get();
      expect(suggDoc.data()!['upCount'], equals(0));
      expect(suggDoc.data()!['downCount'], equals(0));
      expect(voteDoc.exists, isFalse);
    });

    test('watchSuggestions streams and sorts suggestions correctly', () async {
      final colRef = fakeFirestore
          .collection('trips')
          .doc(tripId)
          .collection('suggestions');

      await colRef.doc('s1').set({
        'title': 'Low Score',
        'note': '',
        'category': 'food',
        'authorId': 'u1',
        'upCount': 1,
        'downCount': 2, // score -1
        'status': 'pending',
        'createdAt': DateTime(2026, 10, 8, 10, 0),
      });

      await colRef.doc('s2').set({
        'title': 'High Score',
        'note': '',
        'category': 'sightseeing',
        'authorId': 'u2',
        'upCount': 5,
        'downCount': 0, // score 5
        'status': 'pending',
        'createdAt': DateTime(2026, 10, 8, 11, 0),
      });

      final stream = repository.watchSuggestions(tripId);
      final list = await stream.first;

      expect(list.length, equals(2));
      expect(list.first.title, equals('High Score'));
      expect(list.last.title, equals('Low Score'));
    });
  });
}
