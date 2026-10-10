import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfound/features/itinerary/data/itinerary_repository.dart';
import 'package:wayfound/features/itinerary/domain/itinerary_logic.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late ItineraryRepository repository;

  const tripId = 'trip_itin_repo_test';
  const suggId1 = 'sugg_1';
  const suggId2 = 'sugg_2';

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repository = ItineraryRepository(firestore: fakeFirestore);
  });

  group('ItineraryRepository Unit Tests', () {
    test('scheduleSuggestion updates status, dayIndex, order', () async {
      final docRef = fakeFirestore
          .collection('trips')
          .doc(tripId)
          .collection('suggestions')
          .doc(suggId1);

      await docRef.set({
        'title': 'Visit Museum',
        'status': 'pending',
        'dayIndex': null,
        'order': null,
      });

      await repository.scheduleSuggestion(
        tripId: tripId,
        suggestionId: suggId1,
        dayIndex: 0,
        order: 0,
      );

      final snap = await docRef.get();
      final data = snap.data()!;
      expect(data['status'], equals('scheduled'));
      expect(data['dayIndex'], equals(0));
      expect(data['order'], equals(0));
      expect(data['title'], equals('Visit Museum')); // Content untouched
    });

    test('moveToDay updates target dayIndex and order', () async {
      final docRef = fakeFirestore
          .collection('trips')
          .doc(tripId)
          .collection('suggestions')
          .doc(suggId1);

      await docRef.set({
        'title': 'Lunch spot',
        'status': 'scheduled',
        'dayIndex': 0,
        'order': 0,
      });

      await repository.moveToDay(
        tripId: tripId,
        suggestionId: suggId1,
        targetDayIndex: 2,
        targetOrder: 1,
      );

      final snap = await docRef.get();
      final data = snap.data()!;
      expect(data['status'], equals('scheduled'));
      expect(data['dayIndex'], equals(2));
      expect(data['order'], equals(1));
    });

    test('reorderDay performs batched write for updated orders', () async {
      final ref1 = fakeFirestore
          .collection('trips')
          .doc(tripId)
          .collection('suggestions')
          .doc(suggId1);
      final ref2 = fakeFirestore
          .collection('trips')
          .doc(tripId)
          .collection('suggestions')
          .doc(suggId2);

      await ref1.set({'status': 'scheduled', 'dayIndex': 0, 'order': 0});
      await ref2.set({'status': 'scheduled', 'dayIndex': 0, 'order': 1});

      final updates = [
        const ReorderItemUpdate(suggestionId: suggId1, newOrder: 1),
        const ReorderItemUpdate(suggestionId: suggId2, newOrder: 0),
      ];

      await repository.reorderDay(
        tripId: tripId,
        dayIndex: 0,
        updates: updates,
      );

      final snap1 = await ref1.get();
      final snap2 = await ref2.get();

      expect(snap1.data()!['order'], equals(1));
      expect(snap2.data()!['order'], equals(0));
    });

    test(
      'unschedule updates status to pending and resets dayIndex and order',
      () async {
        final docRef = fakeFirestore
            .collection('trips')
            .doc(tripId)
            .collection('suggestions')
            .doc(suggId1);

        await docRef.set({'status': 'scheduled', 'dayIndex': 1, 'order': 0});

        await repository.unschedule(tripId: tripId, suggestionId: suggId1);

        final snap = await docRef.get();
        final data = snap.data()!;
        expect(data['status'], equals('pending'));
        expect(data['dayIndex'], isNull);
        expect(data['order'], isNull);
      },
    );
  });
}
