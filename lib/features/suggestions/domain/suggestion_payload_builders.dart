import 'package:cloud_firestore/cloud_firestore.dart';

class SuggestionPayloadBuilders {
  /// Builds the exact 11-key map required by security rules for creating a suggestion.
  static Map<String, dynamic> buildSuggestionCreatePayload({
    required String title,
    required String note,
    required int? estimatedCost,
    required String category,
    required String authorId,
  }) {
    return {
      'title': title.trim(),
      'note': note.trim(),
      'estimatedCost': estimatedCost,
      'category': category.toLowerCase().trim(),
      'authorId': authorId,
      'upCount': 0,
      'downCount': 0,
      'status': 'pending',
      'dayIndex': null,
      'order': null,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// Builds the update payload for editing suggestion content.
  /// Only contains title, note, estimatedCost, category.
  static Map<String, dynamic> buildSuggestionUpdatePayload({
    required String title,
    required String note,
    required int? estimatedCost,
    required String category,
  }) {
    return {
      'title': title.trim(),
      'note': note.trim(),
      'estimatedCost': estimatedCost,
      'category': category.toLowerCase().trim(),
    };
  }

  /// Builds the counter update payload for suggestion votes.
  static Map<String, dynamic> buildSuggestionCountersPayload({
    required int upCount,
    required int downCount,
  }) {
    return {'upCount': upCount, 'downCount': downCount};
  }

  /// Builds the exact 2-key map required by security rules for setting a vote document.
  static Map<String, dynamic> buildVotePayload({required int value}) {
    assert(value == 1 || value == -1, 'Vote value must be +1 or -1');
    return {'value': value, 'updatedAt': FieldValue.serverTimestamp()};
  }
}
