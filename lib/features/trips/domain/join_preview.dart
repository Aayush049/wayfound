import 'package:cloud_firestore/cloud_firestore.dart';

class JoinPreview {
  final String code;
  final String tripId;
  final String tripName;
  final String destination;
  final DateTime startDate;
  final DateTime endDate;
  final int memberCount;

  const JoinPreview({
    required this.code,
    required this.tripId,
    required this.tripName,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.memberCount,
  });

  factory JoinPreview.fromFirestore(DocumentSnapshot doc) {
    return JoinPreview.fromMap(
      doc.id,
      doc.data() as Map<String, dynamic>? ?? {},
    );
  }

  factory JoinPreview.fromMap(String code, Map<String, dynamic> data) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return JoinPreview(
      code: code,
      tripId: data['tripId'] as String? ?? '',
      tripName: data['tripName'] as String? ?? '',
      destination: data['destination'] as String? ?? '',
      startDate: parseDate(data['startDate']),
      endDate: parseDate(data['endDate']),
      memberCount: (data['memberCount'] as num?)?.toInt() ?? 1,
    );
  }

  bool get isFull => memberCount >= 15;
}
