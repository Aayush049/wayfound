import 'package:flutter_test/flutter_test.dart';
import 'package:wayfound/features/trips/domain/join_code.dart';

void main() {
  group('JoinCode', () {
    group('generateJoinCode', () {
      test('generates a 6-character code matching alphabet', () {
        final code = generateJoinCode();
        expect(code.length, equals(6));
        expect(isValidJoinCode(code), isTrue);
      });

      test('does not include ambiguous characters (0, O, 1, I, L)', () {
        for (var i = 0; i < 100; i++) {
          final code = generateJoinCode();
          expect(code.contains('0'), isFalse);
          expect(code.contains('O'), isFalse);
          expect(code.contains('1'), isFalse);
          expect(code.contains('I'), isFalse);
          expect(code.contains('L'), isFalse);
        }
      });
    });

    group('normalizeJoinCode', () {
      test(
        'trims whitespace, converts to uppercase, removes spaces and hyphens',
        () {
          expect(normalizeJoinCode(' abc-234 '), equals('ABC234'));
          expect(normalizeJoinCode('a-b-c-d-e-f'), equals('ABCDEF'));
        },
      );
    });

    group('isValidJoinCode', () {
      test('returns true for valid 6-char uppercase allowed codes', () {
        expect(isValidJoinCode('ABC234'), isTrue);
        expect(isValidJoinCode('HJKMNP'), isTrue);
      });

      test(
        'returns false for codes of wrong length or containing invalid chars',
        () {
          expect(isValidJoinCode('ABC23'), isFalse); // length 5
          expect(isValidJoinCode('ABC2345'), isFalse); // length 7
          expect(isValidJoinCode('ABC230'), isFalse); // 0 invalid
          expect(isValidJoinCode('ABC23I'), isFalse); // I invalid
          expect(isValidJoinCode('abc234'), isFalse); // lowercase
        },
      );
    });
  });
}
