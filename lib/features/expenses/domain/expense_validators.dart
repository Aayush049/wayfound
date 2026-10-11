import '../../../core/money.dart';

/// Validation functions for expense input fields.
class ExpenseValidators {
  /// Validates expense description: string, 1 to 100 characters.
  static String? validateDescription(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Description is required';
    }
    final trimmed = value.trim();
    if (trimmed.length > 100) {
      return 'Description must be at most 100 characters';
    }
    return null;
  }

  /// Validates expense amount string input using [tryParseMinorUnits] for currency [currencyCode],
  /// or validates integer minor units.
  static String? validateAmountInput(String? input, String currencyCode) {
    if (input == null || input.trim().isEmpty) {
      return 'Amount is required';
    }
    final (val, err) = tryParseMinorUnits(input, currencyCode);
    if (err != null) {
      return err;
    }
    if (val == null) {
      return 'Amount is required';
    }
    if (val <= 0) {
      return 'Amount must be greater than 0';
    }
    if (val > kMaxMinorUnitsCap) {
      return 'Amount exceeds maximum allowed limit';
    }
    return null;
  }

  /// Validates expense amount in minor units: integer, 1 to 100,000,000,000.
  static String? validateAmount(int? amountInMinorUnits) {
    if (amountInMinorUnits == null) {
      return 'Amount is required';
    }
    if (amountInMinorUnits <= 0) {
      return 'Amount must be greater than 0';
    }
    if (amountInMinorUnits > kMaxMinorUnitsCap) {
      return 'Amount exceeds maximum allowed limit';
    }
    return null;
  }

  /// Validates paidBy user ID: non-empty string.
  static String? validatePaidBy(String? paidBy, List<String> memberIds) {
    if (paidBy == null || paidBy.isEmpty) {
      return 'Payer is required';
    }
    if (!memberIds.contains(paidBy)) {
      return 'Selected payer is not an active member';
    }
    return null;
  }

  /// Validates participant IDs: list of 1 to 15 distinct member uids.
  static String? validateParticipants(
    List<String>? participants,
    List<String> memberIds,
  ) {
    if (participants == null || participants.isEmpty) {
      return 'Select at least one participant';
    }
    if (participants.length > 15) {
      return 'Cannot have more than 15 participants';
    }
    final set = participants.toSet();
    if (set.length != participants.length) {
      return 'Participants must be distinct';
    }
    for (final p in participants) {
      if (!memberIds.contains(p)) {
        return 'Participant $p is not an active member';
      }
    }
    return null;
  }
}
