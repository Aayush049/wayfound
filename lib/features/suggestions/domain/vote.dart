import 'package:cloud_firestore/cloud_firestore.dart';

class Vote {
  final String uid;
  final int value; // +1 or -1
  final DateTime updatedAt;

  const Vote({required this.uid, required this.value, required this.updatedAt});

  bool get isUp => value == 1;
  bool get isDown => value == -1;

  factory Vote.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final updatedAtRaw = data['updatedAt'];
    DateTime parsedUpdatedAt;
    if (updatedAtRaw is Timestamp) {
      parsedUpdatedAt = updatedAtRaw.toDate();
    } else if (updatedAtRaw is String) {
      parsedUpdatedAt = DateTime.tryParse(updatedAtRaw) ?? DateTime.now();
    } else {
      parsedUpdatedAt = DateTime.now();
    }

    return Vote(
      uid: doc.id,
      value: (data['value'] as num?)?.toInt() ?? 0,
      updatedAt: parsedUpdatedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {'value': value, 'updatedAt': Timestamp.fromDate(updatedAt)};
  }
}
