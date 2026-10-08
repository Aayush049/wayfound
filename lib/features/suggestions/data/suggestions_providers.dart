import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase_providers.dart';
import '../domain/suggestion.dart';
import '../domain/vote.dart';
import 'suggestion_repository.dart';

final suggestionRepositoryProvider = Provider<SuggestionRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return SuggestionRepository(firestore: firestore);
});

final suggestionsStreamProvider =
    StreamProvider.family<List<Suggestion>, String>((ref, tripId) {
      final repository = ref.watch(suggestionRepositoryProvider);
      return repository.watchSuggestions(tripId);
    });

typedef MyVoteArgs = ({String tripId, String suggestionId, String userUid});

final myVoteStreamProvider = StreamProvider.family<Vote?, MyVoteArgs>((
  ref,
  args,
) {
  final repository = ref.watch(suggestionRepositoryProvider);
  return repository.watchMyVote(args.tripId, args.suggestionId, args.userUid);
});
