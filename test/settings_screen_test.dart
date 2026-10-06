import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfound/app/theme/app_theme.dart';
import 'package:wayfound/app/theme/theme_provider.dart';
import 'package:wayfound/features/auth/data/auth_provider.dart';
import 'package:wayfound/features/auth/data/auth_repository.dart';
import 'package:wayfound/features/auth/presentation/settings_screen.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  late AuthRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth(
      mockUser: MockUser(
        uid: 'user-123',
        email: 'test@example.com',
        displayName: 'Test User',
      ),
    );
    repository = AuthRepository(auth: auth, firestore: firestore);
  });

  Widget buildSettingsScreen() {
    return ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: const SettingsScreen(),
      ),
    );
  }

  group('SettingsScreen', () {
    testWidgets('renders user profile details and appearance controls', (
      tester,
    ) async {
      await tester.pumpWidget(buildSettingsScreen());
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Test User'), findsOneWidget);
      expect(find.text('test@example.com'), findsOneWidget);
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.byType(SegmentedButton<ThemeMode>), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
    });

    testWidgets('shows edit display name dialog on tap', (tester) async {
      await tester.pumpWidget(buildSettingsScreen());
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
      await tester.pumpWidget(buildSettingsScreen());
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
      late WidgetRef savedRef;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                savedRef = ref;
                return const SettingsScreen();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 'Dark' segment
      final darkSegment = find.text('Dark');
      await tester.tap(darkSegment);
      await tester.pumpAndSettle();

      expect(savedRef.read(themeProvider), equals(ThemeMode.dark));
    });
  });
}
