import 'dart:math';

import 'suggestion.dart';

class VoteTransitionResult {
  /// The new value for the vote document: 1 for up, -1 for down, or null if deleted.
  final int? newVoteValue;

  /// Change to upCount (+1, 0, or -1).
  final int upDelta;

  /// Change to downCount (+1, 0, or -1).
  final int downDelta;

  const VoteTransitionResult({
    required this.newVoteValue,
    required this.upDelta,
    required this.downDelta,
  });

  /// Computes the new upCount, strictly enforcing that counters never go negative.
  int computeNewUpCount(int currentUpCount) {
    return max(0, currentUpCount + upDelta);
  }

  /// Computes the new downCount, strictly enforcing that counters never go negative.
  int computeNewDownCount(int currentDownCount) {
    return max(0, currentDownCount + downDelta);
  }
}

/// Computes the pure vote transition for a suggestion.
///
/// [currentVoteValue]: 0 (no vote), 1 (upvote), or -1 (downvote).
/// [targetVoteValue]: 1 (upvote tap) or -1 (downvote tap).
///
/// Transitions:
/// 1. No vote (0) + Up (1) -> Vote 1, upCount +1, downCount +0
/// 2. No vote (0) + Down (-1) -> Vote -1, upCount +0, downCount +1
/// 3. Up (1) + Down (-1) -> Vote -1, upCount -1, downCount +1
/// 4. Down (-1) + Up (1) -> Vote 1, upCount +1, downCount -1
/// 5. Up (1) + Up (1) -> Delete vote (null), upCount -1, downCount +0
/// 6. Down (-1) + Down (-1) -> Delete vote (null), upCount +0, downCount -1
VoteTransitionResult computeVoteTransition({
  required int currentVoteValue,
  required int targetVoteValue,
}) {
  assert(
    currentVoteValue == 0 || currentVoteValue == 1 || currentVoteValue == -1,
    'currentVoteValue must be 0, 1, or -1',
  );
  assert(
    targetVoteValue == 1 || targetVoteValue == -1,
    'targetVoteValue must be 1 or -1',
  );

  if (currentVoteValue == targetVoteValue) {
    // Tapping the same vote again removes the vote
    final upDelta = currentVoteValue == 1 ? -1 : 0;
    final downDelta = currentVoteValue == -1 ? -1 : 0;
    return VoteTransitionResult(
      newVoteValue: null,
      upDelta: upDelta,
      downDelta: downDelta,
    );
  }

  if (currentVoteValue == 0) {
    // New vote
    final upDelta = targetVoteValue == 1 ? 1 : 0;
    final downDelta = targetVoteValue == -1 ? 1 : 0;
    return VoteTransitionResult(
      newVoteValue: targetVoteValue,
      upDelta: upDelta,
      downDelta: downDelta,
    );
  }

  // Flipping vote (from 1 to -1, or from -1 to 1)
  final upDelta = targetVoteValue == 1 ? 1 : -1;
  final downDelta = targetVoteValue == -1 ? 1 : -1;
  return VoteTransitionResult(
    newVoteValue: targetVoteValue,
    upDelta: upDelta,
    downDelta: downDelta,
  );
}

/// Sorts suggestions by score descending, ties broken by oldest createdAt first.
List<Suggestion> sortSuggestions(List<Suggestion> suggestions) {
  final list = List<Suggestion>.from(suggestions);
  list.sort((a, b) {
    final scoreComp = b.score.compareTo(a.score);
    if (scoreComp != 0) return scoreComp;
    return a.createdAt.compareTo(b.createdAt);
  });
  return list;
}
