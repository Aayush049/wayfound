import 'package:cloud_firestore/cloud_firestore.dart';

class Member {
  final String uid;
  final String role;
  final String status;
  final String displayName;
  final String? photoUrl;
  final DateTime? joinedAt;

  const Member({
    required this.uid,
    required this.role,
    required this.status,
    required this.displayName,
    this.photoUrl,
    this.joinedAt,
  });

  factory Member.fromFirestore(DocumentSnapshot doc) {
    return Member.fromMap(doc.id, doc.data() as Map<String, dynamic>? ?? {});
  }

  factory Member.fromMap(String id, Map<String, dynamic> data) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return Member(
      uid: id,
      role: data['role'] as String? ?? 'member',
      status: data['status'] as String? ?? 'active',
      displayName: data['displayName'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      joinedAt: parseDate(data['joinedAt']),
    );
  }

  bool get isOrganizer => role == 'organizer';
  bool get isActive => status == 'active';
}
