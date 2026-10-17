import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/join_code.dart';
import '../domain/join_preview.dart';
import '../domain/member.dart';
import '../domain/trip.dart';
import '../domain/trip_payload_builders.dart';

class TripRepository {
  final FirebaseFirestore _firestore;
  final Random? _random;

  TripRepository({FirebaseFirestore? firestore, this._random})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Creates a new trip atomically with [createTrip] batch.
  /// Retries code generation up to 5 times if a collision occurs.
  Future<({String tripId, String joinCode})> createTrip({
    required String name,
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    required String currency,
    required String userUid,
    required String displayName,
    String? photoUrl,
  }) async {
    int attempts = 0;

    while (attempts < 5) {
      attempts++;
      final code = generateJoinCode(_random);
      final tripDocRef = _firestore.collection('trips').doc();
      final tripId = tripDocRef.id;

      final memberDocRef = tripDocRef.collection('members').doc(userUid);
      final joinCodeDocRef = _firestore.collection('joinCodes').doc(code);

      final batch = _firestore.batch();

      final tripData = buildTripCreatePayload(
        name: name,
        destination: destination,
        startDate: startDate,
        endDate: endDate,
        currency: currency,
        organizerId: userUid,
        joinCode: code,
      );

      final memberData = buildMemberCreatePayload(
        displayName: displayName,
        photoUrl: photoUrl,
        role: 'organizer',
      );

      final joinCodeData = buildJoinCodeCreatePayload(
        tripId: tripId,
        tripName: name,
        destination: destination,
        startDate: startDate,
        endDate: endDate,
        memberCount: 1,
      );

      batch.set(tripDocRef, tripData);
      batch.set(memberDocRef, memberData);
      batch.set(joinCodeDocRef, joinCodeData);

      try {
        await batch.commit();
        return (tripId: tripId, joinCode: code);
      } catch (e) {
        if (attempts >= 5) {
          throw Exception(
            'Failed to generate a unique join code after 5 attempts. Please try again.',
          );
        }
        // Retry loop for collision
      }
    }

    throw Exception('Could not create trip');
  }

  /// Streams trips where [uid] is in [memberIds].
  /// Sorts client-side without composite index:
  /// - Active trips first (upcoming/ongoing by startDate ASC, then past trips by startDate DESC)
  /// - Archived trips last
  Stream<List<Trip>> watchMyTrips(String uid) {
    return _firestore
        .collection('trips')
        .where('memberIds', arrayContains: uid)
        .snapshots()
        .map((snapshot) {
          final trips = snapshot.docs
              .map((doc) => Trip.fromFirestore(doc))
              .toList();

          return sortTripsClientSide(trips);
        });
  }

  /// Client-side sorting helper for trips list.
  static List<Trip> sortTripsClientSide(List<Trip> trips) {
    final today = DateTime.now();
    final midnightToday = DateTime(today.year, today.month, today.day);

    final activeTrips = <Trip>[];
    final pastTrips = <Trip>[];
    final archivedTrips = <Trip>[];

    for (final trip in trips) {
      if (trip.archived) {
        archivedTrips.add(trip);
        continue;
      }
      final endDay = DateTime(
        trip.endDate.year,
        trip.endDate.month,
        trip.endDate.day,
      );
      if (endDay.isBefore(midnightToday)) {
        pastTrips.add(trip);
      } else {
        activeTrips.add(trip);
      }
    }

    // Active trips by startDate ascending
    activeTrips.sort((a, b) => a.startDate.compareTo(b.startDate));

    // Past trips by startDate descending
    pastTrips.sort((a, b) => b.startDate.compareTo(a.startDate));

    // Archived trips by startDate descending
    archivedTrips.sort((a, b) => b.startDate.compareTo(a.startDate));

    return [...activeTrips, ...pastTrips, ...archivedTrips];
  }

