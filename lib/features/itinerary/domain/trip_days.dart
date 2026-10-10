import 'package:intl/intl.dart';

/// Pure logic for trip day calculations.
/// Computes total inclusive trip days safe against time zones and daylight savings.
int tripDays(DateTime startDate, DateTime endDate) {
  final s = DateTime(startDate.year, startDate.month, startDate.day);
  final e = DateTime(endDate.year, endDate.month, endDate.day);
  if (e.isBefore(s)) return 1;
  return e.difference(s).inDays + 1;
}

/// Helper to get the DateTime for a specific 0-based dayIndex.
DateTime dayDate(DateTime startDate, int dayIndex) {
  final s = DateTime(startDate.year, startDate.month, startDate.day);
  return DateTime(s.year, s.month, s.day + dayIndex);
}

/// Formats a day header label, e.g. "Day 1 · Mon 12 Oct".
String formatDayHeader(DateTime startDate, int dayIndex) {
  final date = dayDate(startDate, dayIndex);
  final formattedDate = DateFormat('EEE d MMM').format(date);
  return 'Day ${dayIndex + 1} · $formattedDate';
}
