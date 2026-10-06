import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wayfound/app/theme/theme_provider.dart';
import 'package:wayfound/features/auth/data/auth_repository.dart';
import 'package:wayfound/features/auth/presentation/settings_screen.dart';

import 'helpers/pump_app.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  late AuthRepository repository;
  late SharedPreferences prefs;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(
        uid: 'user-123',
        email: 'test@example.com',
        displayName: 'Test User',
        photoURL: '',
      ),
    );
    repository = AuthRepository(auth: auth, firestore: firestore);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('SettingsScreen', () {
    testWidgets('renders user profile details and appearance controls', (
      tester,
    ) async {
      await tester.pumpApp(
        const SettingsScreen(),
        authRepository: repository,
        sharedPreferences: prefs,
      );
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Test User'), findsOneWidget);
      expect(find.text('test@example.com'), findsOneWidget);
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.byType(SegmentedButton<ThemeMode>), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
    });

    testWidgets('shows edit display name dialog on tap', (tester) async {
      await tester.pumpApp(
        const SettingsScreen(),
        authRepository: repository,
        sharedPreferences: prefs,
      );
      await tester.pumpAndSettle();

      final editIcon = find.byIcon(Icons.edit_outlined);
      expect(editIcon, findsOneWidget);

      await tester.tap(editIcon);
      await tester.pumpAndSettle();

      expect(find.text('Edit Display Name'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('shows sign out confirmation dialog on tap', (tester) async {
      await tester.pumpApp(
        const SettingsScreen(),
        authRepository: repository,
        sharedPreferences: prefs,
      );
      await tester.pumpAndSettle();

      final signOutTile = find.text('Sign Out');
      await tester.tap(signOutTile);
      await tester.pumpAndSettle();

      expect(find.text('Are you sure you want to sign out?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('theme selector segment button updates theme state', (
      tester,
    ) async {
      await tester.pumpApp(
        const SettingsScreen(),
        authRepository: repository,
        sharedPreferences: prefs,
      );
      await tester.pumpAndSettle();

      // Find SegmentedButton
      final segmentedButton = find.byType(SegmentedButton<ThemeMode>);
      expect(segmentedButton, findsOneWidget);

      // Verify initial state
      expect(
        tester.widget<SegmentedButton<ThemeMode>>(segmentedButton).selected,
        {ThemeMode.system},
      );

      // Tap Light
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();

      // Verify state changed in shared prefs
      expect(prefs.getString(kThemeModeKey), equals('light'));
    });
  });
}
