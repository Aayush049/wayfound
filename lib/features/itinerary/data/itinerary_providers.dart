import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase_providers.dart';
import '../../suggestions/data/suggestions_providers.dart';
import '../../suggestions/domain/suggestion.dart';
import '../domain/itinerary_logic.dart';
import 'itinerary_repository.dart';

final itineraryRepositoryProvider = Provider<ItineraryRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return ItineraryRepository(firestore: firestore);
});

/// Derives scheduled suggestions from the main suggestions stream (one listener).
final scheduledSuggestionsProvider =
    Provider.family<AsyncValue<List<Suggestion>>, String>((ref, tripId) {
      final suggestionsAsync = ref.watch(suggestionsStreamProvider(tripId));
      return suggestionsAsync.whenData((suggestions) {
        return suggestions.where((s) => s.status == 'scheduled').toList();
      });
    });

/// Derives grouped itinerary map (`Map<int, List<Suggestion>>`) from scheduled suggestions.
final groupedItineraryProvider =
    Provider.family<AsyncValue<Map<int, List<Suggestion>>>, String>((
      ref,
      tripId,
    ) {
      final scheduledAsync = ref.watch(scheduledSuggestionsProvider(tripId));
      return scheduledAsync.whenData((scheduled) {
        return groupByDay(scheduled);
      });
    });

/// Derives pending suggestions sorted by score descending, then oldest createdAt.
final pendingSuggestionsProvider =
    Provider.family<AsyncValue<List<Suggestion>>, String>((ref, tripId) {
      final suggestionsAsync = ref.watch(suggestionsStreamProvider(tripId));
      return suggestionsAsync.whenData((suggestions) {
        final pending = suggestions
            .where((s) => s.status == 'pending')
            .toList();
        pending.sort((a, b) {
          final scoreComp = b.score.compareTo(a.score);
          if (scoreComp != 0) return scoreComp;
          final timeComp = a.createdAt.compareTo(b.createdAt);
          if (timeComp != 0) return timeComp;
          return a.id.compareTo(b.id);
        });
        return pending;
      });
    });
