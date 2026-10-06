import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfound/features/auth/domain/app_user.dart';

void main() {
  group('AppUser', () {
    test('toFirestoreCreate contains required fields without extra keys', () {
      const user = AppUser(
        uid: 'user-123',
        email: 'test@example.com',
        displayName: 'Test User',
        photoUrl: 'https://example.com/photo.jpg',
      );

      final map = user.toFirestoreCreate();

      expect(map['displayName'], equals('Test User'));
      expect(map['email'], equals('test@example.com'));
      expect(map['photoUrl'], equals('https://example.com/photo.jpg'));
      expect(map['createdAt'], isA<FieldValue>());
      // Must not contain 'uid' or 'updatedAt' as per strict rules
      expect(map.containsKey('uid'), isFalse);
      expect(map.containsKey('updatedAt'), isFalse);
    });

    test('toFirestoreUpdate contains only displayName and photoUrl', () {
      const user = AppUser(
        uid: 'user-123',
        email: 'test@example.com',
        displayName: 'Updated Name',
        photoUrl: 'https://example.com/new.jpg',
      );

      final map = user.toFirestoreUpdate();

      expect(map.keys, containsAll(['displayName', 'photoUrl']));
      expect(map.length, equals(2));
    });

    test('fromFirestore parses DocumentSnapshot correctly', () async {
      final firestore = FakeFirebaseFirestore();
      final docRef = firestore.collection('users').doc('user-999');

      await docRef.set({
        'displayName': 'Alice',
        'email': 'alice@example.com',
        'photoUrl': 'https://example.com/alice.png',
        'createdAt': Timestamp.now(),
      });

      final doc = await docRef.get();
      final appUser = AppUser.fromFirestore(doc);

      expect(appUser.uid, equals('user-999'));
      expect(appUser.displayName, equals('Alice'));
      expect(appUser.email, equals('alice@example.com'));
      expect(appUser.photoUrl, equals('https://example.com/alice.png'));
    });
  });
}
