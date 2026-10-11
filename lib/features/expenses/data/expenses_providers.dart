import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase_providers.dart';
import '../../trips/data/trips_providers.dart';
import '../../trips/domain/member.dart';
import '../domain/balance_calculator.dart';
import '../domain/expense.dart';
import 'expense_repository.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return ExpenseRepository(firestore: firestore);
});

/// Streams all expenses for a specific trip (sorted by date DESC, createdAt DESC).
final expensesStreamProvider =
    StreamProvider.family<List<Expense>, String>((ref, tripId) {
      final repository = ref.watch(expenseRepositoryProvider);
      return repository.watchExpenses(tripId);
    });

/// Derived provider computing net member balances for a trip from expenses and members streams.
final tripBalancesProvider = Provider.family<Map<String, int>, String>((
  ref,
  tripId,
) {
  final expensesAsync = ref.watch(expensesStreamProvider(tripId));
  final membersAsync = ref.watch(tripMembersProvider(tripId));

  final expenses = expensesAsync.asData?.value ?? const <Expense>[];
  final members = membersAsync.asData?.value ?? const <Member>[];

  return computeBalances(expenses, members);
});

/// Derived provider computing minimal suggested payments for a trip from balances.
final suggestedPaymentsProvider =
    Provider.family<List<SuggestedPayment>, String>((ref, tripId) {
      final balances = ref.watch(tripBalancesProvider(tripId));
      return suggestSettlements(balances);
    });

/// Derived provider computing total minor units spent across all trip expenses.
final totalTripSpentProvider = Provider.family<int, String>((ref, tripId) {
  final expensesAsync = ref.watch(expensesStreamProvider(tripId));
  final expenses = expensesAsync.asData?.value ?? const <Expense>[];
  return expenses.fold<int>(0, (sum, e) => sum + e.amount);
});
