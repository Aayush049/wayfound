import '../../suggestions/domain/suggestion.dart';

/// Structure for a reorder update of a suggestion item.
class ReorderItemUpdate {
  final String suggestionId;
  final int newOrder;

  const ReorderItemUpdate({required this.suggestionId, required this.newOrder});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReorderItemUpdate &&
          runtimeType == other.runtimeType &&
          suggestionId == other.suggestionId &&
          newOrder == other.newOrder;

  @override
  int get hashCode => suggestionId.hashCode ^ newOrder.hashCode;

  @override
  String toString() =>
      'ReorderItemUpdate(suggestionId: $suggestionId, newOrder: $newOrder)';
}

/// Result of planning a schedule update (schedule, move day, or unschedule).
class ItineraryScheduleUpdate {
  final String suggestionId;
  final String status;
  final int? dayIndex;
  final int? order;

  const ItineraryScheduleUpdate({
    required this.suggestionId,
    required this.status,
    this.dayIndex,
    this.order,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItineraryScheduleUpdate &&
          runtimeType == other.runtimeType &&
          suggestionId == other.suggestionId &&
          status == other.status &&
          dayIndex == other.dayIndex &&
          order == other.order;

  @override
  int get hashCode =>
      suggestionId.hashCode ^
      status.hashCode ^
      dayIndex.hashCode ^
      order.hashCode;
}

/// Groups scheduled suggestions by dayIndex, sorted by order, then createdAt, then id.
Map<int, List<Suggestion>> groupByDay(List<Suggestion> suggestions) {
  final scheduled = suggestions.where((s) {
    return s.status == 'scheduled' && s.dayIndex != null;
  }).toList();

  final map = <int, List<Suggestion>>{};

  for (final item in scheduled) {
    final day = item.dayIndex!;
    map.putIfAbsent(day, () => []).add(item);
  }

  for (final day in map.keys) {
    map[day]!.sort((a, b) {
      final orderA = a.order ?? 0;
      final orderB = b.order ?? 0;
      if (orderA != orderB) {
        return orderA.compareTo(orderB);
      }
      final createdComp = a.createdAt.compareTo(b.createdAt);
      if (createdComp != 0) return createdComp;
      return a.id.compareTo(b.id);
    });
  }

  return map;
}

/// Returns the next order index for adding a suggestion to a day.
int nextOrderForDay(List<Suggestion> daySuggestions) {
  if (daySuggestions.isEmpty) return 0;
  var maxOrder = -1;
  for (final s in daySuggestions) {
    if (s.order != null && s.order! > maxOrder) {
      maxOrder = s.order!;
    }
  }
  return maxOrder >= 0 ? maxOrder + 1 : daySuggestions.length;
}

/// Plans reordering within a single day.
/// Returns the minimal list of [ReorderItemUpdate] where [order] changes.
List<ReorderItemUpdate> planReorder(
  List<Suggestion> dayItems,
  int oldIndex,
  int newIndex,
) {
  if (dayItems.isEmpty) return [];
  var targetNewIndex = newIndex;
  if (targetNewIndex > oldIndex) {
    targetNewIndex -= 1;
  }
  if (oldIndex < 0 || oldIndex >= dayItems.length) return [];
  if (targetNewIndex < 0 || targetNewIndex >= dayItems.length) return [];
  if (oldIndex == targetNewIndex) return [];

  final mutableList = List<Suggestion>.from(dayItems);
  final movedItem = mutableList.removeAt(oldIndex);
  mutableList.insert(targetNewIndex, movedItem);

  final updates = <ReorderItemUpdate>[];
  for (var i = 0; i < mutableList.length; i++) {
    if (mutableList[i].order != i) {
      updates.add(
        ReorderItemUpdate(suggestionId: mutableList[i].id, newOrder: i),
      );
    }
  }
  return updates;
}

/// Plans moving a suggestion to a target day (appended at the end of the day).
ItineraryScheduleUpdate planMoveToDay(
  Suggestion item,
  int targetDayIndex,
  List<Suggestion> targetDaySuggestions,
) {
  final newOrder = nextOrderForDay(targetDaySuggestions);
  return ItineraryScheduleUpdate(
    suggestionId: item.id,
    status: 'scheduled',
    dayIndex: targetDayIndex,
    order: newOrder,
  );
}

/// Plans unscheduling a suggestion back to pending.
ItineraryScheduleUpdate planUnschedule(Suggestion item) {
  return ItineraryScheduleUpdate(
    suggestionId: item.id,
    status: 'pending',
    dayIndex: null,
    order: null,
  );
}
