import 'package:cloud_firestore/cloud_firestore.dart';

/// Payload builders for expense Firestore documents enforcing exact key sets.
class ExpensePayloadBuilders {
  /// Builds payload for `create` operation with EXACT 7 keys:
  /// amount, description, paidBy, participantIds, createdBy, date, createdAt
  static Map<String, dynamic> buildExpenseCreatePayload({
    required int amount,
    required String description,
    required String paidBy,
    required List<String> participantIds,
    required String createdBy,
    required DateTime date,
  }) {
    // Standardize date to UTC midnight for date-only consistency
    final utcDate = DateTime.utc(date.year, date.month, date.day);
    return {
      'amount': amount,
      'description': description.trim(),
      'paidBy': paidBy,
      'participantIds': List<String>.from(participantIds),
      'createdBy': createdBy,
      'date': Timestamp.fromDate(utcDate),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// Builds payload for `update` operation with EXACT 5 keys:
  /// amount, description, paidBy, participantIds, date
  static Map<String, dynamic> buildExpenseUpdatePayload({
    required int amount,
    required String description,
    required String paidBy,
    required List<String> participantIds,
    required DateTime date,
  }) {
    final utcDate = DateTime.utc(date.year, date.month, date.day);
    return {
      'amount': amount,
      'description': description.trim(),
      'paidBy': paidBy,
      'participantIds': List<String>.from(participantIds),
      'date': Timestamp.fromDate(utcDate),
    };
  }
}
