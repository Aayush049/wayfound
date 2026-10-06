import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_mocks/google_sign_in_mocks.dart';
import 'package:wayfound/app/theme/app_theme.dart';
import 'package:wayfound/features/auth/data/auth_provider.dart';
import 'package:wayfound/features/auth/data/auth_repository.dart';
import 'package:wayfound/features/auth/presentation/sign_up_screen.dart';

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

  Widget buildSignUpScreen({ThemeMode themeMode = ThemeMode.light}) {
    return ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        home: const SignUpScreen(),
      ),
    );
  }

  group('SignUpScreen', () {
    testWidgets(
      'renders display name, email, password, confirm password fields',
      (tester) async {
        await tester.pumpWidget(buildSignUpScreen());

        expect(find.text('Create Account'), findsWidgets);
        expect(find.byType(TextFormField), findsNWidgets(4));
      },
    );

    testWidgets('shows validation error when passwords do not match', (
      tester,
    ) async {
      await tester.pumpWidget(buildSignUpScreen());

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
      await tester.pumpWidget(buildSignUpScreen(themeMode: ThemeMode.dark));

      expect(find.text('Create Account'), findsWidgets);
      expect(find.byType(TextFormField), findsNWidgets(4));
    });
  });
}
