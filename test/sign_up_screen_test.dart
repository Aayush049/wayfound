import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_mocks/google_sign_in_mocks.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wayfound/features/auth/data/auth_repository.dart';
import 'package:wayfound/features/auth/presentation/sign_up_screen.dart';

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

  group('SignUpScreen', () {
    testWidgets(
      'renders display name, email, password, confirm password fields',
      (tester) async {
        await tester.pumpApp(
          const SignUpScreen(),
          authRepository: repository,
          sharedPreferences: prefs,
        );
        await tester.pumpAndSettle();

        expect(find.text('Create Account'), findsWidgets);
        expect(find.byType(TextFormField), findsNWidgets(4));
      },
    );

    testWidgets('shows validation error when passwords do not match', (
      tester,
    ) async {
      await tester.pumpApp(
        const SignUpScreen(),
        authRepository: repository,
        sharedPreferences: prefs,
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Aayush');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'aayush@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(2), 'password123');
      await tester.enterText(
        find.byType(TextFormField).at(3),
        'differentpassword',
      );

      final submitBtn = find.widgetWithText(ElevatedButton, 'Create Account');
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets('renders correctly in Dark Mode', (tester) async {
      await tester.pumpApp(
        const SignUpScreen(),
        authRepository: repository,
        sharedPreferences: prefs,
        themeMode: ThemeMode.dark,
      );
      await tester.pumpAndSettle();

      expect(find.text('Create Account'), findsWidgets);
      expect(find.byType(TextFormField), findsNWidgets(4));
    });
  });
}
