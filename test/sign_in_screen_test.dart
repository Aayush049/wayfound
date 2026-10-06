import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_mocks/google_sign_in_mocks.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wayfound/features/auth/data/auth_repository.dart';
import 'package:wayfound/features/auth/presentation/sign_in_screen.dart';

import 'helpers/pump_app.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  late MockGoogleSignIn googleSignIn;
  late AuthRepository repository;
  late SharedPreferences prefs;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth();
    googleSignIn = MockGoogleSignIn();
    repository = AuthRepository(
      auth: auth,
      googleSignIn: googleSignIn,
      firestore: firestore,
    );
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('SignInScreen', () {
    testWidgets('renders fields and buttons in Light mode', (tester) async {
      await tester.pumpApp(
        const SignInScreen(),
        authRepository: repository,
        sharedPreferences: prefs,
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('Sign In'), findsWidgets);
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('renders correctly in Dark mode', (tester) async {
      await tester.pumpApp(
        const SignInScreen(),
        authRepository: repository,
        sharedPreferences: prefs,
        themeMode: ThemeMode.dark,
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('shows validation errors when fields are empty', (
      tester,
    ) async {
      await tester.pumpApp(
        const SignInScreen(),
        authRepository: repository,
        sharedPreferences: prefs,
      );
      await tester.pumpAndSettle();

      final signInButtons = find.widgetWithText(ElevatedButton, 'Sign In');
      await tester.tap(signInButtons);
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
    });

    testWidgets('shows validation error for invalid email and short password', (
      tester,
    ) async {
      await tester.pumpApp(
        const SignInScreen(),
        authRepository: repository,
        sharedPreferences: prefs,
      );
      await tester.pumpAndSettle();

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
