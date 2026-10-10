import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money.dart';
import '../../../core/widgets/app_empty.dart';
import '../../../core/widgets/app_error.dart';
import '../../../core/widgets/app_loading.dart';
import '../../suggestions/domain/suggestion.dart';
import '../../suggestions/domain/suggestion_category.dart';
import '../data/itinerary_providers.dart';
import '../domain/trip_days.dart';

class PendingSuggestionsSheet extends ConsumerWidget {
  final String tripId;
  final int dayIndex;
  final DateTime startDate;
  final String currency;
  final ValueChanged<Suggestion> onScheduleSuggestion;

  const PendingSuggestionsSheet({
    super.key,
    required this.tripId,
    required this.dayIndex,
    required this.startDate,
    required this.currency,
    required this.onScheduleSuggestion,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pendingAsync = ref.watch(pendingSuggestionsProvider(tripId));
    final dayTitle = formatDayHeader(startDate, dayIndex);

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add to $dayTitle',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Select a pending suggestion below',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: pendingAsync.when(
                loading: () =>
                    const AppLoading(message: 'Loading pending suggestions...'),
                error: (error, stack) => AppError(
                  message: 'Failed to load suggestions: $error',
                  onRetry: () =>
                      ref.invalidate(pendingSuggestionsProvider(tripId)),
                ),
                data: (pendingItems) {
                  if (pendingItems.isEmpty) {
                    return const AppEmpty(
                      title: 'No pending suggestions',
                      message: 'All suggestions have already been scheduled into the itinerary.',
                      icon: Icons.check_circle_outline,
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: pendingItems.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = pendingItems[index];
                      final category = getCategoryInfo(item.category);
                      final scoreText = item.score >= 0
                          ? '+${item.score}'
                          : '${item.score}';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Icon(
                            category.icon,
                            size: 20,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        title: Text(
                          item.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          item.estimatedCost != null && item.estimatedCost! > 0
                              ? '${category.label} · ${formatMinorUnits(item.estimatedCost!, currency)}'
                              : category.label,
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: item.score > 0
                                ? theme.colorScheme.secondaryContainer
                                : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$scoreText votes',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: item.score > 0
                                  ? theme.colorScheme.onSecondaryContainer
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          onScheduleSuggestion(item);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
