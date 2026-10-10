import 'package:flutter/material.dart';

import '../../suggestions/domain/suggestion.dart';
import '../domain/trip_days.dart';
import 'itinerary_item_tile.dart';

class ItineraryDaySection extends StatelessWidget {
  final int dayIndex;
  final DateTime startDate;
  final List<Suggestion> items;
  final String currency;
  final bool isOrganizer;
  final bool isArchived;
  final VoidCallback onAddSuggestion;
  final ValueChanged<Suggestion> onMoveItem;
  final ValueChanged<Suggestion> onUnscheduleItem;
  final ReorderCallback? onReorderItems;

  const ItineraryDaySection({
    super.key,
    required this.dayIndex,
    required this.startDate,
    required this.items,
    required this.currency,
    required this.isOrganizer,
    required this.isArchived,
    required this.onAddSuggestion,
    required this.onMoveItem,
    required this.onUnscheduleItem,
    this.onReorderItems,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerText = formatDayHeader(startDate, dayIndex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headerText,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${items.length} ${items.length == 1 ? 'activity' : 'activities'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isOrganizer && !isArchived)
                IconButton.filledTonal(
                  onPressed: onAddSuggestion,
                  icon: const Icon(Icons.add, size: 20),
                  tooltip: 'Add suggestion to $headerText',
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Items List or Empty State
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 16.0,
              horizontal: 8.0,
            ),
            child: Center(
              child: Text(
                'No activities scheduled for this day yet.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          )
        else if (isOrganizer &&
            !isArchived &&
            onReorderItems != null &&
            items.length > 1)
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            // ignore: deprecated_member_use
            onReorder: onReorderItems!,
            itemBuilder: (context, index) {
              final suggestion = items[index];
              return Container(
                key: ValueKey(suggestion.id),
                child: ItineraryItemTile(
                  suggestion: suggestion,
                  currency: currency,
                  isOrganizer: isOrganizer,
                  isArchived: isArchived,
                  onMoveToDay: () => onMoveItem(suggestion),
                  onUnschedule: () => onUnscheduleItem(suggestion),
                ),
              );
            },
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final suggestion = items[index];
              return ItineraryItemTile(
                key: ValueKey(suggestion.id),
                suggestion: suggestion,
                currency: currency,
                isOrganizer: isOrganizer,
                isArchived: isArchived,
                onMoveToDay: () => onMoveItem(suggestion),
                onUnschedule: () => onUnscheduleItem(suggestion),
              );
            },
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}
