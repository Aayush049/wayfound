import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfound/app/theme/app_theme.dart';
import 'package:wayfound/features/auth/presentation/welcome_screen.dart';

void main() {
  Widget buildWelcomeScreen({ThemeMode themeMode = ThemeMode.light}) {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        home: const WelcomeScreen(),
      ),
    );
  }

  group('WelcomeScreen', () {
    testWidgets(
      'renders brand title, subtitle, and action buttons in Light Mode',
      (tester) async {
        await tester.pumpWidget(buildWelcomeScreen(themeMode: ThemeMode.light));

        expect(find.text('Wayfound'), findsOneWidget);
        expect(
          find.text('Collaborative trip planner for groups'),
          findsOneWidget,
        );
        expect(find.text('Sign In'), findsOneWidget);
        expect(find.text('Create Account'), findsOneWidget);
        expect(find.text('Learn more'), findsOneWidget);
      },
    );

    testWidgets('renders correctly in Dark Mode', (tester) async {
      await tester.pumpWidget(buildWelcomeScreen(themeMode: ThemeMode.dark));

      expect(find.text('Wayfound'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
    });
  });
}
