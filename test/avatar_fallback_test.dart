import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wayfound/features/auth/presentation/settings_screen.dart';
import 'package:wayfound/features/trips/presentation/home_screen.dart';

import 'helpers/pump_app.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('Empty photoURL fallback', () {
    testWidgets('SettingsScreen uses initials when photoURL is empty', (
      tester,
    ) async {
      final user = MockUser(
        uid: 'user-123',
        email: 'test@example.com',
        displayName: 'Test User',
        photoURL: '',
      );

      await tester.pumpApp(
        const SettingsScreen(),
        sharedPreferences: prefs,
        authUserValue: AsyncData(user),
      );
      await tester.pumpAndSettle();

      // Initial 'T' from 'Test User' should be rendered in a CircleAvatar
      expect(find.text('T'), findsOneWidget);
    });

    testWidgets('HomeScreen uses initials when photoURL is empty', (
      tester,
    ) async {
      final user = MockUser(
        uid: 'user-123',
        email: 'test@example.com',
        displayName: 'Test User',
        photoURL: '',
      );

      await tester.pumpApp(
        const HomeScreen(),
        sharedPreferences: prefs,
        authUserValue: AsyncData(user),
      );
      await tester.pumpAndSettle();

      // Initial 'T' from 'Test User' should be rendered in CircleAvatar
      expect(find.text('T'), findsOneWidget);
    });
  });
}
