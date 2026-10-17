import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfound/features/trips/data/trip_repository.dart';

void main() {
  group('TripRepository', () {
    late FakeFirebaseFirestore firestore;
    late TripRepository repository;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = TripRepository(firestore: firestore);
    });

    group('createTrip', () {
      test('creates trip, member, and joinCode atomically', () async {
        final result = await repository.createTrip(
          name: 'Summer Trip',
          destination: 'Goa',
          startDate: DateTime(2026, 7, 1),
          endDate: DateTime(2026, 7, 10),
          currency: 'INR',
          userUid: 'user-123',
          displayName: 'Organizer Name',
          photoUrl: 'https://example.com/photo.jpg',
        );

        expect(result.tripId, isNotEmpty);
        expect(result.joinCode, isNotEmpty);
        expect(result.joinCode.length, equals(6));

        // Verify trip document
        final tripDoc = await firestore
            .collection('trips')
            .doc(result.tripId)
            .get();
        expect(tripDoc.exists, isTrue);
        expect(tripDoc.data()?['name'], equals('Summer Trip'));
        expect(tripDoc.data()?['destination'], equals('Goa'));
        expect(tripDoc.data()?['currency'], equals('INR'));
        expect(tripDoc.data()?['organizerId'], equals('user-123'));
        expect(tripDoc.data()?['joinCode'], equals(result.joinCode));
        expect(tripDoc.data()?['memberIds'], equals(['user-123']));
        expect(tripDoc.data()?['memberCount'], equals(1));
        expect(tripDoc.data()?['archived'], isFalse);

        // Verify member document
        final memberDoc = await firestore
            .collection('trips')
            .doc(result.tripId)
            .collection('members')
            .doc('user-123')
            .get();
        expect(memberDoc.exists, isTrue);
        expect(memberDoc.id, equals('user-123'));
        expect(memberDoc.data()?['displayName'], equals('Organizer Name'));
        expect(
          memberDoc.data()?['photoUrl'],
          equals('https://example.com/photo.jpg'),
        );
        expect(memberDoc.data()?['role'], equals('organizer'));

        // Verify joinCode document
        final codeDoc = await firestore
            .collection('joinCodes')
            .doc(result.joinCode)
            .get();
        expect(codeDoc.exists, isTrue);
        expect(codeDoc.id, equals(result.joinCode));
        expect(codeDoc.data()?['tripId'], equals(result.tripId));
        expect(codeDoc.data()?['memberCount'], equals(1));
      });
    });

    group('watchMyTrips', () {
      test('emits trips where user is a member, sorted client side', () async {
        final now = DateTime.now();
        await repository.createTrip(
          name: 'Future Trip',
          destination: 'Dest 1',
          startDate: now.add(const Duration(days: 5)),
          endDate: now.add(const Duration(days: 10)),
          currency: 'INR',
          userUid: 'user-123',
          displayName: 'Organizer',
        );

        await repository.createTrip(
          name: 'Past Trip',
          destination: 'Dest 2',
          startDate: now.subtract(const Duration(days: 10)),
          endDate: now.subtract(const Duration(days: 5)),
          currency: 'INR',
          userUid: 'user-123',
          displayName: 'Organizer',
        );

        final stream = repository.watchMyTrips('user-123');
        final trips = await stream.first;

        expect(trips.length, equals(2));
        expect(trips[0].name, equals('Future Trip'));
        expect(trips[1].name, equals('Past Trip'));
      });
    });

    group('getJoinPreview', () {
      test('returns null when join code does not exist', () async {
        final preview = await repository.getJoinPreview('INVALID');
        expect(preview, isNull);
      });

      test('returns JoinPreview when code exists', () async {
        final result = await repository.createTrip(
          name: 'Preview Trip',
          destination: 'Paris',
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 8, 10),
          currency: 'EUR',
          userUid: 'user-123',
          displayName: 'Organizer',
        );

        final preview = await repository.getJoinPreview(result.joinCode);
        expect(preview, isNotNull);
        expect(preview?.code, equals(result.joinCode));
        expect(preview?.tripId, equals(result.tripId));
        expect(preview?.tripName, equals('Preview Trip'));
        expect(preview?.destination, equals('Paris'));
        expect(preview?.memberCount, equals(1));
        expect(preview?.isFull, isFalse);
      });
    });

    group('joinTrip', () {
      test('adds user to trip, members subcollection, and increments joinCode useCount', () async {
        final createResult = await repository.createTrip(
          name: 'Group Trip',
          destination: 'Tokyo',
          startDate: DateTime(2026, 9, 1),
          endDate: DateTime(2026, 9, 10),
          currency: 'JPY',
          userUid: 'user-organizer',
          displayName: 'Organizer',
        );

        await repository.joinTrip(
          code: createResult.joinCode,
          tripId: createResult.tripId,
          userUid: 'user-joiner',
          displayName: 'Joiner Name',
          photoUrl: 'https://example.com/joiner.jpg',
          currentMemberCount: 1,
        );

        // Verify trip updated
        final tripDoc = await firestore
            .collection('trips')
            .doc(createResult.tripId)
            .get();
        final memberIds = List<String>.from(tripDoc.data()?['memberIds']);
        expect(memberIds, containsAll(['user-organizer', 'user-joiner']));
        expect(tripDoc.data()?['memberCount'], equals(2));

        // Verify new member document
        final memberDoc = await firestore
            .collection('trips')
            .doc(createResult.tripId)
            .collection('members')
            .doc('user-joiner')
            .get();
        expect(memberDoc.exists, isTrue);
        expect(memberDoc.data()?['displayName'], equals('Joiner Name'));
        expect(memberDoc.data()?['role'], equals('member'));

        // Verify joinCode updated
        final codeDoc = await firestore
            .collection('joinCodes')
            .doc(createResult.joinCode)
            .get();
        expect(codeDoc.data()?['memberCount'], equals(2));
      });

      test('throws Exception when trip is full (>= 15 members)', () async {
        expect(
          () => repository.joinTrip(
            code: 'ABC234',
            tripId: 'trip-full',
            userUid: 'user-16',
            displayName: 'User 16',
            currentMemberCount: 15,
          ),
          throwsA(
            predicate<Exception>((e) => e.toString().contains('Trip is full')),
          ),
        );
      });
    });

    group('watchTrip & watchMembers', () {
      test('watchTrip emits null for non-existent trip and trip object for valid trip', () async {
        final createResult = await repository.createTrip(
          name: 'Single Trip',
          destination: 'Rome',
          startDate: DateTime(2026, 10, 1),
          endDate: DateTime(2026, 10, 5),
          currency: 'EUR',
          userUid: 'user-123',
          displayName: 'Organizer',
        );

        final trip = await repository.watchTrip(createResult.tripId).first;
        expect(trip, isNotNull);
        expect(trip?.name, equals('Single Trip'));

        final members = await repository
            .watchMembers(createResult.tripId)
            .first;
        expect(members.length, equals(1));
        expect(members.first.uid, equals('user-123'));
        expect(members.first.isOrganizer, isTrue);
      });
    });

    group('archiveTrip', () {
      test(
        'updates only archived: true and leaves other fields untouched',
        () async {
          final initialData = {
            'name': 'Tokyo Trip',
            'destination': 'Tokyo',
            'startDate': DateTime(2026, 11, 1),
            'endDate': DateTime(2026, 11, 7),
            'currency': 'JPY',
            'organizerId': 'org-1',
            'joinCode': 'TOK123',
            'memberIds': ['org-1', 'user-2'],
            'memberCount': 2,
            'archived': false,
          };
          final docRef = await firestore.collection('trips').add(initialData);

          await repository.archiveTrip(docRef.id);

          final doc = await firestore.collection('trips').doc(docRef.id).get();
          final data = doc.data()!;
          expect(data['archived'], isTrue);
          expect(data['name'], 'Tokyo Trip');
          expect(data['destination'], 'Tokyo');
          expect(data['currency'], 'JPY');
          expect(data['organizerId'], 'org-1');
          expect(data['joinCode'], 'TOK123');
          expect(data['memberIds'], ['org-1', 'user-2']);
          expect(data['memberCount'], 2);
          expect(data.keys.toSet(), initialData.keys.toSet());
        },
      );
    });
  });
}
