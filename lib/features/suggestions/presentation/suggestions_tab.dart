import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_empty.dart';
import '../../../core/widgets/app_error.dart';
import '../../../core/widgets/app_loading.dart';
import '../../auth/data/auth_provider.dart';
import '../../trips/data/trips_providers.dart';
import '../../trips/domain/trip.dart';
import '../data/suggestions_providers.dart';
import 'suggestion_card.dart';

class SuggestionsTab extends ConsumerWidget {
  final Trip trip;

  const SuggestionsTab({super.key, required this.trip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authUserProvider).asData?.value;
    final currentUserId = authUser?.uid ?? '';
    final isOrganizer = trip.isOrganizer(currentUserId);

    final suggestionsAsync = ref.watch(suggestionsStreamProvider(trip.id));
    final membersAsync = ref.watch(tripMembersProvider(trip.id));

    final members = membersAsync.asData?.value ?? [];

    return Scaffold(
      body: suggestionsAsync.when(
        loading: () => const AppLoading(message: 'Loading suggestions...'),
        error: (err, stack) => AppError(
          message: 'Unable to load suggestions: ${err.toString()}',
          onRetry: () => ref.invalidate(suggestionsStreamProvider(trip.id)),
        ),
        data: (suggestions) {
          if (suggestions.isEmpty) {
            return AppEmpty(
              title: 'No suggestions yet',
              message: 'Add the first idea for this trip!',
              icon: Icons.lightbulb_outline,
              actionLabel: 'Add Suggestion',
              onAction: () => context.push('/trip/${trip.id}/suggestions/add'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: suggestions.length,
            itemBuilder: (context, index) {
              final suggestion = suggestions[index];
              return SuggestionCard(
                key: ValueKey(suggestion.id),
                suggestion: suggestion,
                currency: trip.currency,
                currentUserId: currentUserId,
                isOrganizer: isOrganizer,
                members: members,
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/trip/${trip.id}/suggestions/add'),
        icon: const Icon(Icons.add),
        label: const Text('Add Suggestion'),
      ),
    );
  }
}
