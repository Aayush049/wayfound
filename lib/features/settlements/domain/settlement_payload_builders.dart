import 'package:cloud_firestore/cloud_firestore.dart';

Map<String, dynamic> buildCreateSettlementPayload({
  required String fromUid,
  required String toUid,
  required int amount,
}) {
  return {
    'fromUid': fromUid,
    'toUid': toUid,
    'amount': amount,
    'status': 'pending',
    'createdAt': FieldValue.serverTimestamp(),
    'resolvedAt': null,
  };
}

Map<String, dynamic> buildResolveSettlementPayload({
  required bool confirmed,
}) {
  return {
    'status': confirmed ? 'confirmed' : 'rejected',
    'resolvedAt': FieldValue.serverTimestamp(),
  };
}
