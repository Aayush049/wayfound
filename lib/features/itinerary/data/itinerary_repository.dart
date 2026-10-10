import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/itinerary_logic.dart';
import '../domain/itinerary_payload_builders.dart';

class ItineraryRepository {
  final FirebaseFirestore _firestore;

  ItineraryRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Schedules a pending suggestion to a dayIndex and order.
  Future<void> scheduleSuggestion({
    required String tripId,
    required String suggestionId,
    required int dayIndex,
    required int order,
  }) async {
    final ref = _firestore
        .collection('trips')
        .doc(tripId)
        .collection('suggestions')
        .doc(suggestionId);
    await ref.update(
      ItineraryPayloadBuilders.buildSchedulePayload(
        dayIndex: dayIndex,
        order: order,
      ),
    );
  }

  /// Moves a scheduled suggestion to another dayIndex and target order.
  Future<void> moveToDay({
    required String tripId,
    required String suggestionId,
    required int targetDayIndex,
    required int targetOrder,
  }) async {
    final ref = _firestore
        .collection('trips')
        .doc(tripId)
        .collection('suggestions')
        .doc(suggestionId);
    await ref.update(
      ItineraryPayloadBuilders.buildSchedulePayload(
        dayIndex: targetDayIndex,
        order: targetOrder,
      ),
    );
  }

  /// Performs ONE batched write to reorder items within a day.
  Future<void> reorderDay({
    required String tripId,
    required int dayIndex,
    required List<ReorderItemUpdate> updates,
  }) async {
    if (updates.isEmpty) return;
    final batch = _firestore.batch();
    for (final update in updates) {
      final ref = _firestore
          .collection('trips')
          .doc(tripId)
          .collection('suggestions')
          .doc(update.suggestionId);
      batch.update(
        ref,
        ItineraryPayloadBuilders.buildSchedulePayload(
          dayIndex: dayIndex,
          order: update.newOrder,
        ),
      );
    }
    await batch.commit();
  }

  /// Unschedules a scheduled suggestion back to pending.
  Future<void> unschedule({
    required String tripId,
    required String suggestionId,
  }) async {
    final ref = _firestore
        .collection('trips')
        .doc(tripId)
        .collection('suggestions')
        .doc(suggestionId);
    await ref.update(ItineraryPayloadBuilders.buildUnschedulePayload());
  }
}
