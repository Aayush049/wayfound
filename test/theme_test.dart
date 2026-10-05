import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wayfound/app/theme/app_colors.dart';
import 'package:wayfound/app/theme/app_theme.dart';
import 'package:wayfound/app/theme/theme_provider.dart';

void main() {
  group('Theme System Tests', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('Default theme mode is System', () {
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final mode = container.read(themeProvider);
      expect(mode, equals(ThemeMode.system));
    });

    test('ThemeMode persists and reloads from shared_preferences', () async {
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      // Set to light
      await container
          .read(themeProvider.notifier)
          .setThemeMode(ThemeMode.light);
      expect(container.read(themeProvider), equals(ThemeMode.light));
      expect(prefs.getString(kThemeModeKey), equals('light'));

      // New container with same prefs instance reloads light
      final container2 = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container2.dispose);
      expect(container2.read(themeProvider), equals(ThemeMode.light));

      // Set to dark
      await container.read(themeProvider.notifier).setThemeMode(ThemeMode.dark);
      expect(container.read(themeProvider), equals(ThemeMode.dark));
      expect(prefs.getString(kThemeModeKey), equals('dark'));
    });

    test(
      'Quick toggle flips relative to current displayed brightness',
      () async {
        final container = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        addTearDown(container.dispose);

        // If currently showing light, toggle should flip to dark
        await container
            .read(themeProvider.notifier)
            .toggleTheme(Brightness.light);
        expect(container.read(themeProvider), equals(ThemeMode.dark));

        // If currently showing dark, toggle should flip to light
        await container
            .read(themeProvider.notifier)
            .toggleTheme(Brightness.dark);
        expect(container.read(themeProvider), equals(ThemeMode.light));
      },
    );

    test('Spot-check AppTheme ColorSchemes for palette values', () {
      final light = AppTheme.lightTheme;
      final dark = AppTheme.darkTheme;

      // Light spot check
      expect(light.colorScheme.primary, equals(AppColors.primaryLight));
      expect(light.scaffoldBackgroundColor, equals(AppColors.backgroundLight));
      expect(light.colorScheme.surface, equals(AppColors.surfaceLight));
      expect(light.colorScheme.error, equals(AppColors.errorLight));

      // Dark spot check
      expect(dark.colorScheme.primary, equals(AppColors.primaryDark));
      expect(dark.scaffoldBackgroundColor, equals(AppColors.backgroundDark));
      expect(dark.colorScheme.surface, equals(AppColors.surfaceDark));
      expect(dark.colorScheme.error, equals(AppColors.errorDark));
    });
  });
}
