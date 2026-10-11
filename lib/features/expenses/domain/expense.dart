import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  final String id;
  final int amount;
  final String description;
  final String paidBy;
  final List<String> participantIds;
  final String createdBy;
  final DateTime date;
  final DateTime createdAt;

  const Expense({
    required this.id,
    required this.amount,
    required this.description,
    required this.paidBy,
    required this.participantIds,
    required this.createdBy,
    required this.date,
    required this.createdAt,
  });

  factory Expense.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Expense.fromMap(data, doc.id);
  }

  factory Expense.fromMap(Map<String, dynamic> data, String id) {
    final dateVal = data['date'];
    final createdAtVal = data['createdAt'];

    DateTime parseTimestamp(dynamic val) {
      if (val is Timestamp) {
        return val.toDate();
      } else if (val is DateTime) {
        return val;
      }
      return DateTime.now();
    }

    return Expense(
      id: id,
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      description: (data['description'] as String?) ?? '',
      paidBy: (data['paidBy'] as String?) ?? '',
      participantIds:
          (data['participantIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      createdBy: (data['createdBy'] as String?) ?? '',
      date: parseTimestamp(dateVal),
      createdAt: parseTimestamp(createdAtVal),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'amount': amount,
      'description': description,
      'paidBy': paidBy,
      'participantIds': participantIds,
      'createdBy': createdBy,
      'date': Timestamp.fromDate(date),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Expense copyWith({
    String? id,
    int? amount,
    String? description,
    String? paidBy,
    List<String>? participantIds,
    String? createdBy,
    DateTime? date,
    DateTime? createdAt,
  }) {
    return Expense(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      paidBy: paidBy ?? this.paidBy,
      participantIds: participantIds ?? this.participantIds,
      createdBy: createdBy ?? this.createdBy,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
