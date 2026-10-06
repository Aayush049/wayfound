import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_mocks/google_sign_in_mocks.dart';
import 'package:wayfound/app/theme/app_theme.dart';
import 'package:wayfound/features/auth/data/auth_provider.dart';
import 'package:wayfound/features/auth/data/auth_repository.dart';
import 'package:wayfound/features/auth/presentation/sign_in_screen.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  late MockGoogleSignIn googleSignIn;
  late AuthRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth();
    googleSignIn = MockGoogleSignIn();
    repository = AuthRepository(
      auth: auth,
      googleSignIn: googleSignIn,
      firestore: firestore,
    );
  });

  Widget buildSignInScreen({ThemeMode themeMode = ThemeMode.light}) {
    return ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        home: const SignInScreen(),
      ),
    );
  }

  group('SignInScreen', () {
    testWidgets('renders fields and buttons in Light mode', (tester) async {
      await tester.pumpWidget(buildSignInScreen());

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('Sign In'), findsWidgets);
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('renders correctly in Dark mode', (tester) async {
      await tester.pumpWidget(buildSignInScreen(themeMode: ThemeMode.dark));

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('shows validation errors when fields are empty', (
      tester,
    ) async {
      await tester.pumpWidget(buildSignInScreen());

      final signInButtons = find.widgetWithText(ElevatedButton, 'Sign In');
      await tester.tap(signInButtons);
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
    });

    testWidgets('shows validation error for invalid email and short password', (
      tester,
    ) async {
      await tester.pumpWidget(buildSignInScreen());

      await tester.enterText(find.byType(TextFormField).at(0), 'invalidemail');
      await tester.enterText(find.byType(TextFormField).at(1), '123');

      final signInButtons = find.widgetWithText(ElevatedButton, 'Sign In');
      await tester.tap(signInButtons);
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email address'), findsOneWidget);
      expect(
        find.text('Password must be at least 8 characters'),
        findsOneWidget,
      );
    });
  });
}
