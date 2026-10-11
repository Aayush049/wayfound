import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfound/features/expenses/data/expense_repository.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late ExpenseRepository repository;

  const tripId = 'trip_expense_repo_test';
  const userUid = 'user_creator';
  const member2Uid = 'user_member2';
  const expenseId = 'exp_123';

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repository = ExpenseRepository(firestore: fakeFirestore);
  });

  group('ExpenseRepository Unit Tests', () {
    test('createExpense adds a document with exact payload keys', () async {
      final date = DateTime(2026, 11, 2);
      await repository.createExpense(
        tripId: tripId,
        amount: 1500,
        description: 'Ramen Dinner',
        paidBy: userUid,
        participantIds: [userUid, member2Uid],
        createdBy: userUid,
        date: date,
      );

      final snapshot = await fakeFirestore
          .collection('trips')
          .doc(tripId)
          .collection('expenses')
          .get();

      expect(snapshot.docs.length, equals(1));
      final data = snapshot.docs.first.data();
      expect(data['amount'], equals(1500));
      expect(data['description'], equals('Ramen Dinner'));
      expect(data['paidBy'], equals(userUid));
      expect(data['participantIds'], equals([userUid, member2Uid]));
      expect(data['createdBy'], equals(userUid));
      expect(data['date'], isA<Timestamp>());
      expect(data['createdAt'], isNotNull);
      expect(
        data.keys.toSet(),
        equals({
          'amount',
          'description',
          'paidBy',
          'participantIds',
          'createdBy',
          'date',
          'createdAt',
        }),
      );
    });

    test('updateExpense modifies allowed fields', () async {
      final docRef = fakeFirestore
          .collection('trips')
          .doc(tripId)
          .collection('expenses')
          .doc(expenseId);

      await docRef.set({
        'amount': 1000,
        'description': 'Original',
        'paidBy': userUid,
        'participantIds': [userUid],
        'createdBy': userUid,
        'date': Timestamp.fromDate(DateTime(2026, 11, 1)),
        'createdAt': Timestamp.now(),
      });

      final newDate = DateTime(2026, 11, 5);
      await repository.updateExpense(
        tripId: tripId,
        expenseId: expenseId,
        amount: 2500,
        description: 'Updated Description',
        paidBy: member2Uid,
        participantIds: [userUid, member2Uid],
        date: newDate,
      );

      final updatedDoc = await docRef.get();
      final data = updatedDoc.data()!;
      expect(data['amount'], equals(2500));
      expect(data['description'], equals('Updated Description'));
      expect(data['paidBy'], equals(member2Uid));
      expect(data['participantIds'], equals([userUid, member2Uid]));
      expect(data['createdBy'], equals(userUid)); // Unchanged
    });

    test('deleteExpense removes document from Firestore', () async {
      final docRef = fakeFirestore
          .collection('trips')
          .doc(tripId)
          .collection('expenses')
          .doc(expenseId);

      await docRef.set({'description': 'To delete'});

      await repository.deleteExpense(tripId: tripId, expenseId: expenseId);

      final doc = await docRef.get();
      expect(doc.exists, isFalse);
    });

    test(
      'watchExpenses streams and sorts expenses by date DESC, then createdAt DESC',
      () async {
        final colRef = fakeFirestore
            .collection('trips')
            .doc(tripId)
            .collection('expenses');

        final t1 = DateTime(2026, 11, 1, 10, 0);
        final t2 = DateTime(2026, 11, 3, 12, 0);
        final t3 = DateTime(2026, 11, 3, 14, 0);

        await colRef.doc('e1').set({
          'amount': 1000,
          'description': 'Earliest Date',
          'paidBy': userUid,
          'participantIds': [userUid],
          'createdBy': userUid,
          'date': Timestamp.fromDate(t1),
          'createdAt': Timestamp.fromDate(t1),
        });

        await colRef.doc('e2').set({
          'amount': 2000,
          'description': 'Later Date, Earlier CreatedAt',
          'paidBy': userUid,
          'participantIds': [userUid],
          'createdBy': userUid,
          'date': Timestamp.fromDate(t2),
          'createdAt': Timestamp.fromDate(t2),
        });

        await colRef.doc('e3').set({
          'amount': 3000,
          'description': 'Later Date, Later CreatedAt',
          'paidBy': userUid,
          'participantIds': [userUid],
          'createdBy': userUid,
          'date': Timestamp.fromDate(t2),
          'createdAt': Timestamp.fromDate(t3),
        });

        final stream = repository.watchExpenses(tripId);
        final list = await stream.first;

        expect(list.length, equals(3));
        expect(list[0].description, equals('Later Date, Later CreatedAt'));
        expect(list[1].description, equals('Later Date, Earlier CreatedAt'));
        expect(list[2].description, equals('Earliest Date'));
      },
    );
  });
}
