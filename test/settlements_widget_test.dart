import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfound/features/expenses/data/expenses_providers.dart';
import 'package:wayfound/features/expenses/domain/balance_calculator.dart';
import 'package:wayfound/features/expenses/domain/expense.dart';
import 'package:wayfound/features/expenses/presentation/balances_view.dart';
import 'package:wayfound/features/expenses/presentation/expense_card.dart';
import 'package:wayfound/features/settlements/data/settlement_repository.dart';
import 'package:wayfound/features/settlements/data/settlements_providers.dart';
import 'package:wayfound/features/settlements/domain/settlement.dart';
import 'package:wayfound/features/trips/data/trip_repository.dart';
import 'package:wayfound/features/trips/data/trips_providers.dart';
import 'package:wayfound/features/trips/domain/member.dart';
import 'package:wayfound/features/trips/domain/trip.dart';
import 'package:wayfound/features/trips/presentation/join_trip_screen.dart';
import 'package:wayfound/features/trips/presentation/members_tab.dart';

import 'helpers/pump_app.dart';

void main() {
  final now = DateTime(2026, 11, 1);
  final activeTrip = Trip(
    id: 'trip_p6',
    name: 'Paris Trip',
    destination: 'Paris',
    startDate: now,
    endDate: now.add(const Duration(days: 4)),
    currency: 'USD',
    organizerId: 'org_user',
    joinCode: 'ABC234',
    memberIds: ['org_user', 'mem_alice', 'mem_bob'],
    memberCount: 3,
    archived: false,
  );

  final archivedTrip = Trip(
    id: 'trip_archived',
    name: 'Rome Trip',
    destination: 'Rome',
    startDate: now,
    endDate: now.add(const Duration(days: 4)),
    currency: 'USD',
    organizerId: 'org_user',
    joinCode: 'ROM123',
    memberIds: ['org_user', 'mem_alice'],
    memberCount: 2,
    archived: true,
  );

  final orgMember = Member(
    uid: 'org_user',
    displayName: 'Organizer Dan',
    role: 'organizer',
    status: 'active',
    joinedAt: now,
  );

  final aliceMember = Member(
    uid: 'mem_alice',
    displayName: 'Alice Member',
    role: 'member',
    status: 'active',
    joinedAt: now,
  );

  final bobLeftMember = Member(
    uid: 'mem_bob',
    displayName: 'Bob Left',
    role: 'member',
    status: 'left',
    joinedAt: now,
  );

  group('Widget Tests (W1 - W10)', () {
    testWidgets(
      'W1 Role visibility: organizer sees Remove-member actions and not Leave; plain member sees Leave and not Remove',
      (tester) async {
        final mockOrg = MockUser(
          uid: 'org_user',
          email: 'org@test.com',
          displayName: 'Organizer Dan',
        );
        final mockAlice = MockUser(
          uid: 'mem_alice',
          email: 'alice@test.com',
          displayName: 'Alice Member',
        );

        // 1. Organizer perspective
        await tester.pumpApp(
          Scaffold(body: MembersTab(trip: activeTrip)),
          authUserValue: AsyncData(mockOrg),
          overrides: [
            tripMembersProvider(activeTrip.id)
                .overrideWithValue(AsyncData([orgMember, aliceMember])),
            tripBalancesProvider(activeTrip.id)
                .overrideWithValue({'org_user': 0, 'mem_alice': 0}),
            settlementsStreamProvider(activeTrip.id)
                .overrideWithValue(const AsyncData([])),
          ],
        );

        // Organizer sees "Remove" button on plain member
        expect(find.text('Remove'), findsOneWidget);
        // Organizer DOES NOT see "Leave Trip" button
        expect(find.text('Leave Trip'), findsNothing);

        // 2. Positive control: Plain member perspective
        await tester.pumpApp(
          Scaffold(body: MembersTab(trip: activeTrip)),
          authUserValue: AsyncData(mockAlice),
          overrides: [
            tripMembersProvider(activeTrip.id)
                .overrideWithValue(AsyncData([orgMember, aliceMember])),
            tripBalancesProvider(activeTrip.id)
                .overrideWithValue({'org_user': 0, 'mem_alice': 0}),
            settlementsStreamProvider(activeTrip.id)
                .overrideWithValue(const AsyncData([])),
          ],
        );

        // Plain member sees "Leave Trip" button
        expect(find.text('Leave Trip'), findsOneWidget);
        // Plain member DOES NOT see "Remove" button
        expect(find.text('Remove'), findsNothing);
      },
    );

    testWidgets(
      'W2 Mark-as-paid sheet: input validation, error text asserted, submit disabled/blocked',
      (tester) async {
        await tester.pumpApp(
          Scaffold(
            body: MarkAsPaidSheet(
              trip: activeTrip,
              payment: const SuggestedPayment(
                fromUid: 'mem_alice',
                toUid: 'org_user',
                amount: 2500,
              ),
              receiverName: 'Organizer Dan',
            ),
          ),
        );

        final submitBtnFinder = find.widgetWithText(
          FilledButton,
          'Submit Payment',
        );
        final textFieldFinder = find.byType(TextField);

        // 1. Empty input
        await tester.enterText(textFieldFinder, '');
        await tester.tap(submitBtnFinder);
        await tester.pumpAndSettle();
        expect(find.text('Please enter an amount.'), findsOneWidget);

        // 2. Zero amount
        await tester.enterText(textFieldFinder, '0');
        await tester.tap(submitBtnFinder);
        await tester.pumpAndSettle();
        expect(find.text('Amount must be greater than zero.'), findsOneWidget);

        // 3. Negative amount
        await tester.enterText(textFieldFinder, '-10');
        await tester.tap(submitBtnFinder);
        await tester.pumpAndSettle();
        expect(find.text('Amount cannot be negative.'), findsOneWidget);

        // 4. Non-numeric
        await tester.enterText(textFieldFinder, 'abc');
        await tester.tap(submitBtnFinder);
        await tester.pumpAndSettle();
        expect(find.text('Invalid number format.'), findsOneWidget);

        // 5. Amount > current debt (2500 minor units = 25.00, input 30.00)
        await tester.enterText(textFieldFinder, '30.00');
        await tester.tap(submitBtnFinder);
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Amount cannot exceed current debt'),
          findsOneWidget,
        );

        // 6. Positive control: valid boundary amount (25.00)
        await tester.enterText(textFieldFinder, '25.00');
        expect(find.text('25.00'), findsOneWidget);
      },
    );

    testWidgets(
      'W2b Mark-as-paid sheet: valid amounts (full debt and partial) submit successfully on fake Firestore',
      (tester) async {
        final fakeFirestore = FakeFirebaseFirestore();
        final repo = SettlementRepository(fakeFirestore);

        // 1. Full debt amount (25.00)
        await tester.pumpApp(
          Scaffold(
            body: MarkAsPaidSheet(
              trip: activeTrip,
              payment: const SuggestedPayment(
                fromUid: 'mem_alice',
                toUid: 'org_user',
                amount: 2500,
              ),
              receiverName: 'Organizer Dan',
            ),
          ),
          authUserValue: AsyncData(
            MockUser(
              uid: 'mem_alice',
              email: 'alice@test.com',
              displayName: 'Alice Member',
            ),
          ),
          overrides: [settlementRepositoryProvider.overrideWithValue(repo)],
        );

        final submitBtn = find.widgetWithText(FilledButton, 'Submit Payment');
        final textField = find.byType(TextField);

        await tester.enterText(textField, '25.00');
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        // No validation errors shown
        expect(find.textContaining('Amount cannot'), findsNothing);
        expect(find.textContaining('Invalid number'), findsNothing);

        // Assert pending doc created in Firestore
        final settlements = await fakeFirestore
            .collection('trips')
            .doc(activeTrip.id)
            .collection('settlements')
            .get();
        expect(settlements.docs.length, 1);
        final doc1 = settlements.docs.first.data();
        expect(doc1['amount'], 2500);
        expect(doc1['fromUid'], 'mem_alice');
        expect(doc1['toUid'], 'org_user');
        expect(doc1['status'], 'pending');

        // Unmount previous tree before pumping second sheet
        await tester.pumpWidget(const SizedBox());

        // 2. Partial debt amount (10.00)
        await tester.pumpApp(
          Scaffold(
            body: MarkAsPaidSheet(
              trip: activeTrip,
              payment: const SuggestedPayment(
                fromUid: 'mem_alice',
                toUid: 'org_user',
                amount: 2500,
              ),
              receiverName: 'Organizer Dan',
            ),
          ),
          authUserValue: AsyncData(
            MockUser(
              uid: 'mem_alice',
              email: 'alice@test.com',
              displayName: 'Alice Member',
            ),
          ),
          overrides: [settlementRepositoryProvider.overrideWithValue(repo)],
        );

        await tester.enterText(find.byType(TextField), '10.00');
        await tester.tap(find.widgetWithText(FilledButton, 'Submit Payment'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Amount cannot'), findsNothing);
        final settlements2 = await fakeFirestore
            .collection('trips')
            .doc(activeTrip.id)
            .collection('settlements')
            .get();
        expect(settlements2.docs.length, 2);
        final doc2 = settlements2.docs.last.data();
        expect(doc2['amount'], 1000);
        expect(doc2['fromUid'], 'mem_alice');
        expect(doc2['toUid'], 'org_user');
        expect(doc2['status'], 'pending');
      },
    );

    testWidgets(
      'W3 Status chips show text labels (Confirmed, Rejected, Awaiting confirmation) asserted via find.text',
      (tester) async {
        final sConfirmed = Settlement(
          id: 's_conf',
          fromUid: 'mem_alice',
          toUid: 'org_user',
          amount: 1500,
          status: SettlementStatus.confirmed,
          createdAt: now,
          resolvedAt: now,
        );

        final sRejected = Settlement(
          id: 's_rej',
          fromUid: 'mem_alice',
          toUid: 'org_user',
          amount: 1200,
          status: SettlementStatus.rejected,
          createdAt: now,
          resolvedAt: now,
        );

        final sPending = Settlement(
          id: 's_pen',
          fromUid: 'mem_alice',
          toUid: 'org_user',
          amount: 800,
          status: SettlementStatus.pending,
          createdAt: now,
        );

        await tester.pumpApp(
          Scaffold(body: BalancesView(trip: activeTrip)),
          authUserValue: AsyncData(
            MockUser(
              uid: 'org_user',
              email: 'org@test.com',
              displayName: 'Organizer Dan',
            ),
          ),
          overrides: [
            tripAllMembersProvider(activeTrip.id)
                .overrideWithValue(AsyncData([orgMember, aliceMember])),
            tripMembersProvider(activeTrip.id)
                .overrideWithValue(AsyncData([orgMember, aliceMember])),
            tripBalancesProvider(activeTrip.id)
                .overrideWithValue({'org_user': 0, 'mem_alice': 0}),
            totalTripSpentProvider(activeTrip.id).overrideWithValue(10000),
            settlementsStreamProvider(
              activeTrip.id,
            ).overrideWithValue(AsyncData([sConfirmed, sRejected, sPending])),
          ],
        );

        // Assert text labels exist directly via find.text
        expect(find.text('Confirmed'), findsOneWidget);
        expect(find.text('Rejected'), findsOneWidget);
        expect(find.text('Awaiting confirmation'), findsOneWidget);
      },
    );

    testWidgets(
      'W4 Action visibility on pending vs confirmed/rejected settlements',
      (tester) async {
        final pendingSettlement = Settlement(
          id: 's_pend',
          fromUid: 'mem_alice',
          toUid: 'org_user',
          amount: 1000,
          status: SettlementStatus.pending,
          createdAt: now,
        );

        final confirmedSettlement = Settlement(
          id: 's_done',
          fromUid: 'mem_alice',
          toUid: 'org_user',
          amount: 1000,
          status: SettlementStatus.confirmed,
          createdAt: now,
          resolvedAt: now,
        );

        // 1. Receiver perspective (org_user is toUid) on pending settlement
        await tester.pumpApp(
          Scaffold(body: BalancesView(trip: activeTrip)),
          authUserValue: AsyncData(
            MockUser(
              uid: 'org_user',
              email: 'org@test.com',
              displayName: 'Organizer Dan',
            ),
          ),
          overrides: [
            tripAllMembersProvider(activeTrip.id)
                .overrideWithValue(AsyncData([orgMember, aliceMember])),
            tripMembersProvider(activeTrip.id)
                .overrideWithValue(AsyncData([orgMember, aliceMember])),
            tripBalancesProvider(activeTrip.id)
                .overrideWithValue({'org_user': 0, 'mem_alice': 0}),
            totalTripSpentProvider(activeTrip.id).overrideWithValue(1000),
            settlementsStreamProvider(activeTrip.id)
                .overrideWithValue(AsyncData([pendingSettlement])),
          ],
        );

        // Receiver sees Reject and Confirm
        expect(find.text('Reject'), findsOneWidget);
        expect(find.text('Confirm'), findsOneWidget);
        // Receiver does NOT see Cancel
        expect(find.text('Cancel'), findsNothing);

        // 2. Payer perspective (mem_alice is fromUid) on pending settlement
        await tester.pumpApp(
          Scaffold(body: BalancesView(trip: activeTrip)),
          authUserValue: AsyncData(
            MockUser(
              uid: 'mem_alice',
              email: 'alice@test.com',
              displayName: 'Alice Member',
            ),
          ),
          overrides: [
            tripAllMembersProvider(activeTrip.id)
                .overrideWithValue(AsyncData([orgMember, aliceMember])),
            tripMembersProvider(activeTrip.id)
                .overrideWithValue(AsyncData([orgMember, aliceMember])),
            tripBalancesProvider(activeTrip.id)
                .overrideWithValue({'org_user': 0, 'mem_alice': 0}),
            totalTripSpentProvider(activeTrip.id).overrideWithValue(1000),
            settlementsStreamProvider(activeTrip.id)
                .overrideWithValue(AsyncData([pendingSettlement])),
          ],
        );

        // Payer sees Cancel button
        expect(find.text('Cancel'), findsOneWidget);
        // Payer does NOT see Reject or Confirm
        expect(find.text('Reject'), findsNothing);
        expect(find.text('Confirm'), findsNothing);

        // 3. Non-participant perspective (mem_bob) on pending settlement
        await tester.pumpApp(
          Scaffold(body: BalancesView(trip: activeTrip)),
          authUserValue: AsyncData(
            MockUser(
              uid: 'mem_bob',
              email: 'bob@test.com',
              displayName: 'Bob Left',
            ),
          ),
          overrides: [
            tripAllMembersProvider(activeTrip.id).overrideWithValue(
              AsyncData([orgMember, aliceMember, bobLeftMember]),
            ),
            tripMembersProvider(activeTrip.id)
                .overrideWithValue(AsyncData([orgMember, aliceMember])),
            tripBalancesProvider(
              activeTrip.id,
            ).overrideWithValue({'org_user': 0, 'mem_alice': 0, 'mem_bob': 0}),
            totalTripSpentProvider(activeTrip.id).overrideWithValue(1000),
            settlementsStreamProvider(activeTrip.id)
                .overrideWithValue(AsyncData([pendingSettlement])),
          ],
        );
        expect(find.text('Cancel'), findsNothing);
        expect(find.text('Reject'), findsNothing);
        expect(find.text('Confirm'), findsNothing);

        // 4. Confirmed settlement: NOBODY sees action buttons
        await tester.pumpApp(
          Scaffold(body: BalancesView(trip: activeTrip)),
          authUserValue: AsyncData(
            MockUser(
              uid: 'org_user',
              email: 'org@test.com',
              displayName: 'Organizer Dan',
            ),
          ),
          overrides: [
            tripAllMembersProvider(activeTrip.id)
                .overrideWithValue(AsyncData([orgMember, aliceMember])),
            tripMembersProvider(activeTrip.id)
                .overrideWithValue(AsyncData([orgMember, aliceMember])),
            tripBalancesProvider(activeTrip.id)
                .overrideWithValue({'org_user': 0, 'mem_alice': 0}),
            totalTripSpentProvider(activeTrip.id).overrideWithValue(1000),
            settlementsStreamProvider(activeTrip.id)
                .overrideWithValue(AsyncData([confirmedSettlement])),
          ],
        );
        expect(find.text('Confirm'), findsNothing);
        expect(find.text('Reject'), findsNothing);
        expect(find.text('Cancel'), findsNothing);
      },
    );

    testWidgets(
      'W4b Settlement action permissions: organizer as payer sees Cancel only; organizer as receiver sees Confirm/Reject; rejected has no actions',
      (tester) async {
        final sOrgOwesAlice = Settlement(
          id: 's_org_owes',
          fromUid: 'org_user',
          toUid: 'mem_alice',
          amount: 1500,
          status: SettlementStatus.pending,
          createdAt: now,
        );

        final sRejected = Settlement(
          id: 's_rej',
          fromUid: 'mem_alice',
          toUid: 'org_user',
          amount: 800,
          status: SettlementStatus.rejected,
          createdAt: now,
          resolvedAt: now,
        );

        // 1. Organizer as PAYER (org_user owes mem_alice)
        await tester.pumpApp(
          Scaffold(body: BalancesView(trip: activeTrip)),
          authUserValue: AsyncData(
            MockUser(
              uid: 'org_user',
              email: 'org@test.com',
              displayName: 'Organizer Dan',
            ),
          ),
          overrides: [
            tripAllMembersProvider(activeTrip.id)
                .overrideWithValue(AsyncData([orgMember, aliceMember])),
            tripMembersProvider(activeTrip.id)
                .overrideWithValue(AsyncData([orgMember, aliceMember])),
            tripBalancesProvider(activeTrip.id)
                .overrideWithValue({'org_user': 0, 'mem_alice': 0}),
            totalTripSpentProvider(activeTrip.id).overrideWithValue(1500),
            settlementsStreamProvider(activeTrip.id)
                .overrideWithValue(AsyncData([sOrgOwesAlice])),
          ],
        );

        // Organizer is payer -> Cancel visible, Confirm and Reject absent
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Confirm'), findsNothing);
        expect(find.text('Reject'), findsNothing);

        // 2. Rejected settlement: neither party sees any action buttons
        await tester.pumpApp(
          Scaffold(body: BalancesView(trip: activeTrip)),
          authUserValue: AsyncData(
            MockUser(
              uid: 'org_user',
              email: 'org@test.com',
              displayName: 'Organizer Dan',
            ),
          ),
          overrides: [
            tripAllMembersProvider(activeTrip.id)
                .overrideWithValue(AsyncData([orgMember, aliceMember])),
            tripMembersProvider(activeTrip.id)
                .overrideWithValue(AsyncData([orgMember, aliceMember])),
            tripBalancesProvider(activeTrip.id)
                .overrideWithValue({'org_user': 0, 'mem_alice': 0}),
            totalTripSpentProvider(activeTrip.id).overrideWithValue(800),
            settlementsStreamProvider(activeTrip.id)
                .overrideWithValue(AsyncData([sRejected])),
          ],
        );

        expect(find.text('Confirm'), findsNothing);
        expect(find.text('Reject'), findsNothing);
        expect(find.text('Cancel'), findsNothing);
      },
    );

    testWidgets(
      'W4c Settlement action permissions: organizer as third party, plain member as third party, payer vs receiver, rejected visibility, and real confirm',
      (tester) async {
        final carolMember = Member(
          uid: 'mem_carol',
          displayName: 'Carol Active',
          role: 'member',
          status: 'active',
          joinedAt: now,
        );

        final daveMember = Member(
          uid: 'mem_dave',
          displayName: 'Dave Plain',
          role: 'member',
          status: 'active',
          joinedAt: now,
        );

        final allMembers = [orgMember, aliceMember, carolMember, daveMember];

        final sPendingAliceToCarol = Settlement(
          id: 's_alice_carol_pen',
          fromUid: 'mem_alice',
          toUid: 'mem_carol',
          amount: 2000,
          status: SettlementStatus.pending,
          createdAt: now,
        );

        final sRejectedAliceToCarol = Settlement(
          id: 's_alice_carol_rej',
          fromUid: 'mem_alice',
          toUid: 'mem_carol',
          amount: 2000,
          status: SettlementStatus.rejected,
          createdAt: now,
          resolvedAt: now,
        );

        // (a) Organizer (neither payer nor receiver) sees Confirm and Reject and NOT Cancel
        await tester.pumpApp(
          Scaffold(body: BalancesView(trip: activeTrip)),
          authUserValue: AsyncData(
            MockUser(
              uid: 'org_user',
              email: 'org@test.com',
              displayName: 'Organizer Dan',
            ),
          ),
          overrides: [
            tripAllMembersProvider(activeTrip.id)
                .overrideWithValue(AsyncData(allMembers)),
            tripMembersProvider(activeTrip.id)
                .overrideWithValue(AsyncData(allMembers)),
            tripBalancesProvider(activeTrip.id).overrideWithValue({
              'org_user': 0,
              'mem_alice': 0,
              'mem_carol': 0,
              'mem_dave': 0,
            }),
            totalTripSpentProvider(activeTrip.id).overrideWithValue(2000),
            settlementsStreamProvider(activeTrip.id)
                .overrideWithValue(AsyncData([sPendingAliceToCarol])),
          ],
        );

        expect(find.text('Confirm'), findsOneWidget);
        expect(find.text('Reject'), findsOneWidget);
        expect(find.text('Cancel'), findsNothing);

        // (b) Plain member Dave (active, neither party) sees none of Confirm, Reject, Cancel
        await tester.pumpWidget(const SizedBox());
        await tester.pumpApp(
          Scaffold(body: BalancesView(trip: activeTrip)),
          authUserValue: AsyncData(
            MockUser(
              uid: 'mem_dave',
              email: 'dave@test.com',
              displayName: 'Dave Plain',
            ),
          ),
          overrides: [
            tripAllMembersProvider(activeTrip.id)
                .overrideWithValue(AsyncData(allMembers)),
            tripMembersProvider(activeTrip.id)
                .overrideWithValue(AsyncData(allMembers)),
            tripBalancesProvider(activeTrip.id).overrideWithValue({
              'org_user': 0,
              'mem_alice': 0,
              'mem_carol': 0,
              'mem_dave': 0,
            }),
            totalTripSpentProvider(activeTrip.id).overrideWithValue(2000),
            settlementsStreamProvider(activeTrip.id)
                .overrideWithValue(AsyncData([sPendingAliceToCarol])),
          ],
        );

        expect(find.text('Awaiting confirmation'), findsOneWidget);
        expect(find.text('Confirm'), findsNothing);
        expect(find.text('Reject'), findsNothing);
        expect(find.text('Cancel'), findsNothing);

        // (c1) Receiver Carol (not organizer) sees Confirm and Reject, NOT Cancel
        await tester.pumpWidget(const SizedBox());
        await tester.pumpApp(
          Scaffold(body: BalancesView(trip: activeTrip)),
          authUserValue: AsyncData(
            MockUser(
              uid: 'mem_carol',
              email: 'carol@test.com',
              displayName: 'Carol Active',
            ),
          ),
          overrides: [
            tripAllMembersProvider(activeTrip.id)
                .overrideWithValue(AsyncData(allMembers)),
            tripMembersProvider(activeTrip.id)
                .overrideWithValue(AsyncData(allMembers)),
            tripBalancesProvider(activeTrip.id).overrideWithValue({
              'org_user': 0,
              'mem_alice': 0,
              'mem_carol': 0,
              'mem_dave': 0,
            }),
            totalTripSpentProvider(activeTrip.id).overrideWithValue(2000),
            settlementsStreamProvider(activeTrip.id)
                .overrideWithValue(AsyncData([sPendingAliceToCarol])),
          ],
        );

        expect(find.text('Confirm'), findsOneWidget);
        expect(find.text('Reject'), findsOneWidget);
        expect(find.text('Cancel'), findsNothing);

        // (c2) Payer Alice (not organizer) sees Cancel only, NOT Confirm or Reject
        await tester.pumpWidget(const SizedBox());
        await tester.pumpApp(
          Scaffold(body: BalancesView(trip: activeTrip)),
          authUserValue: AsyncData(
            MockUser(
              uid: 'mem_alice',
              email: 'alice@test.com',
              displayName: 'Alice Member',
            ),
          ),
          overrides: [
            tripAllMembersProvider(activeTrip.id)
                .overrideWithValue(AsyncData(allMembers)),
            tripMembersProvider(activeTrip.id)
                .overrideWithValue(AsyncData(allMembers)),
            tripBalancesProvider(activeTrip.id).overrideWithValue({
              'org_user': 0,
              'mem_alice': 0,
              'mem_carol': 0,
              'mem_dave': 0,
            }),
            totalTripSpentProvider(activeTrip.id).overrideWithValue(2000),
            settlementsStreamProvider(activeTrip.id)
                .overrideWithValue(AsyncData([sPendingAliceToCarol])),
          ],
        );

        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Confirm'), findsNothing);
        expect(find.text('Reject'), findsNothing);

        // (d1) Rejected settlement viewed by org_user
        await tester.pumpWidget(const SizedBox());
        await tester.pumpApp(
          Scaffold(body: BalancesView(trip: activeTrip)),
          authUserValue: AsyncData(
            MockUser(
              uid: 'org_user',
              email: 'org@test.com',
              displayName: 'Organizer Dan',
            ),
          ),
          overrides: [
            tripAllMembersProvider(activeTrip.id)
                .overrideWithValue(AsyncData(allMembers)),
            tripMembersProvider(activeTrip.id)
                .overrideWithValue(AsyncData(allMembers)),
            tripBalancesProvider(activeTrip.id).overrideWithValue({
              'org_user': 0,
              'mem_alice': 0,
              'mem_carol': 0,
              'mem_dave': 0,
            }),
            totalTripSpentProvider(activeTrip.id).overrideWithValue(2000),
            settlementsStreamProvider(activeTrip.id)
                .overrideWithValue(AsyncData([sRejectedAliceToCarol])),
          ],
        );
        expect(find.text('Rejected'), findsOneWidget);
        expect(find.text('Confirm'), findsNothing);
        expect(find.text('Reject'), findsNothing);
        expect(find.text('Cancel'), findsNothing);

        // (d2) Rejected settlement viewed by payer mem_alice
        await tester.pumpWidget(const SizedBox());
        await tester.pumpApp(
          Scaffold(body: BalancesView(trip: activeTrip)),
          authUserValue: AsyncData(
            MockUser(
              uid: 'mem_alice',
              email: 'alice@test.com',
              displayName: 'Alice Member',
            ),
          ),
          overrides: [
            tripAllMembersProvider(activeTrip.id)
                .overrideWithValue(AsyncData(allMembers)),
            tripMembersProvider(activeTrip.id)
                .overrideWithValue(AsyncData(allMembers)),
            tripBalancesProvider(activeTrip.id).overrideWithValue({
              'org_user': 0,
              'mem_alice': 0,
              'mem_carol': 0,
              'mem_dave': 0,
            }),
            totalTripSpentProvider(activeTrip.id).overrideWithValue(2000),
            settlementsStreamProvider(activeTrip.id)
                .overrideWithValue(AsyncData([sRejectedAliceToCarol])),
          ],
        );
        expect(find.text('Rejected'), findsOneWidget);
        expect(find.text('Confirm'), findsNothing);
        expect(find.text('Reject'), findsNothing);
        expect(find.text('Cancel'), findsNothing);

        // (d3) Rejected settlement viewed by receiver mem_carol
        await tester.pumpWidget(const SizedBox());
        await tester.pumpApp(
          Scaffold(body: BalancesView(trip: activeTrip)),
          authUserValue: AsyncData(
            MockUser(
              uid: 'mem_carol',
              email: 'carol@test.com',
              displayName: 'Carol Active',
            ),
          ),
          overrides: [
            tripAllMembersProvider(activeTrip.id)
                .overrideWithValue(AsyncData(allMembers)),
            tripMembersProvider(activeTrip.id)
                .overrideWithValue(AsyncData(allMembers)),
            tripBalancesProvider(activeTrip.id).overrideWithValue({
              'org_user': 0,
              'mem_alice': 0,
              'mem_carol': 0,
              'mem_dave': 0,
            }),
            totalTripSpentProvider(activeTrip.id).overrideWithValue(2000),
            settlementsStreamProvider(activeTrip.id)
                .overrideWithValue(AsyncData([sRejectedAliceToCarol])),
          ],
        );
        expect(find.text('Rejected'), findsOneWidget);
        expect(find.text('Confirm'), findsNothing);
        expect(find.text('Reject'), findsNothing);
        expect(find.text('Cancel'), findsNothing);

        // (e) Organizer taps Confirm: resolves on fake Firestore
        final fakeFirestore = FakeFirebaseFirestore();
        final settlementRef = fakeFirestore
            .collection('trips')
            .doc(activeTrip.id)
            .collection('settlements')
            .doc('s_alice_carol_pen');
        await settlementRef.set({
          'fromUid': 'mem_alice',
          'toUid': 'mem_carol',
          'amount': 2000,
          'status': 'pending',
          'createdAt': Timestamp.now(),
        });

        final repo = SettlementRepository(fakeFirestore);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpApp(
          Scaffold(body: BalancesView(trip: activeTrip)),
          authUserValue: AsyncData(
            MockUser(
              uid: 'org_user',
              email: 'org@test.com',
              displayName: 'Organizer Dan',
            ),
          ),
          overrides: [
            tripAllMembersProvider(activeTrip.id)
                .overrideWithValue(AsyncData(allMembers)),
            tripMembersProvider(activeTrip.id)
                .overrideWithValue(AsyncData(allMembers)),
            tripBalancesProvider(activeTrip.id).overrideWithValue({
              'org_user': 0,
              'mem_alice': 0,
              'mem_carol': 0,
              'mem_dave': 0,
            }),
            totalTripSpentProvider(activeTrip.id).overrideWithValue(2000),
            settlementsStreamProvider(activeTrip.id)
                .overrideWithValue(AsyncData([sPendingAliceToCarol])),
            settlementRepositoryProvider.overrideWithValue(repo),
          ],
        );

        final confirmBtnFinder = find.widgetWithText(FilledButton, 'Confirm');
        expect(confirmBtnFinder, findsOneWidget);
        await tester.ensureVisible(confirmBtnFinder);
        await tester.tap(confirmBtnFinder);
        await tester.pumpAndSettle();

        final updatedDoc = await settlementRef.get();
        final data = updatedDoc.data()!;
        expect(data['status'], 'confirmed');
        expect(data['resolvedAt'], isNotNull);
        expect(data['amount'], 2000);
      },
    );

    testWidgets(
      'W5 Leave dialog: blocked-state message on nonzero balance; allowed-state confirm and cancel',
      (tester) async {
        final mockAlice = MockUser(
          uid: 'mem_alice',
          email: 'alice@test.com',
          displayName: 'Alice Member',
        );

        // 1. Blocked state (nonzero balance)
        await tester.pumpApp(
          Scaffold(body: MembersTab(trip: activeTrip)),
          authUserValue: AsyncData(mockAlice),
          overrides: [
            tripMembersProvider(activeTrip.id)
                .overrideWithValue(AsyncData([orgMember, aliceMember])),
            tripBalancesProvider(activeTrip.id)
                .overrideWithValue({'org_user': 500, 'mem_alice': -500}),
            settlementsStreamProvider(activeTrip.id)
                .overrideWithValue(const AsyncData([])),
          ],
        );

        await tester.tap(find.text('Leave Trip'));
        await tester.pumpAndSettle();

        expect(find.text('Cannot Leave Trip'), findsOneWidget);
        expect(
          find.textContaining('Cannot leave while you have a nonzero balance'),
          findsOneWidget,
        );
        expect(find.textContaining('you owe'), findsOneWidget);
        expect(find.textContaining('5.00'), findsOneWidget);
        expect(find.textContaining('minor units'), findsNothing);
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        expect(find.text('Cannot Leave Trip'), findsNothing);

        // 2. Allowed state: confirm and cancel paths
        await tester.pumpApp(
          Scaffold(body: MembersTab(trip: activeTrip)),
          authUserValue: AsyncData(mockAlice),
          overrides: [
            tripMembersProvider(activeTrip.id)
                .overrideWithValue(AsyncData([orgMember, aliceMember])),
            tripBalancesProvider(activeTrip.id)
                .overrideWithValue({'org_user': 0, 'mem_alice': 0}),
            settlementsStreamProvider(activeTrip.id)
                .overrideWithValue(const AsyncData([])),
          ],
        );

        await tester.tap(find.text('Leave Trip'));
        await tester.pumpAndSettle();

        expect(
          find.text('Leave Trip'),
          findsNWidgets(2),
        ); // Button + Dialog title
        expect(
          find.text(
            'Are you sure you want to leave this trip? You won\'t be able to rejoin this trip in this version. Your past expenses stay in the balances, marked (left).',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('rejoin later'), findsNothing);
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.widgetWithText(FilledButton, 'Leave'), findsOneWidget);

        // Cancel dismisses dialog
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Are you sure you want to leave this trip?'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'W5b Leave dialog: blocked by pending settlement with zero balance; allowed when no pending settlements',
      (tester) async {
        final mockAlice = MockUser(
          uid: 'mem_alice',
          email: 'alice@test.com',
          displayName: 'Alice Member',
        );

        final pendingSettlement = Settlement(
          id: 's_pend',
          fromUid: 'mem_alice',
          toUid: 'org_user',
          amount: 1000,
          status: SettlementStatus.pending,
          createdAt: now,
        );

        // 1. Blocked: balance is 0, but has pending settlement
        await tester.pumpApp(
          Scaffold(body: MembersTab(trip: activeTrip)),
          authUserValue: AsyncData(mockAlice),
          overrides: [
            tripMembersProvider(activeTrip.id)
                .overrideWithValue(AsyncData([orgMember, aliceMember])),
            tripBalancesProvider(activeTrip.id)
                .overrideWithValue({'org_user': 0, 'mem_alice': 0}),
            settlementsStreamProvider(activeTrip.id)
                .overrideWithValue(AsyncData([pendingSettlement])),
          ],
        );

        await tester.tap(find.text('Leave Trip'));
        await tester.pumpAndSettle();

        expect(find.text('Cannot Leave Trip'), findsOneWidget);
        expect(
          find.textContaining(
            'Cannot leave while you have pending settlements',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        // 2. Allowed: balance is 0 and no pending settlements
        await tester.pumpApp(
          Scaffold(body: MembersTab(trip: activeTrip)),
          authUserValue: AsyncData(mockAlice),
          overrides: [
            tripMembersProvider(activeTrip.id)
                .overrideWithValue(AsyncData([orgMember, aliceMember])),
            tripBalancesProvider(activeTrip.id)
                .overrideWithValue({'org_user': 0, 'mem_alice': 0}),
            settlementsStreamProvider(activeTrip.id)
                .overrideWithValue(const AsyncData([])),
          ],
        );

        await tester.tap(find.text('Leave Trip'));
        await tester.pumpAndSettle();

        expect(find.text('Leave Trip'), findsNWidgets(2)); // Button + Title
        expect(find.widgetWithText(FilledButton, 'Leave'), findsOneWidget);
      },
    );

    testWidgets('W6 Remove dialog: confirm and cancel paths', (tester) async {
      final mockOrg = MockUser(
        uid: 'org_user',
        email: 'org@test.com',
        displayName: 'Organizer Dan',
      );

      await tester.pumpApp(
        Scaffold(body: MembersTab(trip: activeTrip)),
        authUserValue: AsyncData(mockOrg),
        overrides: [
          tripMembersProvider(activeTrip.id)
              .overrideWithValue(AsyncData([orgMember, aliceMember])),
          tripBalancesProvider(activeTrip.id)
              .overrideWithValue({'org_user': 0, 'mem_alice': 0}),
          settlementsStreamProvider(activeTrip.id)
              .overrideWithValue(const AsyncData([])),
        ],
      );

      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(find.text('Remove Member'), findsOneWidget);
      expect(
        find.text(
          'Are you sure you want to remove Alice Member from this trip?',
        ),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Remove'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Are you sure you want to remove Alice Member from this trip?',
        ),
        findsNothing,
      );
    });

    testWidgets(
      'W6b Remove dialog: confirm updates member status to left and memberIds in Firestore; cancel leaves docs unchanged',
      (tester) async {
        final fakeFirestore = FakeFirebaseFirestore();
        await fakeFirestore.collection('trips').doc(activeTrip.id).set({
          'name': 'Paris Trip',
          'memberIds': ['org_user', 'mem_alice'],
          'memberCount': 2,
        });
        await fakeFirestore
            .collection('trips')
            .doc(activeTrip.id)
            .collection('members')
            .doc('mem_alice')
            .set({
              'displayName': 'Alice Member',
              'role': 'member',
              'status': 'active',
            });
        final repo = TripRepository(firestore: fakeFirestore);

        final mockOrg = MockUser(
          uid: 'org_user',
          email: 'org@test.com',
          displayName: 'Organizer Dan',
        );

        final twoMemberTrip = Trip(
          id: activeTrip.id,
          name: activeTrip.name,
          destination: activeTrip.destination,
          startDate: activeTrip.startDate,
          endDate: activeTrip.endDate,
          currency: activeTrip.currency,
          organizerId: activeTrip.organizerId,
          joinCode: activeTrip.joinCode,
          memberIds: ['org_user', 'mem_alice'],
          memberCount: 2,
          archived: false,
        );

        // 1. Cancel does NOT mutate docs
        await tester.pumpApp(
          Scaffold(body: MembersTab(trip: twoMemberTrip)),
          authUserValue: AsyncData(mockOrg),
          overrides: [
            tripMembersProvider(activeTrip.id)
                .overrideWithValue(AsyncData([orgMember, aliceMember])),
            tripBalancesProvider(activeTrip.id)
                .overrideWithValue({'org_user': 0, 'mem_alice': 0}),
            settlementsStreamProvider(activeTrip.id)
                .overrideWithValue(const AsyncData([])),
            tripRepositoryProvider.overrideWithValue(repo),
          ],
        );

        await tester.tap(find.text('Remove'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        var tripDoc = await fakeFirestore
            .collection('trips')
            .doc(activeTrip.id)
            .get();
        expect(tripDoc.data()?['memberCount'], 2);
        var memberDoc = await fakeFirestore
            .collection('trips')
            .doc(activeTrip.id)
            .collection('members')
            .doc('mem_alice')
            .get();
        expect(memberDoc.data()?['status'], 'active');

        // 2. Confirm Remove updates member status to left, removes from memberIds, decrements memberCount
        await tester.tap(find.text('Remove'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
        await tester.pumpAndSettle();

        expect(find.text('Alice Member has been removed.'), findsOneWidget);

        tripDoc = await fakeFirestore
            .collection('trips')
            .doc(activeTrip.id)
            .get();
        expect(tripDoc.data()?['memberCount'], 1);
        expect(tripDoc.data()?['memberIds'], ['org_user']);
        memberDoc = await fakeFirestore
            .collection('trips')
            .doc(activeTrip.id)
            .collection('members')
            .doc('mem_alice')
            .get();
        expect(memberDoc.data()?['status'], 'left');
      },
    );

    testWidgets(
      'W7 "(left)" label appears for left member in balances, and not for active members',
      (tester) async {
        await tester.pumpApp(
          Scaffold(body: BalancesView(trip: activeTrip)),
          authUserValue: AsyncData(
            MockUser(
              uid: 'org_user',
              email: 'org@test.com',
              displayName: 'Organizer Dan',
            ),
          ),
          overrides: [
            tripAllMembersProvider(activeTrip.id).overrideWithValue(
              AsyncData([orgMember, aliceMember, bobLeftMember]),
            ),
            tripMembersProvider(activeTrip.id)
                .overrideWithValue(AsyncData([orgMember, aliceMember])),
            tripBalancesProvider(
              activeTrip.id,
            ).overrideWithValue({'org_user': 0, 'mem_alice': 0, 'mem_bob': 0}),
            totalTripSpentProvider(activeTrip.id).overrideWithValue(0),
            settlementsStreamProvider(activeTrip.id)
                .overrideWithValue(const AsyncData([])),
          ],
        );

        // Left member has "(left)" suffix
        expect(find.text('Bob Left (left)'), findsOneWidget);
        // Active members do not have "(left)" suffix
        expect(find.text('Alice Member (left)'), findsNothing);
        expect(find.text('Alice Member'), findsOneWidget);
      },
    );

    testWidgets(
      'W8 Expense Edit is disabled when an expense involves a left member (and enabled when not)',
      (tester) async {
        final activeExpense = Expense(
          id: 'e_active',
          amount: 2000,
          description: 'Lunch',
          paidBy: 'org_user',
          participantIds: ['org_user', 'mem_alice'],
          createdBy: 'org_user',
          date: now,
          createdAt: now,
        );

        final leftExpense = Expense(
          id: 'e_left',
          amount: 2000,
          description: 'Dinner with Bob',
          paidBy: 'org_user',
          participantIds: ['org_user', 'mem_bob'],
          createdBy: 'org_user',
          date: now,
          createdAt: now,
        );

        // 1. Involving left member
        await tester.pumpApp(
          Scaffold(
            body: ExpenseCard(
              expense: leftExpense,
              currency: 'USD',
              members: [orgMember, aliceMember, bobLeftMember],
              canManage: true,
              onEdit: () {},
              onDelete: () {},
            ),
          ),
        );

        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();

        final editItemFinder = find.widgetWithText(
          PopupMenuItem<String>,
          'Edit',
        );
        expect(editItemFinder, findsOneWidget);
        final editWidget = tester.widget<PopupMenuItem<String>>(editItemFinder);
        expect(editWidget.enabled, isFalse);

        // Close menu
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        // 2. Positive control: active members only -> Edit enabled
        await tester.pumpApp(
          Scaffold(
            body: ExpenseCard(
              expense: activeExpense,
              currency: 'USD',
              members: [orgMember, aliceMember],
              canManage: true,
              onEdit: () {},
              onDelete: () {},
            ),
          ),
        );

        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();

        final editActiveFinder = find.widgetWithText(
          PopupMenuItem<String>,
          'Edit',
        );
        final activeWidget = tester.widget<PopupMenuItem<String>>(
          editActiveFinder,
        );
        expect(activeWidget.enabled, isTrue);
      },
    );

    testWidgets(
      'W9 Archived trip: all settlement/leave/remove/add actions absent or disabled; read content visible',
      (tester) async {
        final sPending = Settlement(
          id: 's_pen',
          fromUid: 'mem_alice',
          toUid: 'org_user',
          amount: 1000,
          status: SettlementStatus.pending,
          createdAt: now,
        );

        // In BalancesView on archived trip
        await tester.pumpApp(
          Scaffold(body: BalancesView(trip: archivedTrip)),
          authUserValue: AsyncData(
            MockUser(
              uid: 'org_user',
              email: 'org@test.com',
              displayName: 'Organizer Dan',
            ),
          ),
          overrides: [
            tripAllMembersProvider(archivedTrip.id)
                .overrideWithValue(AsyncData([orgMember, aliceMember])),
            tripMembersProvider(archivedTrip.id)
                .overrideWithValue(AsyncData([orgMember, aliceMember])),
            tripBalancesProvider(archivedTrip.id)
                .overrideWithValue({'org_user': 0, 'mem_alice': 0}),
            totalTripSpentProvider(archivedTrip.id).overrideWithValue(1000),
            settlementsStreamProvider(archivedTrip.id)
                .overrideWithValue(AsyncData([sPending])),
          ],
        );

        // Confirm / Reject action buttons are absent because trip.archived is true
        expect(find.text('Confirm'), findsNothing);
        expect(find.text('Reject'), findsNothing);
        expect(find.text('Cancel'), findsNothing);
        // Read content remains visible
        expect(find.text('Awaiting confirmation'), findsOneWidget);

        // Unmount previous tree before pumping MembersTab with different overrides
        await tester.pumpWidget(const SizedBox());

        // In MembersTab on archived trip (organizer perspective)
        await tester.pumpApp(
          Scaffold(body: MembersTab(trip: archivedTrip)),
          authUserValue: AsyncData(
            MockUser(
              uid: 'org_user',
              email: 'org@test.com',
              displayName: 'Organizer Dan',
            ),
          ),
          overrides: [
            tripMembersProvider(archivedTrip.id)
                .overrideWithValue(AsyncData([orgMember, aliceMember])),
            tripBalancesProvider(archivedTrip.id)
                .overrideWithValue({'org_user': 0, 'mem_alice': 0}),
            settlementsStreamProvider(archivedTrip.id)
                .overrideWithValue(const AsyncData([])),
          ],
        );

        // Remove member button is absent when trip.archived is true
        expect(find.text('Remove'), findsNothing);

        // Unmount before pumping member perspective
        await tester.pumpWidget(const SizedBox());

        // In MembersTab on archived trip (member perspective)
        await tester.pumpApp(
          Scaffold(body: MembersTab(trip: archivedTrip)),
          authUserValue: AsyncData(
            MockUser(
              uid: 'mem_alice',
              email: 'alice@test.com',
              displayName: 'Alice Member',
            ),
          ),
          overrides: [
            tripMembersProvider(archivedTrip.id)
                .overrideWithValue(AsyncData([orgMember, aliceMember])),
            tripBalancesProvider(archivedTrip.id)
                .overrideWithValue({'org_user': 0, 'mem_alice': 0}),
            settlementsStreamProvider(archivedTrip.id)
                .overrideWithValue(const AsyncData([])),
          ],
        );

        // Leave Trip button is absent when trip.archived is true
        expect(find.text('Leave Trip'), findsNothing);
      },
    );

    testWidgets(
      'W9b Suggested payments: Mark as Paid button shown on active trip and absent on archived trip',
      (tester) async {
        final mockAlice = MockUser(
          uid: 'mem_alice',
          email: 'alice@test.com',
          displayName: 'Alice Member',
        );

        // 1. Active trip: mem_alice owes org_user -> Mark as Paid is visible
        await tester.pumpApp(
          Scaffold(body: BalancesView(trip: activeTrip)),
          authUserValue: AsyncData(mockAlice),
          overrides: [
            tripAllMembersProvider(activeTrip.id)
                .overrideWithValue(AsyncData([orgMember, aliceMember])),
            tripMembersProvider(activeTrip.id)
                .overrideWithValue(AsyncData([orgMember, aliceMember])),
            tripBalancesProvider(activeTrip.id)
                .overrideWithValue({'org_user': 2500, 'mem_alice': -2500}),
            totalTripSpentProvider(activeTrip.id).overrideWithValue(5000),
            settlementsStreamProvider(activeTrip.id)
                .overrideWithValue(const AsyncData([])),
          ],
        );

        expect(find.text('Mark as Paid'), findsOneWidget);

        // Unmount before pumping archived trip
        await tester.pumpWidget(const SizedBox());

        // 2. Archived trip: mem_alice owes org_user -> Mark as Paid is absent
        await tester.pumpApp(
          Scaffold(body: BalancesView(trip: archivedTrip)),
          authUserValue: AsyncData(mockAlice),
          overrides: [
            tripAllMembersProvider(archivedTrip.id)
                .overrideWithValue(AsyncData([orgMember, aliceMember])),
            tripMembersProvider(archivedTrip.id)
                .overrideWithValue(AsyncData([orgMember, aliceMember])),
            tripBalancesProvider(archivedTrip.id)
                .overrideWithValue({'org_user': 2500, 'mem_alice': -2500}),
            totalTripSpentProvider(archivedTrip.id).overrideWithValue(5000),
            settlementsStreamProvider(archivedTrip.id)
                .overrideWithValue(const AsyncData([])),
          ],
        );

        expect(find.text('Mark as Paid'), findsNothing);
      },
    );

    testWidgets('W10 Join error message displayed on invalid code format', (
      tester,
    ) async {
      await tester.pumpApp(const JoinTripScreen());

      // Positive control: error message is not unconditionally present
      expect(find.textContaining('Invalid join code format'), findsNothing);

      // Enter invalid format join code
      await tester.enterText(find.byType(TextFormField), '123');
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      // Error message is displayed
      expect(
        find.text(
          'Invalid join code format. Must be 6 characters (letters and numbers).',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'W10b Join screen displays rejoin refusal message on permission-denied',
      (tester) async {
        final throwingFirestore = _ThrowingPermissionDeniedFirestore();
        await throwingFirestore.collection('joinCodes').doc('REJ234').set({
          'tripId': 'trip_rejoin',
          'tripName': 'Rome Adventure',
          'destination': 'Rome',
          'startDate': Timestamp.now(),
          'endDate': Timestamp.now(),
          'memberCount': 2,
        });
        final repo = TripRepository(firestore: throwingFirestore);

        await tester.pumpApp(
          const JoinTripScreen(),
          authUserValue: AsyncData(
            MockUser(
              uid: 'u_left',
              email: 'left@example.com',
              displayName: 'Left User',
            ),
          ),
          overrides: [tripRepositoryProvider.overrideWithValue(repo)],
        );

        await tester.enterText(find.byType(TextFormField), 'REJ234');
        await tester.tap(find.byIcon(Icons.search));
        await tester.pumpAndSettle();

        expect(find.text('Rome Adventure'), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, 'Join Trip'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            "Couldn't join this trip. If you left it earlier, rejoining isn't supported in this version.",
          ),
          findsOneWidget,
        );
      },
    );
  });
}

class _ThrowingPermissionDeniedFirestore extends FakeFirebaseFirestore {
  @override
  WriteBatch batch() => _ThrowingPermissionDeniedBatch(super.batch());
}

class _ThrowingPermissionDeniedBatch implements WriteBatch {
  final WriteBatch _inner;
  _ThrowingPermissionDeniedBatch(this._inner);

  @override
  Future<void> commit() {
    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
      message: 'Missing or insufficient permissions.',
    );
  }

  @override
  void delete(DocumentReference document) => _inner.delete(document);

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) =>
      _inner.set(document, data, options);

  @override
  void update<T>(DocumentReference<T> document, T data) =>
      _inner.update<T>(document, data);
}
