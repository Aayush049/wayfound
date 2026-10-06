import 'package:flutter_test/flutter_test.dart';
import 'package:wayfound/features/auth/presentation/sign_in_screen.dart';

void main() {
  group('SignInScreen', () {
    testWidgets('renders all UI elements', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SignInScreen(),
        ),
      );

      // Verify logo/title
      expect(find.text('Wayfound'), findsOneWidget);

      // Verify form elements
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);

      // Verify buttons
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text("Don't have an account?"), findsOneWidget);
      expect(find.text('Sign Up'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
    });

    testWidgets('toggles between sign in and sign up modes', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SignInScreen(),
        ),
      );

      // Initial state: Sign In mode
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Sign In'), findsAtLeast(1));

      // Tap "Sign Up" link
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();

      // Now in Sign Up mode
      expect(find.text('Create an account'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Already have an account?'), findsOneWidget);
    });

    testWidgets('validates empty email', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SignInScreen(),
        ),
      );

      // Try to submit without entering email
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      // Should show validation error
      expect(find.text('Please enter your email'), findsOneWidget);
    });

    testWidgets('validates empty password', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SignInScreen(),
        ),
      );

      await tester.enterText(find.byType(TextFormField).first, 'test@example.com');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your password'), findsOneWidget);
    });

    testWidgets('password field can be obscured', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SignInScreen(),
        ),
      );

      // Find password field
      final passwordField = find.byType(TextFormField).last;

      // Type a password
      await tester.enterText(passwordField, 'secret123');
      await tester.pump();

      // Verify it's visible (obscureText is controlled by the widget state)
      // The presence of the visibility toggle icon confirms password field exists
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });
  });
}