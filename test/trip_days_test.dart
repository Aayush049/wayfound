import 'package:flutter_test/flutter_test.dart';
import 'package:wayfound/features/itinerary/domain/trip_days.dart';

void main() {
  group('tripDays', () {
    test('same-day trip returns 1', () {
      expect(
        tripDays(DateTime(2024, 10, 10), DateTime(2024, 10, 10)),
        equals(1),
      );
      expect(
        tripDays(DateTime.utc(2024, 10, 10), DateTime.utc(2024, 10, 10)),
        equals(1),
      );
    });

    test('handles different times of day on same date', () {
      // 00:00 vs 23:59 same day should give 1
      expect(
        tripDays(DateTime(2024, 10, 10, 0, 0), DateTime(2024, 10, 10, 23, 59)),
        equals(1),
      );
      expect(
        tripDays(DateTime(2024, 10, 10, 23, 59), DateTime(2024, 10, 11, 0, 0)),
        equals(2),
      );
    });

    test('handles 23-hour day (fall-back weekend)', () {
      // Nov 2 2024 to Nov 3 2024 - 23 hours due to DST fall-back
      final start = DateTime.utc(2024, 11, 2, 12, 0);
      final end = DateTime.utc(2024, 11, 3, 12, 0);
      expect(tripDays(start, end), equals(2));
    });

    test('handles 25-hour day (spring-forward weekend)', () {
      // Mar 9 2024 to Mar 10 2024 - 25 hours due to DST spring-forward
      final start = DateTime.utc(2024, 3, 9, 12, 0);
      final end = DateTime.utc(2024, 3, 10, 12, 0);
      expect(tripDays(start, end), equals(2));
    });

    test('handles month boundary crossing', () {
      // Jan 28 to Feb 2 = 6 days
      expect(
        tripDays(DateTime.utc(2024, 1, 28), DateTime.utc(2024, 2, 2)),
        equals(6),
      );
    });

    test('handles year boundary crossing', () {
      // Dec 30 2023 to Jan 2 2024 = 4 days
      expect(
        tripDays(DateTime.utc(2023, 12, 30), DateTime.utc(2024, 1, 2)),
        equals(4),
      );
    });

    test('handles leap day', () {
      // Feb 28 2024 to Mar 1 2024 (2024 is leap year) = 3 days
      expect(
        tripDays(DateTime.utc(2024, 2, 28), DateTime.utc(2024, 3, 1)),
        equals(3),
      );
    });

    test('end before start returns 1 (edge case)', () {
      expect(
        tripDays(DateTime.utc(2024, 10, 12), DateTime.utc(2024, 10, 10)),
        equals(1),
      );
    });

    test('result depends only on calendar date, not time', () {
      final baseStartEarly = DateTime.utc(2024, 10, 10, 0, 0, 0);
      final baseStartLate = DateTime.utc(2024, 10, 10, 23, 59, 59);
      final baseEnd = DateTime.utc(2024, 10, 15, 12, 0, 0);

      expect(tripDays(baseStartEarly, baseEnd), equals(6));
      expect(tripDays(baseStartLate, baseEnd), equals(6));
    });

    test('crosses leap year February correctly', () {
      // Jan 31 2024 to Feb 1 2024 (leap year) = 2 days
      expect(
        tripDays(DateTime.utc(2024, 1, 31), DateTime.utc(2024, 2, 1)),
        equals(2),
      );
    });
  });

  group('dayDate', () {
    test('returns correct date for dayIndex 0', () {
      final start = DateTime.utc(2024, 10, 10, 12, 30);
      final result = dayDate(start, 0);
      expect(result.year, equals(2024));
      expect(result.month, equals(10));
      expect(result.day, equals(10));
    });

    test('returns correct date for dayIndex 1', () {
      final start = DateTime.utc(2024, 10, 10, 12, 30);
      final result = dayDate(start, 1);
      expect(result.year, equals(2024));
      expect(result.month, equals(10));
      expect(result.day, equals(11));
    });

    test('returns correct date for dayIndex beyond month', () {
      final start = DateTime.utc(2024, 10, 30, 12, 0);
      final result = dayDate(start, 3);
      expect(result.year, equals(2024));
      expect(result.month, equals(11));
      expect(result.day, equals(2));
    });

    test('returns correct date for dayIndex beyond year', () {
      final start = DateTime.utc(2024, 12, 31, 12, 0);
      final result = dayDate(start, 2);
      expect(result.year, equals(2025));
      expect(result.month, equals(1));
      expect(result.day, equals(2));
    });

    test('result is at UTC midnight', () {
      final start = DateTime.utc(2024, 10, 10, 15, 30, 0); // 3:30 PM UTC
      final result = dayDate(start, 0);
      expect(result.hour, equals(0));
      expect(result.minute, equals(0));
      expect(result.second, equals(0));
    });

    test('same time of day inputs give same day result', () {
      final startMorning = DateTime.utc(2024, 10, 10, 8, 0);
      final startEvening = DateTime.utc(2024, 10, 10, 20, 0);

      expect(dayDate(startMorning, 5), equals(dayDate(startEvening, 5)));
    });
  });

  group('formatDayHeader', () {
    test('formats day 1 correctly', () {
      final start = DateTime(2024, 10, 14); // Monday
      final result = formatDayHeader(start, 0);
      expect(result, equals('Day 1 · Mon 14 Oct'));
    });

    test('formats day 2 correctly', () {
      final start = DateTime(2024, 10, 14); // Monday
      final result = formatDayHeader(start, 1);
      expect(result, equals('Day 2 · Tue 15 Oct'));
    });

    test('handles month boundary', () {
      final start = DateTime.utc(2024, 10, 31); // Thursday
      final result = formatDayHeader(start, 1);
      expect(result, equals('Day 2 · Fri 1 Nov'));
    });

    test('handles year boundary', () {
      final start = DateTime.utc(2024, 12, 31); // Tuesday
      final result = formatDayHeader(start, 1);
      expect(result, equals('Day 2 · Wed 1 Jan'));
    });
  });
}
