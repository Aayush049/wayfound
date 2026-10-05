import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kThemeModeKey = 'theme_mode';

/// Provider for SharedPreferences instance.
/// Override in [ProviderScope] at startup.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in ProviderScope',
  );
});

/// Notifier to manage and persist [ThemeMode].
class ThemeNotifier extends Notifier<ThemeMode> {
  late final SharedPreferences _prefs;

  @override
  ThemeMode build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    final savedMode = _prefs.getString(kThemeModeKey);
    return _parseThemeMode(savedMode);
  }

  /// Update and persist [ThemeMode].
  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await _prefs.setString(kThemeModeKey, mode.name);
  }

  /// Quick toggle: Flips to the opposite of the brightness currently displayed.
  ///
  /// [currentBrightness] should be the active [Brightness] of the screen context.
  Future<void> toggleTheme(Brightness currentBrightness) async {
    if (currentBrightness == Brightness.dark) {
      await setThemeMode(ThemeMode.light);
    } else {
      await setThemeMode(ThemeMode.dark);
    }
  }

  static ThemeMode _parseThemeMode(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(
  ThemeNotifier.new,
);
