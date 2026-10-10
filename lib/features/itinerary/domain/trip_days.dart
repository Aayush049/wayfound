import 'package:intl/intl.dart';

/// Pure logic for trip day calculations.
/// Uses UTC calendar arithmetic to be safe against time zones and daylight savings.
/// A trip from Oct 10 to Oct 12 inclusive has 3 days: dayIndex 0, 1, 2.
int tripDays(DateTime startDate, DateTime endDate) {
  final s = DateTime.utc(startDate.year, startDate.month, startDate.day);
  final e = DateTime.utc(endDate.year, endDate.month, endDate.day);
  if (e.isBefore(s)) return 1;
  return e.difference(s).inDays + 1;
}

/// Helper to get the DateTime for a specific 0-based dayIndex.
/// Returns the calendar date at UTC midnight for that day.
DateTime dayDate(DateTime startDate, int dayIndex) {
  final s = DateTime.utc(startDate.year, startDate.month, startDate.day);
  return DateTime.utc(s.year, s.month, s.day + dayIndex);
}

/// Formats a day header label, e.g. "Day 1 · Mon 12 Oct".
String formatDayHeader(DateTime startDate, int dayIndex) {
  final date = dayDate(startDate, dayIndex);
  final formattedDate = DateFormat('EEE d MMM').format(date);
  return 'Day ${dayIndex + 1} · $formattedDate';
}
