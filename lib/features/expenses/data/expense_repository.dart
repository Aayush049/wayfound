import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/expense.dart';
import '../domain/expense_payload_builders.dart';

/// Client-side sorting function for expenses:
/// Primary sort: date DESC
/// Secondary sort: createdAt DESC
List<Expense> sortExpenses(List<Expense> expenses) {
  final list = List<Expense>.from(expenses);
  list.sort((a, b) {
    final dateComp = b.date.compareTo(a.date);
    if (dateComp != 0) return dateComp;
    return b.createdAt.compareTo(a.createdAt);
  });
  return list;
}

class ExpenseRepository {
  final FirebaseFirestore _firestore;

  ExpenseRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Streams expenses for a trip, sorted client-side by date DESC, then createdAt DESC.
  Stream<List<Expense>> watchExpenses(String tripId) {
    return _firestore
        .collection('trips')
        .doc(tripId)
        .collection('expenses')
        .snapshots()
        .map((snapshot) {
          final expenses =
              snapshot.docs.map((doc) => Expense.fromFirestore(doc)).toList();
          return sortExpenses(expenses);
        });
  }

  /// Creates a new expense document.
  Future<void> createExpense({
    required String tripId,
    required int amount,
    required String description,
    required String paidBy,
    required List<String> participantIds,
    required String createdBy,
    required DateTime date,
  }) async {
    final payload = ExpensePayloadBuilders.buildExpenseCreatePayload(
      amount: amount,
      description: description,
      paidBy: paidBy,
      participantIds: participantIds,
      createdBy: createdBy,
      date: date,
    );

    await _firestore
        .collection('trips')
        .doc(tripId)
        .collection('expenses')
        .add(payload);
  }

  /// Updates an existing expense document.
  Future<void> updateExpense({
    required String tripId,
    required String expenseId,
    required int amount,
    required String description,
    required String paidBy,
    required List<String> participantIds,
    required DateTime date,
  }) async {
    final payload = ExpensePayloadBuilders.buildExpenseUpdatePayload(
      amount: amount,
      description: description,
      paidBy: paidBy,
      participantIds: participantIds,
      date: date,
    );

    await _firestore
        .collection('trips')
        .doc(tripId)
        .collection('expenses')
        .doc(expenseId)
        .update(payload);
  }

  /// Deletes an expense document.
  Future<void> deleteExpense({
    required String tripId,
    required String expenseId,
  }) async {
    await _firestore
        .collection('trips')
        .doc(tripId)
        .collection('expenses')
        .doc(expenseId)
        .delete();
  }
}
