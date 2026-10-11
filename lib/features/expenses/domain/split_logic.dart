/// Computes equal split of an amount in minor units among participant UIDs.
///
/// Participants are sorted by UID ascending.
/// Each participant receives amount ~/ n minor units, and the first (amount % n)
/// participants receive 1 extra minor unit, ensuring shares always sum
/// exactly to amount.
Map<String, int> splitEqually(int amount, List<String> participantIds) {
  if (participantIds.isEmpty) {
    return const {};
  }
  // Contract check: distinct uids
  final sorted = List<String>.from(participantIds)..sort();
  final n = sorted.length;
  final baseShare = amount ~/ n;
  final remainder = amount % n;

  final result = <String, int>{};
  for (var i = 0; i < n; i++) {
    final uid = sorted[i];
    final extra = i < remainder ? 1 : 0;
    result[uid] = baseShare + extra;
  }

  return result;
}
