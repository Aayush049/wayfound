import 'package:flutter/material.dart';

import '../../../core/money.dart';
import '../../suggestions/domain/suggestion.dart';
import '../../suggestions/domain/suggestion_category.dart';

class ItineraryItemTile extends StatelessWidget {
  final Suggestion suggestion;
  final String currency;
  final bool isOrganizer;
  final bool isArchived;
  final VoidCallback? onMoveToDay;
  final VoidCallback? onUnschedule;

  const ItineraryItemTile({
    super.key,
    required this.suggestion,
    required this.currency,
    required this.isOrganizer,
    required this.isArchived,
    this.onMoveToDay,
    this.onUnschedule,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = getCategoryInfo(suggestion.category);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Icon Chip
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                category.icon,
                size: 20,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (suggestion.note.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      suggestion.note,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (suggestion.estimatedCost != null &&
                      suggestion.estimatedCost! > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      formatMinorUnits(suggestion.estimatedCost!, currency),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Actions menu for organizer on non-archived trips
            if (isOrganizer && !isArchived)
              PopupMenuButton<String>(
                tooltip: 'Options',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  Icons.more_vert,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                onSelected: (value) {
                  if (value == 'move') {
                    onMoveToDay?.call();
                  } else if (value == 'unschedule') {
                    onUnschedule?.call();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'move',
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 20,
                          color: theme.colorScheme.onSurface,
                        ),
                        const SizedBox(width: 8),
                        const Text('Move to another day'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'unschedule',
                    child: Row(
                      children: [
                        Icon(
                          Icons.event_busy_outlined,
                          size: 20,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Remove from itinerary',
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
