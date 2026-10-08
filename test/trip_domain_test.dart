import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfound/features/trips/data/trip_repository.dart';
import 'package:wayfound/features/trips/domain/currencies.dart';
import 'package:wayfound/features/trips/domain/join_preview.dart';
import 'package:wayfound/features/trips/domain/member.dart';
import 'package:wayfound/features/trips/domain/trip.dart';

void main() {
  group('Trip Domain Models', () {
    group('Currencies', () {
      test('isSupportedCurrency validates currency codes', () {
        expect(isSupportedCurrency('INR'), isTrue);
        expect(isSupportedCurrency('USD'), isTrue);
        expect(isSupportedCurrency('EUR'), isTrue);
        expect(isSupportedCurrency('ABC'), isFalse);
        expect(isSupportedCurrency(null), isFalse);
      });
    });

    group('Trip', () {
      test('fromMap creates valid Trip object', () {
        final now = DateTime.now();
        final tripData = {
          'name': 'Beach Trip',
          'destination': 'Goa',
          'startDate': Timestamp.fromDate(now),
          'endDate': Timestamp.fromDate(now.add(const Duration(days: 3))),
          'currency': 'INR',
          'organizerId': 'user-1',
          'joinCode': 'ABC234',
          'memberIds': ['user-1', 'user-2'],
          'memberCount': 2,
          'archived': false,
          'createdAt': Timestamp.fromDate(now),
        };

        final trip = Trip.fromMap('trip-123', tripData);
        expect(trip.id, equals('trip-123'));
        expect(trip.name, equals('Beach Trip'));
        expect(trip.destination, equals('Goa'));
        expect(trip.currency, equals('INR'));
        expect(trip.organizerId, equals('user-1'));
        expect(trip.joinCode, equals('ABC234'));
        expect(trip.memberIds, equals(['user-1', 'user-2']));
        expect(trip.memberCount, equals(2));
        expect(trip.archived, isFalse);
        expect(trip.isOrganizer('user-1'), isTrue);
        expect(trip.isOrganizer('user-2'), isFalse);
        expect(trip.isMember('user-2'), isTrue);
        expect(trip.isMember('user-3'), isFalse);
      });

      test('status getters work correctly (upcoming, ongoing, past)', () {
        final today = DateTime.now();
        final now = DateTime(today.year, today.month, today.day);

        final upcomingTrip = Trip(
          id: '1',
          name: 'Future',
          destination: 'Dest',
          startDate: now.add(const Duration(days: 5)),
          endDate: now.add(const Duration(days: 10)),
          currency: 'INR',
          organizerId: 'u1',
          joinCode: 'ABC234',
          memberIds: ['u1'],
          memberCount: 1,
          archived: false,
        );

        final ongoingTrip = Trip(
          id: '2',
          name: 'Now',
          destination: 'Dest',
          startDate: now.subtract(const Duration(days: 1)),
          endDate: now.add(const Duration(days: 2)),
          currency: 'INR',
          organizerId: 'u1',
          joinCode: 'ABC234',
          memberIds: ['u1'],
          memberCount: 1,
          archived: false,
        );

        final pastTrip = Trip(
          id: '3',
          name: 'Past',
          destination: 'Dest',
          startDate: now.subtract(const Duration(days: 10)),
          endDate: now.subtract(const Duration(days: 5)),
          currency: 'INR',
          organizerId: 'u1',
          joinCode: 'ABC234',
          memberIds: ['u1'],
          memberCount: 1,
          archived: false,
        );

        expect(upcomingTrip.isUpcoming, isTrue);
        expect(upcomingTrip.isOngoing, isFalse);
        expect(upcomingTrip.isPast, isFalse);

        expect(ongoingTrip.isOngoing, isTrue);
        expect(ongoingTrip.isUpcoming, isFalse);
        expect(ongoingTrip.isPast, isFalse);

        expect(pastTrip.isPast, isTrue);
        expect(pastTrip.isUpcoming, isFalse);
        expect(pastTrip.isOngoing, isFalse);
      });

      test('sortTripsClientSide sorts upcoming/ongoing ascending and past descending', () {
        final today = DateTime.now();
        final now = DateTime(today.year, today.month, today.day);

        final upcomingLater = Trip(
          id: 'u2',
          name: 'Upcoming Later',
          destination: 'D',
          startDate: now.add(const Duration(days: 10)),
          endDate: now.add(const Duration(days: 15)),
          currency: 'INR',
          organizerId: 'u1',
          joinCode: 'ABC234',
          memberIds: ['u1'],
          memberCount: 1,
          archived: false,
        );

        final upcomingSooner = Trip(
          id: 'u1',
          name: 'Upcoming Sooner',
          destination: 'D',
          startDate: now.add(const Duration(days: 2)),
          endDate: now.add(const Duration(days: 5)),
          currency: 'INR',
          organizerId: 'u1',
          joinCode: 'ABC234',
          memberIds: ['u1'],
          memberCount: 1,
          archived: false,
        );

        final pastOlder = Trip(
          id: 'p2',
          name: 'Past Older',
          destination: 'D',
          startDate: now.subtract(const Duration(days: 20)),
          endDate: now.subtract(const Duration(days: 15)),
          currency: 'INR',
          organizerId: 'u1',
          joinCode: 'ABC234',
          memberIds: ['u1'],
          memberCount: 1,
          archived: false,
        );

        final pastRecent = Trip(
          id: 'p1',
          name: 'Past Recent',
          destination: 'D',
          startDate: now.subtract(const Duration(days: 5)),
          endDate: now.subtract(const Duration(days: 2)),
          currency: 'INR',
          organizerId: 'u1',
          joinCode: 'ABC234',
          memberIds: ['u1'],
          memberCount: 1,
          archived: false,
        );

        final sorted = TripRepository.sortTripsClientSide([
          pastOlder,
          upcomingLater,
          pastRecent,
          upcomingSooner,
        ]);

        expect(sorted.length, equals(4));
        expect(sorted[0].id, equals('u1')); // Sooner upcoming first
        expect(sorted[1].id, equals('u2')); // Later upcoming second
        expect(sorted[2].id, equals('p1')); // More recent past third
        expect(sorted[3].id, equals('p2')); // Older past last
      });
    });

    group('Member', () {
      test('fromMap creates valid Member object', () {
        final now = DateTime.now();
        final memberData = {
          'uid': 'user-123',
          'displayName': 'Alice',
          'photoUrl': 'https://example.com/alice.jpg',
          'role': 'organizer',
          'joinedAt': Timestamp.fromDate(now),
        };

        final member = Member.fromMap('user-123', memberData);
        expect(member.uid, equals('user-123'));
        expect(member.displayName, equals('Alice'));
        expect(member.photoUrl, equals('https://example.com/alice.jpg'));
        expect(member.role, equals('organizer'));
        expect(member.isOrganizer, isTrue);
      });
    });

    group('JoinPreview', () {
      test('fromMap creates valid JoinPreview object', () {
        final start = DateTime(2026, 8, 1);
        final end = DateTime(2026, 8, 5);

        final tripData = {
          'tripId': 'trip-999',
          'tripName': 'Mountains',
          'destination': 'Manali',
          'startDate': Timestamp.fromDate(start),
          'endDate': Timestamp.fromDate(end),
          'memberCount': 15,
        };

        final preview = JoinPreview.fromMap('ABC234', tripData);
        expect(preview.code, equals('ABC234'));
        expect(preview.tripId, equals('trip-999'));
        expect(preview.tripName, equals('Mountains'));
        expect(preview.destination, equals('Manali'));
        expect(preview.startDate, equals(start));
        expect(preview.endDate, equals(end));
        expect(preview.memberCount, equals(15));
        expect(preview.isFull, isTrue);
      });
    });
  });
}
