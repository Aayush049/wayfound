import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wayfound/features/auth/presentation/welcome_screen.dart';

import 'helpers/pump_app.dart';

void main() {
  group('WelcomeScreen', () {
    testWidgets(
      'renders brand title, subtitle, and action buttons in Light Mode',
      (tester) async {
        await tester.pumpApp(const WelcomeScreen());

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
      await tester.pumpApp(const WelcomeScreen(), themeMode: ThemeMode.dark);

      expect(find.text('Wayfound'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
    });
  });
}