  /// Streams a single [Trip] document.
  Stream<Trip?> watchTrip(String tripId) {
    return _firestore.collection('trips').doc(tripId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Trip.fromFirestore(doc);
    });
  }

  /// Streams members of a trip (`trips/{tripId}/members`).
  /// Active members sorted: organizer first, then by joinedAt ASC.
  Stream<List<Member>> watchMembers(String tripId) {
    return _firestore
        .collection('trips')
        .doc(tripId)
        .collection('members')
        .snapshots()
        .map((snapshot) {
          final members = snapshot.docs
              .map((doc) => Member.fromFirestore(doc))
              .where((m) => m.isActive)
              .toList();

          members.sort((a, b) {
            if (a.isOrganizer && !b.isOrganizer) return -1;
            if (!a.isOrganizer && b.isOrganizer) return 1;
            if (a.joinedAt != null && b.joinedAt != null) {
              return a.joinedAt!.compareTo(b.joinedAt!);
            }
            return 0;
          });

          return members;
        });
  }

  /// Looks up a join preview document `joinCodes/{code}`.
  Future<JoinPreview?> getJoinPreview(String code) async {
    final doc = await _firestore.collection('joinCodes').doc(code).get();
    if (!doc.exists) return null;
    return JoinPreview.fromFirestore(doc);
  }

  /// Joins a trip via one atomic batched write.
  Future<void> joinTrip({
    required String code,
    required String tripId,
    required String userUid,
    required String displayName,
    String? photoUrl,
    required int currentMemberCount,
  }) async {
    if (currentMemberCount >= 15) {
      throw Exception('Trip is full');
    }

    final tripDocRef = _firestore.collection('trips').doc(tripId);
    final memberDocRef = tripDocRef.collection('members').doc(userUid);
    final joinCodeDocRef = _firestore.collection('joinCodes').doc(code);

    final batch = _firestore.batch();

    batch.update(tripDocRef, buildJoinTripUpdatePayload(callerUid: userUid));

    batch.set(
      memberDocRef,
      buildMemberCreatePayload(
        displayName: displayName,
        photoUrl: photoUrl,
        role: 'member',
      ),
    );

    batch.update(
      joinCodeDocRef,
      buildJoinCodeUpdatePayload(newMemberCount: currentMemberCount + 1),
    );

    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      final freshCodeDoc = await getJoinPreview(code);
      if (freshCodeDoc != null && freshCodeDoc.isFull) {
        throw Exception('Could not join, the trip may be full');
      }
      if (e.code == 'permission-denied') {
        throw Exception(
          "Couldn't join this trip. If you left it earlier, rejoining isn't supported in this version.",
        );
      }
      throw Exception(
        'Could not join trip. Please verify the code and try again.',
      );
    } catch (e) {
      final freshCodeDoc = await getJoinPreview(code);
      if (freshCodeDoc != null && freshCodeDoc.isFull) {
        throw Exception('Could not join, the trip may be full');
      }
      if (e.toString().contains('permission-denied')) {
        throw Exception(
          "Couldn't join this trip. If you left it earlier, rejoining isn't supported in this version.",
        );
      }
      throw Exception(
        'Could not join trip. Please verify the code and try again.',
      );
    }
  }

  /// Leaves a trip atomically.
  Future<void> leaveTrip({
    required String tripId,
    required String userUid,
    required List<String> currentMemberIds,
  }) async {
    final tripDocRef = _firestore.collection('trips').doc(tripId);
    final memberDocRef = tripDocRef.collection('members').doc(userUid);

    final newMemberIds = currentMemberIds.where((id) => id != userUid).toList();

    final batch = _firestore.batch();
    batch.update(tripDocRef, {
      'memberIds': newMemberIds,
      'memberCount': newMemberIds.length,
    });
    batch.update(memberDocRef, {'status': 'left'});

    await batch.commit();
  }

  /// Removes a member from a trip atomically (organizer action).
  Future<void> removeMember({
    required String tripId,
    required String targetUid,
    required List<String> currentMemberIds,
  }) async {
    final tripDocRef = _firestore.collection('trips').doc(tripId);
    final memberDocRef = tripDocRef.collection('members').doc(targetUid);

    final newMemberIds = currentMemberIds
        .where((id) => id != targetUid)
        .toList();

    final batch = _firestore.batch();
    batch.update(tripDocRef, {
      'memberIds': newMemberIds,
      'memberCount': newMemberIds.length,
    });
    batch.update(memberDocRef, {'status': 'left'});

    await batch.commit();
  }

  /// Streams all members of a trip (active and left).
  Stream<List<Member>> watchAllMembers(String tripId) {
    return _firestore
        .collection('trips')
        .doc(tripId)
        .collection('members')
        .snapshots()
        .map((snapshot) {
          final members = snapshot.docs
              .map((doc) => Member.fromFirestore(doc))
              .toList();

          members.sort((a, b) {
            if (a.isOrganizer && !b.isOrganizer) return -1;
            if (!a.isOrganizer && b.isOrganizer) return 1;
            if (a.joinedAt != null && b.joinedAt != null) {
              return a.joinedAt!.compareTo(b.joinedAt!);
            }
            return 0;
          });

          return members;
        });
  }

  /// Archives a trip. Only the organizer may archive, and payload must contain only `{'archived': true}`.
  Future<void> archiveTrip(String tripId) async {
    final tripDocRef = _firestore.collection('trips').doc(tripId);
    await tripDocRef.update(buildArchiveTripUpdatePayload());
  }
}
