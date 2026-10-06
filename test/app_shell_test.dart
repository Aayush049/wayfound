import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wayfound/app/theme/theme_provider.dart';
import 'package:wayfound/features/auth/data/auth_provider.dart';
import 'package:wayfound/features/auth/data/auth_repository.dart';
import 'package:wayfound/main.dart';

void main() {
  group('App Shell & Router Tests', () {
    late SharedPreferences prefs;
    late FakeFirebaseFirestore firestore;
    late MockFirebaseAuth auth;
    late AuthRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      firestore = FakeFirebaseFirestore();
      auth = MockFirebaseAuth();
      repository = AuthRepository(auth: auth, firestore: firestore);
    });

    Widget createTestApp({AsyncValue<User?>? authUserValue}) {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(repository),
          if (authUserValue != null)
            authUserProvider.overrideWithValue(authUserValue),
        ],
        child: const WayfoundApp(),
      );
    }

    testWidgets('App shell builds and starts on Welcome Screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(authUserValue: const AsyncData(null)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Wayfound'), findsOneWidget);
      expect(
        find.text('Collaborative trip planner for groups'),
        findsOneWidget,
      );
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
    });

    testWidgets('Router navigates from Welcome to Sign In', (tester) async {
      await tester.pumpWidget(
        createTestApp(authUserValue: const AsyncData(null)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget);
    });

    testWidgets('Home theme toggle button flips theme mode', (tester) async {
      final user = MockUser(
        uid: 'user-123',
        email: 'test@example.com',
        photoURL: '',
      );
      auth = MockFirebaseAuth(signedIn: true, mockUser: user);
      repository = AuthRepository(auth: auth, firestore: firestore);

      await tester.pumpWidget(createTestApp(authUserValue: AsyncData(user)));
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
