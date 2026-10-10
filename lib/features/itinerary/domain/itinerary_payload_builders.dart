/// Pure payload builders for scheduling operations.
/// Guarantees exact field key sets matching security rules.
class ItineraryPayloadBuilders {
  ItineraryPayloadBuilders._();

  /// Payload for scheduling or moving a suggestion to a day and order.
  static Map<String, dynamic> buildSchedulePayload({
    required int dayIndex,
    required int order,
  }) {
    return {'status': 'scheduled', 'dayIndex': dayIndex, 'order': order};
  }

  /// Payload for unscheduling a suggestion back to pending.
  static Map<String, dynamic> buildUnschedulePayload() {
    return {'status': 'pending', 'dayIndex': null, 'order': null};
  }
}
