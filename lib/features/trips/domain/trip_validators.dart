import 'currencies.dart';

/// Validator for Trip Name (1 to 60 chars trimmed).
String? validateTripName(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Trip name is required';
  }
  final trimmed = value.trim();
  if (trimmed.length > 60) {
    return 'Trip name must be 60 characters or less';
  }
  return null;
}

/// Validator for Trip Destination (1 to 80 chars trimmed).
String? validateDestination(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Destination is required';
  }
  final trimmed = value.trim();
  if (trimmed.length > 80) {
    return 'Destination must be 80 characters or less';
  }
  return null;
}

/// Validator for Date Range (start and end required, end not before start).
String? validateDateRange(DateTime? startDate, DateTime? endDate) {
  if (startDate == null) {
    return 'Start date is required';
  }
  if (endDate == null) {
    return 'End date is required';
  }
  // Compare date components only (midnight)
  final startDay = DateTime(startDate.year, startDate.month, startDate.day);
  final endDay = DateTime(endDate.year, endDate.month, endDate.day);
  if (endDay.isBefore(startDay)) {
    return 'End date cannot be before start date';
  }
  return null;
}

/// Validator for Currency selection.
String? validateCurrencySelection(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Please select a currency';
  }
  if (!isSupportedCurrency(value)) {
    return 'Selected currency is not supported';
  }
  return null;
}
