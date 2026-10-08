import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfound/features/trips/domain/trip_payload_builders.dart';

void main() {
  group('TripPayloadBuilders', () {
    group('buildTripCreatePayload', () {
      test('builds payload with exact required keys and values', () {
        final startDate = DateTime(2026, 7, 1);
        final endDate = DateTime(2026, 7, 10);
        final payload = buildTripCreatePayload(
          name: 'Summer Trip',
          destination: 'Paris',
          startDate: startDate,
          endDate: endDate,
          currency: 'EUR',
          organizerId: 'user-123',
          joinCode: 'ABC234',
        );

        expect(payload['name'], equals('Summer Trip'));
        expect(payload['destination'], equals('Paris'));
        expect(payload['startDate'], equals(Timestamp.fromDate(startDate)));
        expect(payload['endDate'], equals(Timestamp.fromDate(endDate)));
        expect(payload['currency'], equals('EUR'));
        expect(payload['organizerId'], equals('user-123'));
        expect(payload['joinCode'], equals('ABC234'));
        expect(payload['memberIds'], equals(['user-123']));
        expect(payload['memberCount'], equals(1));
        expect(payload['archived'], isFalse);
        expect(payload['createdAt'], equals(FieldValue.serverTimestamp()));

        expect(payload.keys.length, equals(11));
      });
    });

    group('buildMemberCreatePayload', () {
      test('builds member payload for organizer', () {
        final payload = buildMemberCreatePayload(
          displayName: 'Organizer Name',
          photoUrl: 'https://example.com/photo.jpg',
          role: 'organizer',
        );

        expect(payload['displayName'], equals('Organizer Name'));
        expect(payload['photoUrl'], equals('https://example.com/photo.jpg'));
        expect(payload['role'], equals('organizer'));
        expect(payload['status'], equals('active'));
        expect(payload['joinedAt'], equals(FieldValue.serverTimestamp()));
        expect(payload.keys.length, equals(5));
      });

      test('builds member payload for regular member with null photoUrl', () {
        final payload = buildMemberCreatePayload(
          displayName: 'Member Name',
          photoUrl: null,
          role: 'member',
        );

        expect(payload['role'], equals('member'));
        expect(payload['status'], equals('active'));
        expect(payload['photoUrl'], isNull);
      });
    });

    group('buildJoinCodeCreatePayload', () {
      test('builds join code payload', () {
        final startDate = DateTime(2026, 7, 1);
        final endDate = DateTime(2026, 7, 10);
        final payload = buildJoinCodeCreatePayload(
          tripId: 'trip-123',
          tripName: 'Summer Trip',
          destination: 'Paris',
          startDate: startDate,
          endDate: endDate,
          memberCount: 1,
        );

        expect(payload['tripId'], equals('trip-123'));
        expect(payload['tripName'], equals('Summer Trip'));
        expect(payload['destination'], equals('Paris'));
        expect(payload['startDate'], equals(Timestamp.fromDate(startDate)));
        expect(payload['endDate'], equals(Timestamp.fromDate(endDate)));
        expect(payload['memberCount'], equals(1));
        expect(payload.keys.length, equals(6));
      });
    });

    group('buildJoinTripUpdatePayload', () {
      test('builds join trip update payload with FieldValue.arrayUnion and FieldValue.increment', () {
        final payload = buildJoinTripUpdatePayload(callerUid: 'user-456');

        expect(payload['memberIds'], isA<FieldValue>());
        expect(payload['memberCount'], isA<FieldValue>());
        expect(payload.keys.length, equals(2));
      });
    });

    group('buildJoinCodeUpdatePayload', () {
      test('builds join code update payload with new member count', () {
        final payload = buildJoinCodeUpdatePayload(newMemberCount: 2);

        expect(payload['memberCount'], equals(2));
        expect(payload.keys.length, equals(1));
      });
    });
  });
}
