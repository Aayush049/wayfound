import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase_providers.dart';
import '../domain/settlement.dart';
import '../domain/settlement_payload_builders.dart';

class SettlementRepository {
  final FirebaseFirestore _firestore;

  SettlementRepository(this._firestore);

  Stream<List<Settlement>> watchSettlements(String tripId) {
    return _firestore
        .collection('trips')
        .doc(tripId)
        .collection('settlements')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Settlement.fromFirestore(doc))
              .toList(),
        );
  }

  Future<void> createPending({
    required String tripId,
    required String fromUid,
    required String toUid,
    required int amount,
  }) async {
    final payload = buildCreateSettlementPayload(
      fromUid: fromUid,
      toUid: toUid,
      amount: amount,
    );
    await _firestore
        .collection('trips')
        .doc(tripId)
        .collection('settlements')
        .add(payload);
  }

  Future<void> resolve({
    required String tripId,
    required String settlementId,
    required bool confirmed,
  }) async {
    final payload = buildResolveSettlementPayload(confirmed: confirmed);
    await _firestore
        .collection('trips')
        .doc(tripId)
        .collection('settlements')
        .doc(settlementId)
        .update(payload);
  }

  Future<void> cancelPending({
    required String tripId,
    required String settlementId,
  }) async {
    await _firestore
        .collection('trips')
        .doc(tripId)
        .collection('settlements')
        .doc(settlementId)
        .delete();
  }
}

final settlementRepositoryProvider = Provider<SettlementRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return SettlementRepository(firestore);
});
