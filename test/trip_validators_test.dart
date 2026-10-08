import 'package:flutter_test/flutter_test.dart';
import 'package:wayfound/features/trips/domain/currencies.dart';
import 'package:wayfound/features/trips/domain/trip_validators.dart';

void main() {
  group('TripValidators', () {
    group('validateTripName', () {
      test('returns error when null or empty', () {
        expect(validateTripName(null), isNotNull);
        expect(validateTripName(''), isNotNull);
        expect(validateTripName('   '), isNotNull);
      });

      test('returns error when longer than 60 characters', () {
        final longName = 'A' * 61;
        expect(validateTripName(longName), isNotNull);
      });

      test('returns null for valid trip names', () {
        expect(validateTripName('Goa Vacation'), isNull);
        expect(validateTripName('A' * 60), isNull);
      });
    });

    group('validateDestination', () {
      test('returns error when null or empty', () {
        expect(validateDestination(null), isNotNull);
        expect(validateDestination(''), isNotNull);
        expect(validateDestination('   '), isNotNull);
      });

      test('returns error when longer than 80 characters', () {
        final longDest = 'A' * 81;
        expect(validateDestination(longDest), isNotNull);
      });

      test('returns null for valid destinations', () {
        expect(validateDestination('Goa, India'), isNull);
        expect(validateDestination('A' * 80), isNull);
      });
    });

    group('validateDateRange', () {
      test('returns error when start or end is null', () {
        expect(validateDateRange(null, DateTime.now()), isNotNull);
        expect(validateDateRange(DateTime.now(), null), isNotNull);
      });

      test('returns error when end date is before start date', () {
        final start = DateTime(2026, 6, 10);
        final end = DateTime(2026, 6, 5);
        expect(validateDateRange(start, end), isNotNull);
      });

      test('returns null for valid date range', () {
        final start = DateTime(2026, 6, 1);
        final end = DateTime(2026, 6, 10);
        expect(validateDateRange(start, end), isNull);
        expect(validateDateRange(start, start), isNull);
      });
    });

    group('validateCurrencySelection', () {
      test('returns error when null, empty, or unsupported', () {
        expect(validateCurrencySelection(null), isNotNull);
        expect(validateCurrencySelection(''), isNotNull);
        expect(validateCurrencySelection('XYZ'), isNotNull);
      });

      test('returns null for supported currencies', () {
        for (final currency in kSupportedCurrencies) {
          expect(validateCurrencySelection(currency), isNull);
        }
      });
    });
  });
}
