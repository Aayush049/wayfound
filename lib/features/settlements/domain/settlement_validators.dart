import '../../../core/money.dart';

String? validateSettlementAmount(
  String? input,
  String currencyCode,
  int maxAllowedMinorUnits,
) {
  if (input == null || input.trim().isEmpty) {
    return 'Please enter an amount.';
  }

  final (value, error) = tryParseMinorUnits(input, currencyCode);
  if (error != null) {
    return error;
  }
  if (value == null || value <= 0) {
    return 'Amount must be greater than zero.';
  }
  if (value > maxAllowedMinorUnits) {
    return 'Amount cannot exceed current debt (${formatMinorUnits(maxAllowedMinorUnits, currencyCode)}).';
  }

  return null;
}
