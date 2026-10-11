import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:wayfound/features/expenses/domain/balance_calculator.dart';
import 'package:wayfound/features/expenses/domain/expense.dart';
import 'package:wayfound/features/expenses/domain/split_logic.dart';
import 'package:wayfound/features/trips/domain/member.dart';

void main() {
  group('Expense Domain Logic - splitEqually', () {
    test('splits 1000 among 3 participants with remainder given to first', () {
      // Participant UIDs sorted: 'Asha', 'Ravi', 'Sam'
      final shares = splitEqually(1000, ['Asha', 'Ravi', 'Sam']);
      expect(shares['Asha'], equals(334));
      expect(shares['Ravi'], equals(333));
      expect(shares['Sam'], equals(333));
      expect(shares.values.fold(0, (a, b) => a + b), equals(1000));
    });

    test('handles n = 1 participant', () {
      final shares = splitEqually(5000, ['user_1']);
      expect(shares['user_1'], equals(5000));
    });

    test('handles n = 15 participants', () {
      final participants = List.generate(15, (i) => 'uid_${i.toString().padLeft(2, '0')}');
      final shares = splitEqually(100, participants);
      // 100 ~/ 15 = 6, remainder 10
      // First 10 get 7, last 5 get 6
      expect(shares.values.fold(0, (a, b) => a + b), equals(100));
      expect(shares.values.where((v) => v == 7).length, equals(10));
      expect(shares.values.where((v) => v == 6).length, equals(5));
    });

    test('handles amount smaller than n (some shares 0)', () {
      final shares = splitEqually(2, ['uid_c', 'uid_a', 'uid_b', 'uid_d']);
      // Sorted: uid_a, uid_b, uid_c, uid_d
      // 2 ~/ 4 = 0, remainder 2 -> uid_a=1, uid_b=1, uid_c=0, uid_d=0
      expect(shares['uid_a'], equals(1));
      expect(shares['uid_b'], equals(1));
      expect(shares['uid_c'], equals(0));
      expect(shares['uid_d'], equals(0));
      expect(shares.values.fold(0, (a, b) => a + b), equals(2));
    });

    test('empty participant list returns empty map', () {
      final shares = splitEqually(1000, []);
      expect(shares, isEmpty);
    });
  });

  group('Expense Domain Logic - computeBalances & suggestSettlements', () {
    final now = DateTime.now();
    final asha = Member(
      uid: 'asha',
      displayName: 'Asha',
      photoUrl: null,
      role: 'organizer',
      status: 'active',
      joinedAt: now,
    );
    final ravi = Member(
      uid: 'ravi',
      displayName: 'Ravi',
      photoUrl: null,
      role: 'member',
      status: 'active',
      joinedAt: now,
    );
    final sam = Member(
      uid: 'sam',
      displayName: 'Sam',
      photoUrl: null,
      role: 'member',
      status: 'active',
      joinedAt: now,
    );
    final members = [asha, ravi, sam];

    test('Report 8.5 Worked Example: Dinner 900 by Asha, Cab 300 by Ravi', () {
      final dinner = Expense(
        id: 'exp1',
        amount: 900,
        description: 'Dinner',
        paidBy: 'asha',
        participantIds: ['asha', 'ravi', 'sam'],
        createdBy: 'asha',
        date: now,
        createdAt: now,
      );

      final cab = Expense(
        id: 'exp2',
        amount: 300,
        description: 'Cab',
        paidBy: 'ravi',
        participantIds: ['asha', 'ravi', 'sam'],
        createdBy: 'ravi',
        date: now,
        createdAt: now,
      );

      final balances = computeBalances([dinner, cab], members);

      // Asha: +900 - 300 (dinner) - 100 (cab) = +500
      // Ravi: -300 (dinner) + 300 - 100 (cab) = -100
      // Sam: -300 (dinner) - 100 (cab) = -400
      expect(balances['asha'], equals(500));
      expect(balances['ravi'], equals(-100));
      expect(balances['sam'], equals(-400));

      final totalSum = balances.values.fold(0, (a, b) => a + b);
      expect(totalSum, equals(0));

      final suggestions = suggestSettlements(balances);
      // Expected: Sam pays Asha 400, Ravi pays Asha 100
      expect(suggestions.length, equals(2));
      expect(
        suggestions,
        contains(const SuggestedPayment(fromUid: 'sam', toUid: 'asha', amount: 400)),
      );
      expect(
        suggestions,
        contains(const SuggestedPayment(fromUid: 'ravi', toUid: 'asha', amount: 100)),
      );
    });

    test('Payer who is NOT a participant', () {
      // Asha pays 600 for a gift split between Ravi and Sam only
      final gift = Expense(
        id: 'exp3',
        amount: 600,
        description: 'Gift',
        paidBy: 'asha',
        participantIds: ['ravi', 'sam'],
        createdBy: 'asha',
        date: now,
        createdAt: now,
      );

      final balances = computeBalances([gift], members);
      expect(balances['asha'], equals(600));
      expect(balances['ravi'], equals(-300));
      expect(balances['sam'], equals(-300));
      expect(balances.values.fold(0, (a, b) => a + b), equals(0));
    });

    test('Payer who IS a participant in single-person expense', () {
      final solo = Expense(
        id: 'exp4',
        amount: 500,
        description: 'Solo Snack',
        paidBy: 'asha',
        participantIds: ['asha'],
        createdBy: 'asha',
        date: now,
        createdAt: now,
      );

      final balances = computeBalances([solo], members);
      expect(balances['asha'], equals(0));
      expect(balances['ravi'], equals(0));
      expect(balances['sam'], equals(0));
      expect(balances.values.fold(0, (a, b) => a + b), equals(0));
    });

    test('Confirmed settlements reduce balances', () {
      final dinner = Expense(
        id: 'exp1',
        amount: 900,
        description: 'Dinner',
        paidBy: 'asha',
        participantIds: ['asha', 'ravi', 'sam'],
        createdBy: 'asha',
        date: now,
        createdAt: now,
      );

      // Sam pays Asha 400 outside app, confirmed
      final settlement = const ConfirmedSettlementInput(
        fromUid: 'sam',
        toUid: 'asha',
        amount: 400,
      );

      final balances = computeBalances([dinner], members, confirmedSettlements: [settlement]);
      // Asha: +900 - 300 + 400 = +1000... wait:
      // Dinner: Asha paid 900, share 300 -> net +600.
      // Settlement: Sam paid Asha 400 -> Asha gets +400?
      // Wait! For confirmed settlement: payer (fromUid = Sam) gets +amount, receiver (toUid = Asha) gets -amount.
      // So Sam's debt (-300) improves by +400 to +100 (overpaid by 100).
      // Asha's credit (+600) decreases by -400 to +200.
      expect(balances['asha'], equals(200));
      expect(balances['sam'], equals(100));
      expect(balances['ravi'], equals(-300));
      expect(balances.values.fold(0, (a, b) => a + b), equals(0));
    });

    test('Partial settlement scenario', () {
      final dinner = Expense(
        id: 'exp1',
        amount: 900,
        description: 'Dinner',
        paidBy: 'asha',
        participantIds: ['asha', 'ravi', 'sam'],
        createdBy: 'asha',
        date: now,
        createdAt: now,
      );

      // Sam pays Asha 200 (partial of 300)
      final partial = const ConfirmedSettlementInput(
        fromUid: 'sam',
        toUid: 'asha',
        amount: 200,
      );

      final balances = computeBalances([dinner], members, confirmedSettlements: [partial]);
      // Asha net: +600 - 200 = +400
      // Sam net: -300 + 200 = -100
      // Ravi net: -300
      expect(balances['asha'], equals(400));
      expect(balances['sam'], equals(-100));
      expect(balances['ravi'], equals(-300));
      expect(balances.values.fold(0, (a, b) => a + b), equals(0));

      final suggested = suggestSettlements(balances);
      expect(suggested.length, equals(2));
      // Debtors: ravi (-300), sam (-100). Creditor: asha (+400).
      // Ravi pays Asha 300, Sam pays Asha 100.
      expect(
        suggested,
        contains(const SuggestedPayment(fromUid: 'ravi', toUid: 'asha', amount: 300)),
      );
      expect(
        suggested,
        contains(const SuggestedPayment(fromUid: 'sam', toUid: 'asha', amount: 100)),
      );
    });

    test('Empty expenses list returns zero balances', () {
      final balances = computeBalances([], members);
      expect(balances['asha'], equals(0));
      expect(balances['ravi'], equals(0));
      expect(balances['sam'], equals(0));
      expect(suggestSettlements(balances), isEmpty);
    });

    test('One member trip returns zero balances', () {
      final singleMember = [asha];
      final exp = Expense(
        id: 'exp_single',
        amount: 1500,
        description: 'Hotel',
        paidBy: 'asha',
        participantIds: ['asha'],
        createdBy: 'asha',
        date: now,
        createdAt: now,
      );
      final balances = computeBalances([exp], singleMember);
      expect(balances['asha'], equals(0));
      expect(suggestSettlements(balances), isEmpty);
    });
  });

  group('Expense Domain Logic - Seeded Random Property Tests (200 cases)', () {
    test('200 random property test iterations for split, balances and settlements', () {
      final rand = Random(42); // Seeded for deterministic reproducibility

      for (var iteration = 0; iteration < 200; iteration++) {
        final numMembers = rand.nextInt(15) + 1; // 1 to 15 members
        final memberUids = List.generate(
          numMembers,
          (i) => 'uid_${i.toString().padLeft(2, '0')}',
        );
        final members = memberUids
            .map(
              (u) => Member(
                uid: u,
                displayName: 'Member $u',
                photoUrl: null,
                role: 'member',
                status: 'active',
                joinedAt: DateTime.now(),
              ),
            )
            .toList();

        final numExpenses = rand.nextInt(20); // 0 to 19 expenses
        final expenses = <Expense>[];

        for (var e = 0; e < numExpenses; e++) {
          final amount = rand.nextInt(100000) + 1; // 1 to 100,000 minor units
          final paidBy = memberUids[rand.nextInt(numMembers)];

          // Select random subset of 1 to 15 distinct participants
          final numParticipants = rand.nextInt(numMembers) + 1;
          final shuffled = List<String>.from(memberUids)..shuffle(rand);
          final participantIds = shuffled.sublist(0, numParticipants);

          // Test 1: Property check for splitEqually sum
          final shares = splitEqually(amount, participantIds);
          final sharesSum = shares.values.fold(0, (a, b) => a + b);
          expect(
            sharesSum,
            equals(amount),
            reason: 'Iteration $iteration expense $e shares sum must equal amount',
          );

          expenses.add(
            Expense(
              id: 'exp_$e',
              amount: amount,
              description: 'Random expense $e',
              paidBy: paidBy,
              participantIds: participantIds,
              createdBy: paidBy,
              date: DateTime.now(),
              createdAt: DateTime.now(),
            ),
          );
        }

        // Test 2: Property check for computeBalances sum = 0
        final balances = computeBalances(expenses, members);
        final netSum = balances.values.fold(0, (a, b) => a + b);
        expect(
          netSum,
          equals(0),
          reason: 'Iteration $iteration net balances sum must equal 0',
        );

        final nonZeroCount = balances.values.where((v) => v != 0).length;

        // Test 3: Property checks for suggestSettlements
        final suggestedPayments = suggestSettlements(balances);

        if (nonZeroCount > 0) {
          expect(
            suggestedPayments.length,
            lessThanOrEqualTo(nonZeroCount - 1),
            reason: 'Iteration $iteration payments count must be <= nonZeroCount - 1',
          );
        } else {
          expect(
            suggestedPayments,
            isEmpty,
            reason: 'Iteration $iteration when all balances zero, payments must be empty',
          );
        }

        // Test 4 & 5: Positive payments and applying payments settles all balances to 0
        final testWorkingBalances = Map<String, int>.from(balances);
        for (final p in suggestedPayments) {
          expect(
            p.amount,
            greaterThan(0),
            reason: 'Iteration $iteration payment amount must be strictly positive (> 0)',
          );

          testWorkingBalances[p.fromUid] = testWorkingBalances[p.fromUid]! + p.amount;
          testWorkingBalances[p.toUid] = testWorkingBalances[p.toUid]! - p.amount;
        }

        for (final entry in testWorkingBalances.entries) {
          expect(
            entry.value,
            equals(0),
            reason:
                'Iteration $iteration after applying all suggested payments, member ${entry.key} balance must be 0',
          );
        }
      }
    });
  });
}
