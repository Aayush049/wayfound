import 'package:cloud_firestore/cloud_firestore.dart';

/// Pure payload builder for creating a `trips/{tripId}` document.
Map<String, dynamic> buildTripCreatePayload({
  required String name,
  required String destination,
  required DateTime startDate,
  required DateTime endDate,
  required String currency,
  required String organizerId,
  required String joinCode,
  Object? createdAt,
}) {
  return {
    'name': name.trim(),
    'destination': destination.trim(),
    'startDate': Timestamp.fromDate(
      DateTime(startDate.year, startDate.month, startDate.day),
    ),
    'endDate': Timestamp.fromDate(
      DateTime(endDate.year, endDate.month, endDate.day),
    ),
    'currency': currency.trim().toUpperCase(),
    'organizerId': organizerId,
    'joinCode': joinCode,
    'memberIds': [organizerId],
    'memberCount': 1,
    'archived': false,
    'createdAt': createdAt ?? FieldValue.serverTimestamp(),
  };
}

/// Pure payload builder for creating a `trips/{tripId}/members/{uid}` document.
Map<String, dynamic> buildMemberCreatePayload({
  required String displayName,
  String? photoUrl,
  required String role,
  Object? joinedAt,
}) {
  return {
    'displayName': displayName.trim(),
    'photoUrl': (photoUrl != null && photoUrl.trim().isNotEmpty)
        ? photoUrl.trim()
        : null,
    'role': role,
    'status': 'active',
    'joinedAt': joinedAt ?? FieldValue.serverTimestamp(),
  };
}

/// Pure payload builder for creating a `joinCodes/{code}` document.
Map<String, dynamic> buildJoinCodeCreatePayload({
  required String tripId,
  required String tripName,
  required String destination,
  required DateTime startDate,
  required DateTime endDate,
  required int memberCount,
}) {
  return {
    'tripId': tripId,
    'tripName': tripName.trim(),
    'destination': destination.trim(),
    'startDate': Timestamp.fromDate(
      DateTime(startDate.year, startDate.month, startDate.day),
    ),
    'endDate': Timestamp.fromDate(
      DateTime(endDate.year, endDate.month, endDate.day),
    ),
    'memberCount': memberCount,
  };
}

/// Pure payload builder for updating a `trips/{tripId}` document when a member joins.
Map<String, dynamic> buildJoinTripUpdatePayload({required String callerUid}) {
  return {
    'memberIds': FieldValue.arrayUnion([callerUid]),
    'memberCount': FieldValue.increment(1),
  };
}

/// Pure payload builder for updating a `joinCodes/{code}` document when a member joins.
Map<String, dynamic> buildJoinCodeUpdatePayload({required int newMemberCount}) {
  return {'memberCount': newMemberCount};
}
