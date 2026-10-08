import 'dart:math';

/// 31-character unambiguous alphabet (excludes I, L, O, 0, 1).
const String kJoinCodeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

/// Regex for validating normalized 6-character join code format.
final RegExp kJoinCodeRegex = RegExp(r'^[A-HJKMNP-Z2-9]{6}$');

/// Generates a random 6-character join code from [kJoinCodeAlphabet].
/// Accepts an optional [random] instance for deterministic unit testing.
String generateJoinCode([Random? random]) {
  final rng = random ?? Random();
  final buffer = StringBuffer();
  for (var i = 0; i < 6; i++) {
    final index = rng.nextInt(kJoinCodeAlphabet.length);
    buffer.write(kJoinCodeAlphabet[index]);
  }
  return buffer.toString();
}

/// Normalizes raw join code input by trimming, uppercasing, and removing spaces and hyphens.
String normalizeJoinCode(String rawCode) {
  return rawCode.trim().toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
}

/// Returns true if [code] matches the 6-character join code format.
bool isValidJoinCode(String code) {
  return kJoinCodeRegex.hasMatch(code);
}
