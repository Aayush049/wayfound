import 'package:cloud_firestore/cloud_firestore.dart';

class Trip {
  final String id;
  final String name;
  final String destination;
  final DateTime startDate;
  final DateTime endDate;
  final String currency;
  final String organizerId;
  final String joinCode;
  final List<String> memberIds;
  final int memberCount;
  final bool archived;
  final DateTime? createdAt;

  const Trip({
    required this.id,
    required this.name,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.currency,
    required this.organizerId,
    required this.joinCode,
    required this.memberIds,
    required this.memberCount,
    required this.archived,
    this.createdAt,
  });

  factory Trip.fromFirestore(DocumentSnapshot doc) {
    return Trip.fromMap(doc.id, doc.data() as Map<String, dynamic>? ?? {});
  }

  factory Trip.fromMap(String id, Map<String, dynamic> data) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return Trip(
      id: id,
      name: data['name'] as String? ?? '',
      destination: data['destination'] as String? ?? '',
      startDate: parseDate(data['startDate']),
      endDate: parseDate(data['endDate']),
      currency: data['currency'] as String? ?? 'USD',
      organizerId: data['organizerId'] as String? ?? '',
      joinCode: data['joinCode'] as String? ?? '',
      memberIds: List<String>.from(data['memberIds'] as List? ?? []),
      memberCount: (data['memberCount'] as num?)?.toInt() ?? 1,
      archived: data['archived'] as bool? ?? false,
      createdAt: data['createdAt'] != null
          ? parseDate(data['createdAt'])
          : null,
    );
  }

  /// Helper to determine if a trip is ongoing or upcoming versus past.
  bool get isPast {
    final today = DateTime.now();
    final midnightToday = DateTime(today.year, today.month, today.day);
    final endDay = DateTime(endDate.year, endDate.month, endDate.day);
    return endDay.isBefore(midnightToday);
  }

  bool get isUpcoming {
    final today = DateTime.now();
    final midnightToday = DateTime(today.year, today.month, today.day);
    final startDay = DateTime(startDate.year, startDate.month, startDate.day);
    return startDay.isAfter(midnightToday);
  }

  bool get isOngoing {
    return !isPast && !isUpcoming;
  }

  bool isOrganizer(String uid) => organizerId == uid;
  bool isMember(String uid) => memberIds.contains(uid);
  bool get isFull => memberCount >= 15;
}
