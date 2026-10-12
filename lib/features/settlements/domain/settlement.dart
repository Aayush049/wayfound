import 'package:cloud_firestore/cloud_firestore.dart';

enum SettlementStatus { pending, confirmed, rejected }

class Settlement {
  final String id;
  final String fromUid;
  final String toUid;
  final int amount;
  final SettlementStatus status;
  final DateTime? createdAt;
  final DateTime? resolvedAt;

  const Settlement({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.amount,
    required this.status,
    this.createdAt,
    this.resolvedAt,
  });

  factory Settlement.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Settlement(
      id: doc.id,
      fromUid: data['fromUid'] as String? ?? '',
      toUid: data['toUid'] as String? ?? '',
      amount: data['amount'] as int? ?? 0,
      status: _parseStatus(data['status'] as String? ?? 'pending'),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'fromUid': fromUid,
      'toUid': toUid,
      'amount': amount,
      'status': status.name,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
    };
  }

  static SettlementStatus _parseStatus(String val) {
    switch (val) {
      case 'confirmed':
        return SettlementStatus.confirmed;
      case 'rejected':
        return SettlementStatus.rejected;
      case 'pending':
      default:
        return SettlementStatus.pending;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Settlement &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          fromUid == other.fromUid &&
          toUid == other.toUid &&
          amount == other.amount &&
          status == other.status;

  @override
  int get hashCode =>
      id.hashCode ^
      fromUid.hashCode ^
      toUid.hashCode ^
      amount.hashCode ^
      status.hashCode;
}
