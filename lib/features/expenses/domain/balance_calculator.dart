import 'dart:math';

import '../../trips/domain/member.dart';
import 'expense.dart';
import 'split_logic.dart';

/// Pure data class representing a confirmed settlement input for balance calculations.
class ConfirmedSettlementInput {
  final String fromUid;
  final String toUid;
  final int amount;

  const ConfirmedSettlementInput({
    required this.fromUid,
    required this.toUid,
    required this.amount,
  });
}

/// Pure data class representing a suggested settlement payment.
class SuggestedPayment {
  final String fromUid;
  final String toUid;
  final int amount;

  const SuggestedPayment({
    required this.fromUid,
    required this.toUid,
    required this.amount,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SuggestedPayment &&
          runtimeType == other.runtimeType &&
          fromUid == other.fromUid &&
          toUid == other.toUid &&
          amount == other.amount;

  @override
  int get hashCode => fromUid.hashCode ^ toUid.hashCode ^ amount.hashCode;

  @override
  String toString() => 'SuggestedPayment($fromUid pays $toUid $amount)';
}

/// Computes net balance for each member given a list of expenses and confirmed settlements.
///
/// Net balance calculation:
/// - For each expense:
///   - Payer (`paidBy`) gets `+amount`
///   - Each participant gets `-share` (computed via [splitEqually])
/// - For each confirmed settlement:
///   - Payer (`fromUid`) gets `+amount`
///   - Receiver (`toUid`) gets `-amount`
///
/// Returns a map of `uid -> netBalance` (positive = owed money, negative = owes money).
Map<String, int> computeBalances(
  List<Expense> expenses,
  List<Member> members, {
  List<ConfirmedSettlementInput> confirmedSettlements = const [],
}) {
  final balances = <String, int>{};

  // Initialize all active members to 0 balance
  for (final m in members) {
    balances[m.uid] = 0;
  }

  // Account for expenses
  for (final expense in expenses) {
    // Ensure payer and participants are present in the balance map
    balances.putIfAbsent(expense.paidBy, () => 0);
    balances[expense.paidBy] = (balances[expense.paidBy]!) + expense.amount;

    final shares = splitEqually(expense.amount, expense.participantIds);
    for (final entry in shares.entries) {
      final pUid = entry.key;
      final share = entry.value;
      balances.putIfAbsent(pUid, () => 0);
      balances[pUid] = (balances[pUid]!) - share;
    }
  }

  // Account for confirmed settlements
  for (final settlement in confirmedSettlements) {
    balances.putIfAbsent(settlement.fromUid, () => 0);
    balances[settlement.fromUid] =
        (balances[settlement.fromUid]!) + settlement.amount;

    balances.putIfAbsent(settlement.toUid, () => 0);
    balances[settlement.toUid] =
        (balances[settlement.toUid]!) - settlement.amount;
  }

  return balances;
}

/// Computes minimal suggested payments to settle all debts.
///
/// Uses greedy algorithm: pairs largest debtor (most negative balance) with
/// largest creditor (most positive balance).
/// Deterministic tie-breaking by UID.
/// Returns at most `(non-zero balance members - 1)` payments.
List<SuggestedPayment> suggestSettlements(Map<String, int> balances) {
  final working = Map<String, int>.from(balances);
  final payments = <SuggestedPayment>[];

  while (true) {
    // Find debtors (balance < 0) and creditors (balance > 0)
    MapEntry<String, int>? maxDebtor;
    MapEntry<String, int>? maxCreditor;

    for (final entry in working.entries) {
      if (entry.value < 0) {
        if (maxDebtor == null) {
          maxDebtor = entry;
        } else {
          // More negative, or tie-break by uid ascending
          if (entry.value < maxDebtor.value) {
            maxDebtor = entry;
          } else if (entry.value == maxDebtor.value &&
              entry.key.compareTo(maxDebtor.key) < 0) {
            maxDebtor = entry;
          }
        }
      } else if (entry.value > 0) {
        if (maxCreditor == null) {
          maxCreditor = entry;
        } else {
          // More positive, or tie-break by uid ascending
          if (entry.value > maxCreditor.value) {
            maxCreditor = entry;
          } else if (entry.value == maxCreditor.value &&
              entry.key.compareTo(maxCreditor.key) < 0) {
            maxCreditor = entry;
          }
        }
      }
    }

    if (maxDebtor == null || maxCreditor == null) {
      break;
    }

    final debtorUid = maxDebtor.key;
    final creditorUid = maxCreditor.key;
    final debtAmount = maxDebtor.value.abs();
    final creditAmount = maxCreditor.value;

    final payAmount = min(debtAmount, creditAmount);
    payments.add(SuggestedPayment(
      fromUid: debtorUid,
      toUid: creditorUid,
      amount: payAmount,
    ));

    working[debtorUid] = working[debtorUid]! + payAmount;
    working[creditorUid] = working[creditorUid]! - payAmount;
  }

  return payments;
}
