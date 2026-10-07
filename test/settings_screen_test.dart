import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wayfound/app/theme/app_theme.dart';
import 'package:wayfound/app/theme/theme_provider.dart';
import 'package:wayfound/features/auth/data/auth_provider.dart';
import 'package:wayfound/features/auth/data/auth_repository.dart';
import 'package:wayfound/features/auth/presentation/settings_screen.dart';
import 'package:wayfound/features/trips/presentation/home_screen.dart';

import 'helpers/pump_app.dart';

class FailingAuthRepository extends AuthRepository {
  FailingAuthRepository({required super.auth, required super.firestore});

  @override
  Future<void> updateDisplayName(String displayName) async {
    throw Exception('Failed to update display name');
  }
}

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

    testWidgets(
      'editing display name updates SettingsScreen and HomeScreen immediately without restart',
      (tester) async {
        await firestore.collection('users').doc('user-123').set({
          'displayName': 'Test User',
          'email': 'test@example.com',
        });

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            authRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const SettingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Test User'), findsOneWidget);

        // Tap edit icon
        await tester.tap(find.byIcon(Icons.edit_outlined));
        await tester.pumpAndSettle();

        // Type new name
        final textField = find.byType(TextField);
        await tester.enterText(textField, 'Updated Name');
        await tester.pumpAndSettle();

        // Tap Save
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        // Verify SettingsScreen immediately shows updated name
        expect(find.text('Updated Name'), findsOneWidget);
        expect(find.text('Display name updated successfully'), findsOneWidget);

        // Pump HomeScreen under same container to verify Home screen shows updated name immediately
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const HomeScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Welcome, Updated Name!'), findsOneWidget);
      },
    );

    testWidgets(
      'failed display name edit shows error snackbar and retains old name',
      (tester) async {
        final failingRepository = FailingAuthRepository(
          auth: auth,
          firestore: firestore,
        );

        await firestore.collection('users').doc('user-123').set({
          'displayName': 'Test User',
          'email': 'test@example.com',
        });

        await tester.pumpApp(
          const SettingsScreen(),
          authRepository: failingRepository,
          sharedPreferences: prefs,
        );
        await tester.pumpAndSettle();

        expect(find.text('Test User'), findsOneWidget);

        // Tap edit icon
        await tester.tap(find.byIcon(Icons.edit_outlined));
        await tester.pumpAndSettle();

        // Enter new name
        await tester.enterText(find.byType(TextField), 'Failed Name');
        await tester.pumpAndSettle();

        // Tap Save
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        // Verify error SnackBar is shown
        expect(
          find.textContaining('Failed to update display name'),
          findsOneWidget,
        );

        // Cancel the dialog
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // Verify old name is retained on SettingsScreen
        expect(find.text('Test User'), findsOneWidget);
        expect(find.text('Failed Name'), findsNothing);
      },
    );
  });
}
