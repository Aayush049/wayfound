import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfound/core/firebase_providers.dart';
import 'package:wayfound/features/expenses/data/expenses_providers.dart';
import 'package:wayfound/features/expenses/domain/expense.dart';
import 'package:wayfound/features/expenses/presentation/add_edit_expense_screen.dart';
import 'package:wayfound/features/expenses/presentation/balances_view.dart';
import 'package:wayfound/features/expenses/presentation/expense_card.dart';
import 'package:wayfound/features/expenses/presentation/expense_split_sheet.dart';
import 'package:wayfound/features/expenses/presentation/expenses_tab.dart';
import 'package:wayfound/features/trips/data/trips_providers.dart';
import 'package:wayfound/features/trips/domain/member.dart';
import 'package:wayfound/features/trips/domain/trip.dart';

import 'helpers/pump_app.dart';

class MockUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? email;
  @override
  final String? displayName;
  @override
  final String? photoURL;

  MockUser({
    required this.uid,
    this.email = 'test@example.com',
    this.displayName = 'Test User',
    this.photoURL,
  });
}

void main() {
  late FakeFirebaseFirestore fakeFirestore;

  const tripId = 'trip_exp_ui';
  const organizerUid = 'user_org';
  const creatorUid = 'user_creator';
  const member2Uid = 'user_mem2';

  final now = DateTime(2026, 11, 2);

  final organizer = Member(
    uid: organizerUid,
    displayName: 'Organizer Asha',
    photoUrl: null,
    role: 'organizer',
    status: 'active',
    joinedAt: now,
  );

  final creator = Member(
    uid: creatorUid,
    displayName: 'Creator Ravi',
    photoUrl: null,
    role: 'member',
    status: 'active',
    joinedAt: now,
  );

  final member2 = Member(
    uid: member2Uid,
    displayName: 'Member Sam',
    photoUrl: null,
    role: 'member',
    status: 'active',
    joinedAt: now,
  );

  final members = [organizer, creator, member2];

  final activeTrip = Trip(
    id: tripId,
    name: 'Goa Vacation',
    destination: 'Goa',
    startDate: DateTime(2026, 11, 1),
    endDate: DateTime(2026, 11, 10),
    currency: 'INR',
    organizerId: organizerUid,
    joinCode: 'GOA123',
    memberIds: [organizerUid, creatorUid, member2Uid],
    memberCount: 3,
    archived: false,
    createdAt: now,
  );

  final archivedTrip = Trip(
    id: tripId,
    name: 'Goa Vacation Archived',
    destination: 'Goa',
    startDate: DateTime(2026, 11, 1),
    endDate: DateTime(2026, 11, 10),
    currency: 'INR',
    organizerId: organizerUid,
    joinCode: 'GOA123',
    memberIds: [organizerUid, creatorUid, member2Uid],
    memberCount: 3,
    archived: true,
    createdAt: now,
  );

  final jpyTrip = Trip(
    id: tripId,
    name: 'Tokyo Trip',
    destination: 'Tokyo',
    startDate: DateTime(2026, 11, 1),
    endDate: DateTime(2026, 11, 10),
    currency: 'JPY',
    organizerId: organizerUid,
    joinCode: 'TOK123',
    memberIds: [organizerUid, creatorUid, member2Uid],
    memberCount: 3,
    archived: false,
    createdAt: now,
  );

  final sampleExpense = Expense(
    id: 'exp_sample_1',
    amount: 90000, // ₹900.00
    description: 'Seafood Dinner',
    paidBy: creatorUid,
    participantIds: [organizerUid, creatorUid, member2Uid],
    createdBy: creatorUid,
    date: now,
    createdAt: now,
  );

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
  });

  group('ExpenseCard & ExpenseSplitSheet Widget Tests', () {
    testWidgets('ExpenseCard renders description, amount, payer, and count', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpenseCard(
              expense: sampleExpense,
              currency: 'INR',
              members: members,
              canManage: true,
            ),
          ),
        ),
      );

      expect(find.text('Seafood Dinner'), findsOneWidget);
      expect(find.textContaining('900.00'), findsOneWidget);
      expect(find.text('Paid by Creator Ravi · split among 3'), findsOneWidget);
      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    });

    testWidgets(
      'ExpenseCard hides overflow popup menu when canManage is false',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ExpenseCard(
                expense: sampleExpense,
                currency: 'INR',
                members: members,
                canManage: false,
              ),
            ),
          ),
        );

        expect(find.text('Seafood Dinner'), findsOneWidget);
        expect(find.byType(PopupMenuButton<String>), findsNothing);
      },
    );

    testWidgets(
      'Tapping ExpenseCard opens ExpenseSplitSheet with per-participant shares',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ExpenseCard(
                expense: sampleExpense,
                currency: 'INR',
                members: members,
                canManage: true,
              ),
            ),
          ),
        );

        await tester.tap(find.byType(ExpenseCard));
        await tester.pumpAndSettle();

        expect(find.byType(ExpenseSplitSheet), findsOneWidget);
        expect(find.text('Split Details (3 participants)'), findsOneWidget);
        expect(find.text('Organizer Asha'), findsOneWidget);
        expect(find.text('Creator Ravi'), findsOneWidget);
        expect(find.text('Member Sam'), findsOneWidget);
        // Each share = 90000 / 3 = 30000 = ₹300.00
        expect(find.textContaining('300.00'), findsNWidgets(3));
      },
    );

    testWidgets('Delete option in ExpenseCard shows confirmation dialog', (
      tester,
    ) async {
      bool deleteCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpenseCard(
              expense: sampleExpense,
              currency: 'INR',
              members: members,
              canManage: true,
              onDelete: () {
                deleteCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Expense?'), findsOneWidget);
      expect(
        find.text(
          'Are you sure you want to delete "Seafood Dinner"? This action cannot be undone.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(deleteCalled, isTrue);
    });
  });

  group('BalancesView Widget Tests', () {
    testWidgets(
      'BalancesView displays total spent, net balances with words, and suggested payments',
      (tester) async {
        final mockUser = MockUser(uid: creatorUid);

        await tester.pumpApp(
          Scaffold(body: BalancesView(trip: activeTrip)),
          authUserValue: AsyncData(mockUser),
          overrides: [
            firestoreProvider.overrideWithValue(fakeFirestore),
            tripMembersProvider(tripId).overrideWithValue(AsyncData(members)),
            tripAllMembersProvider(tripId)
                .overrideWithValue(AsyncData(members)),
            expensesStreamProvider(tripId)
                .overrideWithValue(AsyncData([sampleExpense])),
          ],
        );

        await tester.pumpAndSettle();

        // Total spent ₹900.00
        expect(find.text('Total Trip Spent'), findsOneWidget);
        expect(find.textContaining('900.00'), findsAtLeastNWidgets(1));

        // Creator Ravi paid 900, share 300 -> net balance +600.00 ("You are owed")
        expect(find.text('Your Balance'), findsOneWidget);
        expect(find.text('You are owed'), findsOneWidget);

        // Member balance rows
        expect(find.text('Member Balances'), findsOneWidget);
        expect(find.text('Organizer Asha'), findsOneWidget);
        expect(find.text('Creator Ravi (You)'), findsOneWidget);
        expect(find.text('Member Sam'), findsOneWidget);
        expect(find.text('owes'), findsNWidgets(2)); // Asha & Sam owe
        expect(find.text('is owed'), findsNWidgets(1)); // Ravi is owed

        // Suggested Payments section
        expect(find.text('Suggested Payments'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (w) => w is RichText && w.text.toPlainText().contains('pays'),
          ),
          findsNWidgets(2),
        );
      },
    );

    testWidgets(
      'BalancesView shows All Settled state when expenses are empty',
      (tester) async {
        final mockUser = MockUser(uid: creatorUid);

        await tester.pumpApp(
          Scaffold(body: BalancesView(trip: activeTrip)),
          authUserValue: AsyncData(mockUser),
          overrides: [
            firestoreProvider.overrideWithValue(fakeFirestore),
            tripMembersProvider(tripId).overrideWithValue(AsyncData(members)),
            expensesStreamProvider(tripId)
                .overrideWithValue(const AsyncData([])),
          ],
        );

        await tester.pumpAndSettle();

        expect(find.text('All Settled!'), findsOneWidget);
        expect(
          find.text('Everyone is at zero net balance. No payments needed.'),
          findsOneWidget,
        );
      },
    );
  });

  group('ExpensesTab Widget Tests', () {
    testWidgets('ExpensesTab empty state shows Add Expense action', (
      tester,
    ) async {
      final mockUser = MockUser(uid: creatorUid);

      await tester.pumpApp(
        Scaffold(body: ExpensesTab(trip: activeTrip)),
        authUserValue: AsyncData(mockUser),
        overrides: [
          firestoreProvider.overrideWithValue(fakeFirestore),
          tripMembersProvider(tripId).overrideWithValue(AsyncData(members)),
          expensesStreamProvider(tripId).overrideWithValue(const AsyncData([])),
        ],
      );

      await tester.pumpAndSettle();

      expect(find.text('No expenses yet'), findsOneWidget);
      expect(
        find.widgetWithText(FloatingActionButton, 'Add Expense'),
        findsOneWidget,
      );
    });

    testWidgets(
      'ExpensesTab on archived trip hides FAB and empty state action',
      (tester) async {
        final mockUser = MockUser(uid: creatorUid);

        await tester.pumpApp(
          Scaffold(body: ExpensesTab(trip: archivedTrip)),
          authUserValue: AsyncData(mockUser),
          overrides: [
            firestoreProvider.overrideWithValue(fakeFirestore),
            tripMembersProvider(tripId).overrideWithValue(AsyncData(members)),
            expensesStreamProvider(tripId)
                .overrideWithValue(const AsyncData([])),
          ],
        );

        await tester.pumpAndSettle();

        expect(find.text('No expenses yet'), findsOneWidget);
        expect(find.byType(FloatingActionButton), findsNothing);
      },
    );

    testWidgets('ExpensesTab toggles between Expenses and Balances views', (
      tester,
    ) async {
      final mockUser = MockUser(uid: creatorUid);

      await tester.pumpApp(
        Scaffold(body: ExpensesTab(trip: activeTrip)),
        authUserValue: AsyncData(mockUser),
        overrides: [
          firestoreProvider.overrideWithValue(fakeFirestore),
          tripMembersProvider(tripId).overrideWithValue(AsyncData(members)),
          expensesStreamProvider(tripId)
              .overrideWithValue(AsyncData([sampleExpense])),
        ],
      );

      await tester.pumpAndSettle();

      // Currently on Expenses segment
      expect(find.text('Seafood Dinner'), findsOneWidget);

      // Switch to Balances segment
      await tester.tap(find.text('Balances'));
      await tester.pumpAndSettle();

      expect(find.text('Total Trip Spent'), findsOneWidget);
      expect(find.text('Member Balances'), findsOneWidget);
    });
  });

  group('AddEditExpenseScreen Widget Tests & Live Share Preview', () {
    testWidgets(
      'AddEditExpenseScreen shows live share preview as amount changes',
      (tester) async {
        final mockUser = MockUser(uid: creatorUid);

        await tester.pumpApp(
          AddEditExpenseScreen(tripId: tripId),
          authUserValue: AsyncData(mockUser),
          overrides: [
            firestoreProvider.overrideWithValue(fakeFirestore),
            tripProvider(tripId).overrideWithValue(AsyncData(activeTrip)),
            tripMembersProvider(tripId).overrideWithValue(AsyncData(members)),
            expensesStreamProvider(tripId)
                .overrideWithValue(const AsyncData([])),
          ],
        );

        await tester.pumpAndSettle();

        expect(find.text('Add Expense'), findsAtLeastNWidgets(1));

        // Enter Description
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Description *'),
          'Beach Snacks',
        );

        // Enter Amount 300.00
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Amount *'),
          '300.00',
        );
        await tester.pumpAndSettle();

        // Live share preview card should appear
        expect(find.text('Live Share Preview'), findsOneWidget);
        // ₹300.00 split among 3 = ₹100.00 each
        expect(find.textContaining('100.00'), findsNWidgets(3));
      },
    );

    testWidgets(
      'AddEditExpenseScreen shows validation errors for invalid input',
      (tester) async {
        final mockUser = MockUser(uid: creatorUid);

        await tester.pumpApp(
          AddEditExpenseScreen(tripId: tripId),
          authUserValue: AsyncData(mockUser),
          overrides: [
            firestoreProvider.overrideWithValue(fakeFirestore),
            tripProvider(tripId).overrideWithValue(AsyncData(activeTrip)),
            tripMembersProvider(tripId).overrideWithValue(AsyncData(members)),
            expensesStreamProvider(tripId)
                .overrideWithValue(const AsyncData([])),
          ],
        );

        await tester.pumpAndSettle();

        // Scroll to submit button and tap with empty form
        final submitFinder = find.widgetWithText(FilledButton, 'Add Expense');
        await tester.ensureVisible(submitFinder);
        await tester.tap(submitFinder);
        await tester.pumpAndSettle();

        expect(find.text('Description is required'), findsOneWidget);
        expect(find.text('Amount is required'), findsOneWidget);
      },
    );

    testWidgets('JPY trip formats amounts with zero decimal places', (
      tester,
    ) async {
      final mockUser = MockUser(uid: creatorUid);

      await tester.pumpApp(
        AddEditExpenseScreen(tripId: tripId),
        authUserValue: AsyncData(mockUser),
        overrides: [
          firestoreProvider.overrideWithValue(fakeFirestore),
          tripProvider(tripId).overrideWithValue(AsyncData(jpyTrip)),
          tripMembersProvider(tripId).overrideWithValue(AsyncData(members)),
          expensesStreamProvider(tripId).overrideWithValue(const AsyncData([])),
        ],
      );

      await tester.pumpAndSettle();

      // Enter Amount 1500 JPY
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount *'),
        '1500',
      );
      await tester.pumpAndSettle();

      expect(find.text('Live Share Preview'), findsOneWidget);
      // 1500 / 3 = 500 JPY (no decimal places!)
      expect(find.textContaining('¥ 500'), findsNWidgets(3));
      expect(find.textContaining('.00'), findsNothing);
    });
  });

  group('Light and Dark Theme Smoke Test', () {
    testWidgets('ExpensesTab renders cleanly in both Light and Dark mode', (
      tester,
    ) async {
      final mockUser = MockUser(uid: creatorUid);

      // Light Mode
      await tester.pumpApp(
        Scaffold(body: ExpensesTab(trip: activeTrip)),
        authUserValue: AsyncData(mockUser),
        themeMode: ThemeMode.light,
        overrides: [
          firestoreProvider.overrideWithValue(fakeFirestore),
          tripMembersProvider(tripId).overrideWithValue(AsyncData(members)),
          expensesStreamProvider(tripId)
              .overrideWithValue(AsyncData([sampleExpense])),
        ],
      );
      await tester.pumpAndSettle();
      expect(find.text('Seafood Dinner'), findsOneWidget);

      // Dark Mode
      await tester.pumpApp(
        Scaffold(body: ExpensesTab(trip: activeTrip)),
        authUserValue: AsyncData(mockUser),
        themeMode: ThemeMode.dark,
        overrides: [
          firestoreProvider.overrideWithValue(fakeFirestore),
          tripMembersProvider(tripId).overrideWithValue(AsyncData(members)),
          expensesStreamProvider(tripId)
              .overrideWithValue(AsyncData([sampleExpense])),
        ],
      );
      await tester.pumpAndSettle();
      expect(find.text('Seafood Dinner'), findsOneWidget);
    });
  });
}
