import 'package:flutter_test/flutter_test.dart';
import 'package:wayfound/core/money.dart';
import 'package:wayfound/features/expenses/domain/balance_calculator.dart';
import 'package:wayfound/features/expenses/domain/expense.dart';
import 'package:wayfound/features/settlements/domain/leave_eligibility.dart';
import 'package:wayfound/features/settlements/domain/settlement.dart';
import 'package:wayfound/features/settlements/domain/settlement_validators.dart';
import 'package:wayfound/features/trips/domain/member.dart';

void main() {
  group('Settlement Validators Tests', () {
    test('validateSettlementAmount validates correct amounts and errors', () {
      // USD supports 2 decimals
      expect(validateSettlementAmount('10.50', 'USD', 2000), null);
      expect(
        validateSettlementAmount('0', 'USD', 2000),
        'Amount must be greater than zero.',
      );
      expect(
        validateSettlementAmount('-5', 'USD', 2000),
        'Amount cannot be negative.',
      );
      expect(
        validateSettlementAmount('abc', 'USD', 2000),
        'Invalid number format.',
      );
      expect(
        validateSettlementAmount('10.555', 'USD', 2000),
        'Amount cannot have more than 2 decimal places.',
      );

      // JPY supports 0 decimals
      expect(validateSettlementAmount('1000', 'JPY', 5000), null);
      expect(
        validateSettlementAmount('10.5', 'JPY', 5000),
        'JPY does not support decimal amounts.',
      );
    });

    test('tryParseMinorUnits parses currency amounts correctly', () {
      final (val1, err1) = tryParseMinorUnits('10.50', 'USD');
      expect(val1, 1050);
      expect(err1, null);

      final (val2, err2) = tryParseMinorUnits('1000', 'JPY');
      expect(val2, 1000);
      expect(err2, null);

      final (_, err3) = tryParseMinorUnits('invalid', 'USD');
      expect(err3, isNotNull);
    });
  });

  group('Leave Eligibility Tests', () {
    test('Organizer cannot leave', () {
      final res = checkLeaveEligibility(
        uid: 'u1',
        organizerId: 'u1',
        balances: {'u1': 0, 'u2': 0},
        settlements: [],
        currencyCode: 'USD',
      );
      expect(res.allowed, false);
      expect(res.reason, "Organizers can't leave a trip in this version.");
    });

    test('Member with nonzero balance cannot leave', () {
      final res = checkLeaveEligibility(
        uid: 'u2',
        organizerId: 'u1',
        balances: {'u1': 500, 'u2': -500},
        settlements: [],
        currencyCode: 'USD',
      );
      expect(res.allowed, false);
      expect(res.reason?.contains('nonzero balance'), true);
    });

    test('Member with nonzero balance cannot leave - formatted currency (D4 unit)', () {
      // USD owe
      final resUsdOwe = checkLeaveEligibility(
        uid: 'u2',
        organizerId: 'u1',
        balances: {'u1': 3500, 'u2': -3500},
        settlements: [],
        currencyCode: 'USD',
      );
      expect(resUsdOwe.allowed, false);
      expect(resUsdOwe.reason, contains('Cannot leave while you have a nonzero balance'));
      expect(resUsdOwe.reason, contains('you owe'));
      expect(resUsdOwe.reason, contains('35.00'));
      expect(resUsdOwe.reason, isNot(contains('minor units')));

      // USD is owed
      final resUsdOwed = checkLeaveEligibility(
        uid: 'u2',
        organizerId: 'u1',
        balances: {'u1': -3500, 'u2': 3500},
        settlements: [],
        currencyCode: 'USD',
      );
      expect(resUsdOwed.allowed, false);
      expect(resUsdOwed.reason, contains('you are owed'));
      expect(resUsdOwed.reason, contains('35.00'));
      expect(resUsdOwed.reason, isNot(contains('minor units')));

      // JPY zero-decimal owe
      final resJpyOwe = checkLeaveEligibility(
        uid: 'u2',
        organizerId: 'u1',
        balances: {'u1': 500, 'u2': -500},
        settlements: [],
        currencyCode: 'JPY',
      );
      expect(resJpyOwe.allowed, false);
      expect(resJpyOwe.reason, contains('you owe'));
      expect(resJpyOwe.reason, contains('500'));
      expect(resJpyOwe.reason, isNot(contains('minor units')));

      // JPY zero-decimal is owed
      final resJpyOwed = checkLeaveEligibility(
        uid: 'u2',
        organizerId: 'u1',
        balances: {'u1': -500, 'u2': 500},
        settlements: [],
        currencyCode: 'JPY',
      );
      expect(resJpyOwed.allowed, false);
      expect(resJpyOwed.reason, contains('you are owed'));
      expect(resJpyOwed.reason, contains('500'));
      expect(resJpyOwed.reason, isNot(contains('minor units')));
    });

    test('Member with pending settlements cannot leave', () {
      final res = checkLeaveEligibility(
        uid: 'u2',
        organizerId: 'u1',
        balances: {'u1': 0, 'u2': 0},
        settlements: [
          Settlement(
            id: 's1',
            fromUid: 'u2',
            toUid: 'u1',
            amount: 100,
            status: SettlementStatus.pending,
            createdAt: DateTime.now(),
          ),
        ],
        currencyCode: 'USD',
      );
      expect(res.allowed, false);
      expect(res.reason?.contains('pending settlements'), true);
    });

    test('Member with zero balance and no pending settlements can leave', () {
      final res = checkLeaveEligibility(
        uid: 'u2',
        organizerId: 'u1',
        balances: {'u1': 0, 'u2': 0},
        settlements: [],
        currencyCode: 'USD',
      );
      expect(res.allowed, true);
      expect(res.reason, null);
    });
  });

  group('Balances with Confirmed Settlements Tests', () {
    test('Confirmed settlements reduce net debt balances', () {
      final now = DateTime.now();
      final members = [
        Member(
          uid: 'u1',
          displayName: 'Alice',
          role: 'organizer',
          status: 'active',
        ),
        Member(uid: 'u2', displayName: 'Bob', role: 'member', status: 'active'),
      ];

      // Alice paid 1000 split equally: u1: +500, u2: -500
      final expenses = [
        Expense(
          id: 'e1',
          amount: 1000,
          description: 'Dinner',
          paidBy: 'u1',
          participantIds: ['u1', 'u2'],
          createdBy: 'u1',
          date: now,
          createdAt: now,
        ),
      ];

      // Initially u2 owes u1 500
      var balances = computeBalances(expenses, members);
      expect(balances['u1'], 500);
      expect(balances['u2'], -500);

      // Confirmed settlement: u2 paid u1 500
      final confirmedSettlements = [
        ConfirmedSettlementInput(fromUid: 'u2', toUid: 'u1', amount: 500),
      ];

      balances = computeBalances(
        expenses,
        members,
        confirmedSettlements: confirmedSettlements,
      );
      expect(balances['u1'], 0);
      expect(balances['u2'], 0);

      final suggested = suggestSettlements(balances);
      expect(suggested, isEmpty);
    });
  });
}
