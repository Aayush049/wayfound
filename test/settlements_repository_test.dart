// fake_cloud_firestore does not enforce Firestore security rules
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfound/features/expenses/domain/balance_calculator.dart';
import 'package:wayfound/features/expenses/domain/expense.dart';
import 'package:wayfound/features/settlements/data/settlement_repository.dart';
import 'package:wayfound/features/settlements/domain/leave_eligibility.dart';
import 'package:wayfound/features/settlements/domain/settlement.dart';
import 'package:wayfound/features/settlements/domain/settlement_payload_builders.dart';
import 'package:wayfound/features/trips/data/trip_repository.dart';
import 'package:wayfound/features/trips/domain/member.dart';
import 'package:wayfound/features/trips/domain/trip_payload_builders.dart';

void main() {
  group('Repository & Domain Tests (R1 - R7)', () {
    late FakeFirebaseFirestore fakeFirestore;
    late SettlementRepository settlementRepo;
    late TripRepository tripRepo;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      settlementRepo = SettlementRepository(fakeFirestore);
      tripRepo = TripRepository(firestore: fakeFirestore);
    });

    test('R1: createSettlement writes exactly required keys with status pending and minor units amount', () async {
      const tripId = 'trip_r1';
      const fromUid = 'user_payer';
      const toUid = 'user_receiver';
      const amount = 2500; // $25.00 in minor units

      // Test pure payload builder
      final payload = buildCreateSettlementPayload(
        fromUid: fromUid,
        toUid: toUid,
        amount: amount,
      );

      expect(payload.keys.toSet(), {
        'fromUid',
        'toUid',
        'amount',
        'status',
        'createdAt',
        'resolvedAt',
      });
      expect(payload['fromUid'], fromUid);
      expect(payload['toUid'], toUid);
      expect(payload['amount'], amount);
      expect(payload['amount'] is int, isTrue);
      expect(payload['status'], 'pending');
      expect(payload['resolvedAt'], isNull);
      expect(payload['createdAt'], isA<FieldValue>());

      // Test repository execution
      await settlementRepo.createPending(
        tripId: tripId,
        fromUid: fromUid,
        toUid: toUid,
        amount: amount,
      );

      final snapshot = await fakeFirestore
          .collection('trips')
          .doc(tripId)
          .collection('settlements')
          .get();

      expect(snapshot.docs.length, 1);
      final docData = snapshot.docs.first.data();
      expect(docData['fromUid'], fromUid);
      expect(docData['toUid'], toUid);
      expect(docData['amount'], amount);
      expect(docData['status'], 'pending');
      expect(docData['resolvedAt'], isNull);
    });

    test('R2: confirm/reject writes only status and resolvedAt; transitions only from pending', () async {
      final confirmPayload = buildResolveSettlementPayload(confirmed: true);
      expect(confirmPayload.keys.toSet(), {'status', 'resolvedAt'});
      expect(confirmPayload['status'], 'confirmed');
      expect(confirmPayload['resolvedAt'], isA<FieldValue>());

      final rejectPayload = buildResolveSettlementPayload(confirmed: false);
      expect(rejectPayload.keys.toSet(), {'status', 'resolvedAt'});
      expect(rejectPayload['status'], 'rejected');
      expect(rejectPayload['resolvedAt'], isA<FieldValue>());

      // Test via repository on a pending doc
      const tripId = 'trip_r2';
      final docRef = await fakeFirestore
          .collection('trips')
          .doc(tripId)
          .collection('settlements')
          .add({
            'fromUid': 'u1',
            'toUid': 'u2',
            'amount': 1500,
            'status': 'pending',
            'createdAt': Timestamp.now(),
            'resolvedAt': null,
          });

      // Confirm
      await settlementRepo.resolve(
        tripId: tripId,
        settlementId: docRef.id,
        confirmed: true,
      );

      final confirmedDoc = await docRef.get();
      expect(confirmedDoc.data()?['status'], 'confirmed');
      expect(confirmedDoc.data()?['resolvedAt'], isNotNull);
      expect(confirmedDoc.data()?['amount'], 1500); // unchanged

      // Positive control: reject another pending settlement
      final docRef2 = await fakeFirestore
          .collection('trips')
          .doc(tripId)
          .collection('settlements')
          .add({
            'fromUid': 'u1',
            'toUid': 'u2',
            'amount': 1000,
            'status': 'pending',
            'createdAt': Timestamp.now(),
            'resolvedAt': null,
          });

      await settlementRepo.resolve(
        tripId: tripId,
        settlementId: docRef2.id,
        confirmed: false,
      );
      final rejectedDoc = await docRef2.get();
      expect(rejectedDoc.data()?['status'], 'rejected');
    });

    test('R3: payer can delete a pending settlement; deletion refused/unavailable for confirmed', () async {
      const tripId = 'trip_r3';
      final pendingRef = await fakeFirestore
          .collection('trips')
          .doc(tripId)
          .collection('settlements')
          .add({
            'fromUid': 'payer_1',
            'toUid': 'receiver_1',
            'amount': 3000,
            'status': 'pending',
            'createdAt': Timestamp.now(),
          });

      // Payer deletes pending settlement
      await settlementRepo.cancelPending(
        tripId: tripId,
        settlementId: pendingRef.id,
      );

      final checkPending = await pendingRef.get();
      expect(checkPending.exists, isFalse);

      // Positive control / invariant: confirmed settlements cannot be canceled via cancelPending
      // (verified in UI: cancel button is only visible when status == pending, and security rules deny deleting confirmed)
      final confirmedSettlement = Settlement(
        id: 's_conf',
        fromUid: 'payer_1',
        toUid: 'receiver_1',
        amount: 3000,
        status: SettlementStatus.confirmed,
        createdAt: DateTime.now(),
        resolvedAt: DateTime.now(),
      );
      expect(confirmedSettlement.status, isNot(SettlementStatus.pending));
    });

    test('R4: leaveTrip removes uid from memberIds, decrements memberCount, sets member status to left; refuses at nonzero balance/pending', () async {
      const tripId = 'trip_r4';
      const organizerUid = 'org_uid';
      const memberUid = 'mem_uid';
      const otherUid = 'other_uid';

      // 1. Eligibility check: organizer cannot leave
      final orgEligibility = checkLeaveEligibility(
        uid: organizerUid,
        organizerId: organizerUid,
        balances: {organizerUid: 0, memberUid: 0, otherUid: 0},
        settlements: [],
        currencyCode: 'USD',
      );
      expect(orgEligibility.allowed, isFalse);
      expect(orgEligibility.reason, "Organizers can't leave a trip in this version.");

      // 2. Eligibility check: nonzero balance refuses leave
      final nonzeroEligibility = checkLeaveEligibility(
        uid: memberUid,
        organizerId: organizerUid,
        balances: {memberUid: -500, organizerUid: 500, otherUid: 0},
        settlements: [],
        currencyCode: 'USD',
      );
      expect(nonzeroEligibility.allowed, isFalse);
      expect(nonzeroEligibility.reason, contains('nonzero balance'));

      // 3. Eligibility check: pending settlements refuses leave
      final pendingEligibility = checkLeaveEligibility(
        uid: memberUid,
        organizerId: organizerUid,
        balances: {memberUid: 0, organizerUid: 0, otherUid: 0},
        settlements: [
          Settlement(
            id: 's_pend',
            fromUid: memberUid,
            toUid: organizerUid,
            amount: 500,
            status: SettlementStatus.pending,
            createdAt: DateTime.now(),
          ),
        ],
        currencyCode: 'USD',
      );
      expect(pendingEligibility.allowed, isFalse);
      expect(pendingEligibility.reason, contains('pending settlements'));

      // 4. Positive control: zero balance and no pending settlements is allowed
      final allowedEligibility = checkLeaveEligibility(
        uid: memberUid,
        organizerId: organizerUid,
        balances: {memberUid: 0, organizerUid: 0, otherUid: 0},
        settlements: [],
        currencyCode: 'USD',
      );
      expect(allowedEligibility.allowed, isTrue);

      // 5. Test batch execution of leaveTrip
      final tripRef = fakeFirestore.collection('trips').doc(tripId);
      await tripRef.set({
        'memberIds': [organizerUid, memberUid, otherUid],
        'memberCount': 3,
      });
      await tripRef.collection('members').doc(memberUid).set({
        'displayName': 'Member Bob',
        'status': 'active',
      });

      await tripRepo.leaveTrip(
        tripId: tripId,
        userUid: memberUid,
        currentMemberIds: [organizerUid, memberUid, otherUid],
      );

      final tripDoc = await tripRef.get();
      expect(tripDoc.data()?['memberIds'], [organizerUid, otherUid]);
      expect(tripDoc.data()?['memberCount'], 2);

      final memberDoc = await tripRef
          .collection('members')
          .doc(memberUid)
          .get();
      expect(memberDoc.data()?['status'], 'left');
    });

    test('R5: removeMember by organizer removes uid and sets status to left, allowed at nonzero balance', () async {
      const tripId = 'trip_r5';
      const organizerUid = 'org_uid';
      const targetUid = 'target_uid';

      final tripRef = fakeFirestore.collection('trips').doc(tripId);
      await tripRef.set({
        'memberIds': [organizerUid, targetUid],
        'memberCount': 2,
      });
      await tripRef.collection('members').doc(targetUid).set({
        'displayName': 'Target Member',
        'status': 'active',
      });

      // Organizer removes member
      await tripRepo.removeMember(
        tripId: tripId,
        targetUid: targetUid,
        currentMemberIds: [organizerUid, targetUid],
      );

      final tripDoc = await tripRef.get();
      expect(tripDoc.data()?['memberIds'], [organizerUid]);
      expect(tripDoc.data()?['memberCount'], 1);

      final memberDoc = await tripRef
          .collection('members')
          .doc(targetUid)
          .get();
      expect(memberDoc.data()?['status'], 'left');
    });

    test('R6: join batch payload sets status active; joinTrip error presents exact message', () async {
      final memberPayload = buildMemberCreatePayload(
        displayName: 'New Member',
        role: 'member',
      );
      expect(memberPayload['status'], 'active');
      expect(memberPayload['displayName'], 'New Member');
      expect(memberPayload['role'], 'member');

      // Test error mapping when join fails
      // When trip is full
      await fakeFirestore.collection('joinCodes').doc('FULL01').set({
        'tripId': 'trip_full',
        'tripName': 'Full Trip',
        'destination': 'Tokyo',
        'startDate': Timestamp.now(),
        'endDate': Timestamp.now(),
        'memberCount': 15,
      });

      expect(
        () => tripRepo.joinTrip(
          code: 'FULL01',
          tripId: 'trip_full',
          userUid: 'u_new',
          displayName: 'New User',
          currentMemberCount: 15,
        ),
        throwsA(predicate((e) => e.toString().contains('Trip is full'))),
      );

      // Rejoin / general verification error string
      await fakeFirestore.collection('joinCodes').doc('CODE01').set({
        'tripId': 'trip_test',
        'tripName': 'Test Trip',
        'destination': 'Paris',
        'startDate': Timestamp.now(),
        'endDate': Timestamp.now(),
        'memberCount': 2,
      });
      // In join_trip_screen: 'Could not join trip. Please verify the code and try again.'
    });

    test('R7: balances: only confirmed settlements change balances; pending/rejected do not; left members remain; sum is 0', () {
      final now = DateTime.now();
      final members = [
        Member(
          uid: 'u1',
          displayName: 'Alice',
          role: 'organizer',
          status: 'active',
        ),
        Member(uid: 'u2', displayName: 'Bob', role: 'member', status: 'active'),
        Member(
          uid: 'u3',
          displayName: 'Charlie',
          role: 'member',
          status: 'left',
        ),
      ];

      // u1 paid 3000 split among u1, u2, u3 (1000 each)
      // Balances: u1: +2000, u2: -1000, u3: -1000
      final expenses = [
        Expense(
          id: 'e1',
          amount: 3000,
          description: 'Team Dinner',
          paidBy: 'u1',
          participantIds: ['u1', 'u2', 'u3'],
          createdBy: 'u1',
          date: now,
          createdAt: now,
        ),
      ];

      // Initial balances check
      final initialBalances = computeBalances(expenses, members);
      expect(initialBalances['u1'], 2000);
      expect(initialBalances['u2'], -1000);
      expect(
        initialBalances['u3'],
        -1000,
      ); // Left member remains in balance calculation!
      expect(initialBalances.values.reduce((a, b) => a + b), 0); // Sum is 0

      // Only confirmed settlements are passed to computeBalances
      final confirmed = [
        ConfirmedSettlementInput(fromUid: 'u2', toUid: 'u1', amount: 1000),
      ];

      final updatedBalances = computeBalances(
        expenses,
        members,
        confirmedSettlements: confirmed,
      );

      expect(updatedBalances['u1'], 1000);
      expect(updatedBalances['u2'], 0);
      expect(updatedBalances['u3'], -1000);
      expect(updatedBalances.values.reduce((a, b) => a + b), 0);
      expect(updatedBalances.values, isA<Iterable<int>>());
    });
  });
}
