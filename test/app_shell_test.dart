import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wayfound/app/theme/theme_provider.dart';
import 'package:wayfound/main.dart';

void main() {
  group('App Shell & Router Tests', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    Widget createTestApp({ThemeMode initialThemeMode = ThemeMode.system}) {
      return ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const WayfoundApp(),
      );
    }

    testWidgets('App shell builds and starts on Welcome Screen', (
      tester,
    ) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Wayfound'), findsOneWidget);
      expect(
        find.text('Collaborative trip planner for groups'),
        findsOneWidget,
      );
      expect(find.text('Go to Home (TEMP)'), findsOneWidget);
    });

    testWidgets('Router navigates from Welcome to Home', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Go to Home (TEMP)'));
      await tester.pumpAndSettle();

      expect(find.text('My Trips'), findsOneWidget);
      expect(find.text('Home Screen Placeholder'), findsOneWidget);
    });

    testWidgets('Home theme toggle button flips theme mode', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Navigate to Home
      await tester.tap(find.text('Go to Home (TEMP)'));
      await tester.pumpAndSettle();

      // Find toggle IconButton
      final toggleButton = find.byTooltip('Toggle Theme');
      expect(toggleButton, findsOneWidget);

      // Tap toggle button
      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      // Verify theme mode changed in shared preferences
      expect(prefs.getString(kThemeModeKey), isNotNull);
    });
  });
}
