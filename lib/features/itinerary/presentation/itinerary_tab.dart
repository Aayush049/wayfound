import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_empty.dart';
import '../../../core/widgets/app_error.dart';
import '../../../core/widgets/app_loading.dart';
import '../../suggestions/domain/suggestion.dart';
import '../data/itinerary_providers.dart';
import '../domain/itinerary_logic.dart';
import '../domain/trip_days.dart';
import 'day_picker_sheet.dart';
import 'itinerary_day_section.dart';
import 'pending_suggestions_sheet.dart';

class ItineraryTab extends ConsumerWidget {
  final String tripId;
  final DateTime startDate;
  final DateTime endDate;
  final String currency;
  final bool isOrganizer;
  final bool isArchived;

  const ItineraryTab({
    super.key,
    required this.tripId,
    required this.startDate,
    required this.endDate,
    required this.currency,
    required this.isOrganizer,
    required this.isArchived,
  });

  void _showAddSuggestionSheet(
    BuildContext context,
    WidgetRef ref,
    int dayIndex,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => PendingSuggestionsSheet(
        tripId: tripId,
        dayIndex: dayIndex,
        startDate: startDate,
        currency: currency,
        onScheduleSuggestion: (suggestion) async {
          final grouped =
              ref.read(groupedItineraryProvider(tripId)).value ?? {};
          final currentDayItems = grouped[dayIndex] ?? [];
          final order = nextOrderForDay(currentDayItems);

          try {
            await ref
                .read(itineraryRepositoryProvider)
                .scheduleSuggestion(
                  tripId: tripId,
                  suggestionId: suggestion.id,
                  dayIndex: dayIndex,
                  order: order,
                );
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Scheduled "${suggestion.title}" into itinerary',
                  ),
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to schedule item: $e'),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _showMoveDaySheet(
    BuildContext context,
    WidgetRef ref,
    Suggestion suggestion,
    int totalDaysCount,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => DayPickerSheet(
        startDate: startDate,
        totalDays: totalDaysCount,
        currentDayIndex: suggestion.dayIndex,
        onDaySelected: (targetDayIndex) async {
          if (targetDayIndex == suggestion.dayIndex) return;

          final grouped =
              ref.read(groupedItineraryProvider(tripId)).value ?? {};
          final targetItems = grouped[targetDayIndex] ?? [];
          final targetOrder = nextOrderForDay(targetItems);

          try {
            await ref
                .read(itineraryRepositoryProvider)
                .moveToDay(
                  tripId: tripId,
                  suggestionId: suggestion.id,
                  targetDayIndex: targetDayIndex,
                  targetOrder: targetOrder,
                );
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Moved "${suggestion.title}" to ${formatDayHeader(startDate, targetDayIndex)}',
                  ),
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to move item: $e'),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _handleUnschedule(
    BuildContext context,
    WidgetRef ref,
    Suggestion suggestion,
  ) async {
    try {
      await ref
          .read(itineraryRepositoryProvider)
          .unschedule(tripId: tripId, suggestionId: suggestion.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed "${suggestion.title}" from itinerary'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove item: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _handleReorder(
    BuildContext context,
    WidgetRef ref,
    int dayIndex,
    List<Suggestion> currentItems,
    int oldIndex,
    int newIndex,
  ) async {
    final updates = planReorder(currentItems, oldIndex, newIndex);
    if (updates.isEmpty) return;

    try {
      await ref
          .read(itineraryRepositoryProvider)
          .reorderDay(tripId: tripId, dayIndex: dayIndex, updates: updates);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update order: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupedAsync = ref.watch(groupedItineraryProvider(tripId));
    final totalDaysCount = tripDays(startDate, endDate);

    return groupedAsync.when(
      loading: () => const AppLoading(message: 'Loading itinerary...'),
      error: (error, stack) => AppError(
        message: 'Failed to load itinerary: $error',
        onRetry: () => ref.invalidate(groupedItineraryProvider(tripId)),
      ),
      data: (groupedMap) {
        final totalScheduled = groupedMap.values.fold(
          0,
          (sum, list) => sum + list.length,
        );

        if (totalScheduled == 0) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(groupedItineraryProvider(tripId));
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 32),
                AppEmpty(
                  title: 'No itinerary items scheduled yet',
                  message: isOrganizer
                      ? 'As an organizer, tap "+ Add to Day" on any day below or use "Add to itinerary" from the suggestions tab.'
                      : 'Organizers will schedule voted suggestions into the daily plan.',
                  icon: Icons.calendar_today,
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: List.generate(totalDaysCount, (index) {
                      return ItineraryDaySection(
                        dayIndex: index,
                        startDate: startDate,
                        items: const [],
                        currency: currency,
                        isOrganizer: isOrganizer,
                        isArchived: isArchived,
                        onAddSuggestion: () =>
                            _showAddSuggestionSheet(context, ref, index),
                        onMoveItem: (_) {},
                        onUnscheduleItem: (_) {},
                      );
                    }),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(groupedItineraryProvider(tripId));
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: totalDaysCount,
            itemBuilder: (context, index) {
              final dayItems = groupedMap[index] ?? [];
              return ItineraryDaySection(
                dayIndex: index,
                startDate: startDate,
                items: dayItems,
                currency: currency,
                isOrganizer: isOrganizer,
                isArchived: isArchived,
                onAddSuggestion: () =>
                    _showAddSuggestionSheet(context, ref, index),
                onMoveItem: (suggestion) =>
                    _showMoveDaySheet(context, ref, suggestion, totalDaysCount),
                onUnscheduleItem: (suggestion) =>
                    _handleUnschedule(context, ref, suggestion),
                onReorderItems: (oldIndex, newIndex) => _handleReorder(
                  context,
                  ref,
                  index,
                  dayItems,
                  oldIndex,
                  newIndex,
                ),
              );
            },
          ),
        );
      },
    );
  }
}
