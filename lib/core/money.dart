import 'package:intl/intl.dart';

import '../features/trips/domain/currencies.dart';

/// Maximum allowed amount in minor units (100 billion = 100,000,000,000).
const int kMaxMinorUnitsCap = 100000000000;

/// Parses a user input string into an integer minor unit value for the given [currencyCode].
///
/// Returns null if [input] is null, empty or whitespace.
/// Throws [FormatException] if:
/// - input is non-numeric or negative
/// - input has too many decimal places for the currency (e.g. >2 for USD/INR, >0 for JPY)
/// - value exceeds [kMaxMinorUnitsCap] (100,000,000,000 minor units).
int? parseMinorUnits(String? input, String currencyCode) {
  if (input == null) return null;
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;

  if (trimmed.startsWith('-')) {
    throw const FormatException('Amount cannot be negative.');
  }

  final digits = getMinorUnitDigits(currencyCode);

  if (digits == 0) {
    if (trimmed.contains('.')) {
      final parts = trimmed.split('.');
      if (parts.length > 2) {
        throw const FormatException('Invalid number format.');
      }
      final decimals = parts[1];
      if (decimals.isNotEmpty && int.tryParse(decimals) != 0) {
        throw FormatException(
          '$currencyCode does not support decimal amounts.',
        );
      }
      final whole = int.tryParse(parts[0]);
      if (whole == null) {
        throw const FormatException('Invalid number format.');
      }
      if (whole < 0) {
        throw const FormatException('Amount cannot be negative.');
      }
      if (whole > kMaxMinorUnitsCap) {
        throw const FormatException('Amount exceeds maximum allowed limit.');
      }
      return whole;
    }
    final value = int.tryParse(trimmed);
    if (value == null) {
      throw const FormatException('Invalid number format.');
    }
    if (value < 0) {
      throw const FormatException('Amount cannot be negative.');
    }
    if (value > kMaxMinorUnitsCap) {
      throw const FormatException('Amount exceeds maximum allowed limit.');
    }
    return value;
  } else {
    if (trimmed.contains('.')) {
      final parts = trimmed.split('.');
      if (parts.length > 2) {
        throw const FormatException('Invalid number format.');
      }
      final wholeStr = parts[0].isEmpty ? '0' : parts[0];
      final whole = int.tryParse(wholeStr);
      if (whole == null) {
        throw const FormatException('Invalid number format.');
      }
      final fracStr = parts[1];
      if (fracStr.length > digits) {
        throw FormatException(
          'Amount cannot have more than $digits decimal places.',
        );
      }
      final paddedFracStr = fracStr.padRight(digits, '0');
      final frac = int.tryParse(paddedFracStr);
      if (frac == null) {
        throw const FormatException('Invalid number format.');
      }
      final multiplier = digits == 1 ? 10 : 100;
      final totalMinorUnits = whole * multiplier + frac;
      if (totalMinorUnits < 0) {
        throw const FormatException('Amount cannot be negative.');
      }
      if (totalMinorUnits > kMaxMinorUnitsCap) {
        throw const FormatException('Amount exceeds maximum allowed limit.');
      }
      return totalMinorUnits;
    } else {
      final whole = int.tryParse(trimmed);
      if (whole == null) {
        throw const FormatException('Invalid number format.');
      }
      if (whole < 0) {
        throw const FormatException('Amount cannot be negative.');
      }
      final multiplier = digits == 1 ? 10 : 100;
      final totalMinorUnits = whole * multiplier;
      if (totalMinorUnits > kMaxMinorUnitsCap) {
        throw const FormatException('Amount exceeds maximum allowed limit.');
      }
      return totalMinorUnits;
    }
  }
}

/// Safely parses a user input string into an integer minor unit value for the given [currencyCode].
///
/// Returns a Record `(int? value, String? error)` where `value` is non-null only on success,
/// and `error` is non-null if parsing failed. Returns `(null, null)` if input is null or empty.
(int? value, String? error) tryParseMinorUnits(
  String? input,
  String currencyCode,
) {
  if (input == null) return (null, null);
  final trimmed = input.trim();
  if (trimmed.isEmpty) return (null, null);

  try {
    final val = parseMinorUnits(trimmed, currencyCode);
    return (val, null);
  } on FormatException catch (e) {
    return (null, e.message);
  } catch (e) {
    return (null, 'Invalid number format.');
  }
}

/// Formats an integer minor unit value into a localized currency string using [intl].
///
/// Respects minor unit digits (e.g. 12550 INR -> "₹125.50", 500 JPY -> "¥500").
String formatMinorUnits(int amountInMinorUnits, String currencyCode) {
  final digits = getMinorUnitDigits(currencyCode);
  final currencyObj = kCurrencyDetails[currencyCode.toUpperCase().trim()];
  final symbol = currencyObj?.symbol ?? currencyCode;

  if (digits == 0) {
    final formatter = NumberFormat.currency(
      symbol: '$symbol ',
      decimalDigits: 0,
    );
    return formatter.format(amountInMinorUnits).trim();
  } else {
    final majorAmount = amountInMinorUnits / 100.0;
    final formatter = NumberFormat.currency(
      symbol: '$symbol ',
      decimalDigits: 2,
    );
    return formatter.format(majorAmount).trim();
  }
}

/// Formats an integer minor unit value into a signed localized currency string.
///
/// Positive values add a '+' prefix (e.g. "+₹450.00" or "+¥450").
/// Zero returns formatted zero without sign (e.g. "₹0.00" or "¥0").
/// Negative values keep standard formatting (e.g. "-₹450.00" or "-¥450").
String formatSignedMinorUnits(int amountInMinorUnits, String currencyCode) {
  if (amountInMinorUnits > 0) {
    return '+${formatMinorUnits(amountInMinorUnits, currencyCode)}';
  } else if (amountInMinorUnits < 0) {
    return '-${formatMinorUnits(amountInMinorUnits.abs(), currencyCode)}';
  } else {
    return formatMinorUnits(0, currencyCode);
  }
}
