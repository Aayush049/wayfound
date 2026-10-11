import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfound/core/firebase_providers.dart';
import 'package:wayfound/features/expenses/presentation/add_edit_expense_screen.dart';
import 'package:wayfound/features/trips/data/trips_providers.dart';
import 'package:wayfound/features/trips/domain/member.dart';
import 'package:wayfound/features/trips/domain/trip.dart';

import '../helpers/pump_app.dart';

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

  const tripId = 'trip_exp_form';
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

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
  });

  group('AddEditExpenseScreen Input Validation Tests', () {
    testWidgets(
      'Amount field validates invalid inputs (-5, abc, 10.999, 1,000, 1e3, empty) without throwing FormatException',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 1600);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final mockUser = MockUser(uid: creatorUid);

        // Test INR trip first
        await tester.pumpApp(
          const AddEditExpenseScreen(tripId: tripId),
          authUserValue: AsyncData(mockUser),
          overrides: [
            firestoreProvider.overrideWithValue(fakeFirestore),
            tripProvider(tripId).overrideWithValue(AsyncData(activeTrip)),
            tripMembersProvider(tripId).overrideWithValue(AsyncData(members)),
          ],
        );

        await tester.pumpAndSettle();

        // Verify screen is loaded
        expect(find.text('Add Expense'), findsNWidgets(2));

        final amountField = find.byType(TextFormField).at(1);

        // Test cases: input string and expected error text
        final testCases = [
          ('-5', 'Amount cannot be negative.'),
          ('abc', 'Invalid number format.'),
          ('10.999', 'Amount cannot have more than 2 decimal places.'),
          ('1,000', 'Invalid number format.'),
          ('1e3', 'Invalid number format.'),
          ('', 'Amount is required'),
          ('   ', 'Amount is required'),
        ];

        for (final tc in testCases) {
          final input = tc.$1;
          final expectedError = tc.$2;

          await tester.enterText(amountField, input);
          await tester.pumpAndSettle();

          // Try submitting
          await tester.tap(find.widgetWithText(FilledButton, 'Add Expense'));
          await tester.pumpAndSettle();

          // Assert tester.takeException() is null (no unhandled FormatException escape)
          expect(tester.takeException(), isNull);

          // Assert expected error text is shown (either via validator error or snackbar)
          expect(
            find.text(expectedError),
            findsAtLeastNWidgets(1),
            reason: 'Failed for input: "$input"',
          );
        }
      },
    );

    testWidgets('JPY trip validates decimal amounts correctly', (tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockUser = MockUser(uid: creatorUid);

      await tester.pumpApp(
        const AddEditExpenseScreen(tripId: tripId),
        authUserValue: AsyncData(mockUser),
        overrides: [
          firestoreProvider.overrideWithValue(fakeFirestore),
          tripProvider(tripId).overrideWithValue(AsyncData(jpyTrip)),
          tripMembersProvider(tripId).overrideWithValue(AsyncData(members)),
        ],
      );

      await tester.pumpAndSettle();

      final amountField = find.byType(TextFormField).at(1);

      // JPY does not support decimals
      await tester.enterText(amountField, '10.5');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Add Expense'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.text('JPY does not support decimal amounts.'),
        findsAtLeastNWidgets(1),
      );

      // Valid JPY amount works
      await tester.enterText(amountField, '1500');
      await tester.pumpAndSettle();

      expect(find.text('JPY does not support decimal amounts.'), findsNothing);
    });

    testWidgets('Live share preview hides when amount is invalid or zero', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockUser = MockUser(uid: creatorUid);

      await tester.pumpApp(
        const AddEditExpenseScreen(tripId: tripId),
        authUserValue: AsyncData(mockUser),
        overrides: [
          firestoreProvider.overrideWithValue(fakeFirestore),
          tripProvider(tripId).overrideWithValue(AsyncData(activeTrip)),
          tripMembersProvider(tripId).overrideWithValue(AsyncData(members)),
        ],
      );

      await tester.pumpAndSettle();

      final amountField = find.byType(TextFormField).at(1);

      // Initially no live share preview card
      expect(find.text('Live Share Preview'), findsNothing);

      // Enter invalid amount
      await tester.enterText(amountField, 'abc');
      await tester.pumpAndSettle();
      expect(find.text('Live Share Preview'), findsNothing);

      // Enter zero amount
      await tester.enterText(amountField, '0');
      await tester.pumpAndSettle();
      expect(find.text('Live Share Preview'), findsNothing);

      // Enter valid amount
      await tester.enterText(amountField, '900');
      await tester.pumpAndSettle();
      expect(find.text('Live Share Preview'), findsOneWidget);
      expect(find.text('Creator Ravi'), findsOneWidget);
      expect(find.text('₹ 300.00'), findsNWidgets(3));
    });
  });
}
