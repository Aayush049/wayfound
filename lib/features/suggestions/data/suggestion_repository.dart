import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/suggestion.dart';
import '../domain/suggestion_payload_builders.dart';
import '../domain/vote.dart';
import '../domain/vote_logic.dart';

class SuggestionRepository {
  final FirebaseFirestore _firestore;

  SuggestionRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Streams suggestions for a trip, sorted client-side by score DESC, then createdAt ASC.
  Stream<List<Suggestion>> watchSuggestions(String tripId) {
    return _firestore
        .collection('trips')
        .doc(tripId)
        .collection('suggestions')
        .snapshots()
        .map((snapshot) {
          final suggestions = snapshot.docs
              .map((doc) => Suggestion.fromFirestore(doc, tripId))
              .toList();
          return sortSuggestions(suggestions);
        });
  }

  /// Streams the current user's vote for a specific suggestion.
  Stream<Vote?> watchMyVote(
    String tripId,
    String suggestionId,
    String userUid,
  ) {
    return _firestore
        .collection('trips')
        .doc(tripId)
        .collection('suggestions')
        .doc(suggestionId)
        .collection('votes')
        .doc(userUid)
        .snapshots()
        .map((doc) => doc.exists ? Vote.fromFirestore(doc) : null);
  }

  /// Creates a new suggestion document.
  Future<void> createSuggestion({
    required String tripId,
    required String title,
    required String note,
    required int? estimatedCost,
    required String category,
    required String authorId,
  }) async {
    final payload = SuggestionPayloadBuilders.buildSuggestionCreatePayload(
      title: title,
      note: note,
      estimatedCost: estimatedCost,
      category: category,
      authorId: authorId,
    );

    await _firestore
        .collection('trips')
        .doc(tripId)
        .collection('suggestions')
        .add(payload);
  }

  /// Updates suggestion content (title, note, estimatedCost, category).
  Future<void> updateSuggestion({
    required String tripId,
    required String suggestionId,
    required String title,
    required String note,
    required int? estimatedCost,
    required String category,
  }) async {
    final payload = SuggestionPayloadBuilders.buildSuggestionUpdatePayload(
      title: title,
      note: note,
      estimatedCost: estimatedCost,
      category: category,
    );

    await _firestore
        .collection('trips')
        .doc(tripId)
        .collection('suggestions')
        .doc(suggestionId)
        .update(payload);
  }

  /// Deletes a suggestion document.
  Future<void> deleteSuggestion({
    required String tripId,
    required String suggestionId,
  }) async {
    await _firestore
        .collection('trips')
        .doc(tripId)
        .collection('suggestions')
        .doc(suggestionId)
        .delete();
  }

  /// Casts an upvote (+1) or downvote (-1) in ONE transaction.
  ///
  /// Reads the current vote document and suggestion document,
  /// computes the vote transition, then writes the vote document
  /// (set or delete) and updates the suggestion's absolute counter values.
  Future<void> castVote({
    required String tripId,
    required String suggestionId,
    required String userUid,
    required int targetVoteValue,
  }) async {
    final suggRef = _firestore
        .collection('trips')
        .doc(tripId)
        .collection('suggestions')
        .doc(suggestionId);
    final voteRef = suggRef.collection('votes').doc(userUid);

    await _firestore.runTransaction((tx) async {
      final suggSnapshot = await tx.get(suggRef);
      if (!suggSnapshot.exists) {
        throw Exception('Suggestion no longer exists.');
      }

      final voteSnapshot = await tx.get(voteRef);
      final currentVoteValue = voteSnapshot.exists
          ? (voteSnapshot.data()?['value'] as num?)?.toInt() ?? 0
          : 0;

      final transition = computeVoteTransition(
        currentVoteValue: currentVoteValue,
        targetVoteValue: targetVoteValue,
      );

      final currentUpCount =
          (suggSnapshot.data()?['upCount'] as num?)?.toInt() ?? 0;
      final currentDownCount =
          (suggSnapshot.data()?['downCount'] as num?)?.toInt() ?? 0;

      final newUpCount = transition.computeNewUpCount(currentUpCount);
      final newDownCount = transition.computeNewDownCount(currentDownCount);

      // Write suggestion absolute counters
      tx.update(
        suggRef,
        SuggestionPayloadBuilders.buildSuggestionCountersPayload(
          upCount: newUpCount,
          downCount: newDownCount,
        ),
      );

      // Write or delete vote document
      if (transition.newVoteValue != null) {
        tx.set(
          voteRef,
          SuggestionPayloadBuilders.buildVotePayload(
            value: transition.newVoteValue!,
          ),
        );
      } else {
        tx.delete(voteRef);
      }
    });
  }
}
