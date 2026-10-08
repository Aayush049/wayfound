import 'package:flutter_test/flutter_test.dart';
import 'package:wayfound/core/money.dart';
import 'package:wayfound/features/trips/domain/currencies.dart';

void main() {
  group('Money Utilities Tests', () {
    test('getMinorUnitDigits returns 0 for JPY and 2 for other currencies', () {
      expect(getMinorUnitDigits('JPY'), equals(0));
      expect(getMinorUnitDigits('INR'), equals(2));
      expect(getMinorUnitDigits('USD'), equals(2));
      expect(getMinorUnitDigits('EUR'), equals(2));
      expect(getMinorUnitDigits('GBP'), equals(2));
    });

    test(
      'parseMinorUnits parses valid inputs correctly for 2-decimal currencies',
      () {
        expect(parseMinorUnits('125.50', 'INR'), equals(12550));
        expect(parseMinorUnits('100', 'USD'), equals(10000));
        expect(parseMinorUnits('0.05', 'EUR'), equals(5));
        expect(parseMinorUnits('0', 'GBP'), equals(0));
        expect(parseMinorUnits('  10.5  ', 'USD'), equals(1050));
        expect(parseMinorUnits(null, 'USD'), isNull);
        expect(parseMinorUnits('', 'USD'), isNull);
        expect(parseMinorUnits('   ', 'USD'), isNull);
      },
    );

    test('parseMinorUnits parses valid inputs correctly for 0-decimal currency (JPY)', () {
      expect(parseMinorUnits('500', 'JPY'), equals(500));
      expect(parseMinorUnits('1000', 'JPY'), equals(1000));
      expect(parseMinorUnits('0', 'JPY'), equals(0));
      expect(parseMinorUnits('500.0', 'JPY'), equals(500));
    });

    test('parseMinorUnits throws FormatException on invalid, negative, decimal JPY, or too many decimal inputs', () {
      // Negative
      expect(() => parseMinorUnits('-10', 'INR'), throwsFormatException);
      expect(() => parseMinorUnits('-500', 'JPY'), throwsFormatException);

      // Too many decimals
      expect(() => parseMinorUnits('10.123', 'USD'), throwsFormatException);
      expect(() => parseMinorUnits('500.5', 'JPY'), throwsFormatException);

      // Non-numeric
      expect(() => parseMinorUnits('abc', 'INR'), throwsFormatException);
      expect(() => parseMinorUnits('10.2.3', 'USD'), throwsFormatException);

      // Over cap (100 billion minor units)
      expect(
        () => parseMinorUnits('100000000001', 'INR'),
        throwsFormatException,
      );
    });

    test('formatMinorUnits formats currency values correctly using intl', () {
      final formattedInr = formatMinorUnits(12550, 'INR');
      expect(formattedInr, contains('125.50'));
      expect(formattedInr, contains('₹'));

      final formattedUsd = formatMinorUnits(1000, 'USD');
      expect(formattedUsd, contains('10.00'));

      final formattedJpy = formatMinorUnits(500, 'JPY');
      expect(formattedJpy, contains('500'));
      expect(formattedJpy, contains('¥'));
    });
  });
}
