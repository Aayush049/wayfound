import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfound/app/router.dart';
import 'package:wayfound/features/auth/data/auth_provider.dart';
import 'package:wayfound/features/auth/data/auth_repository.dart';

void main() {
  group('App Router Redirects', () {
    testWidgets(
      'Signed out user navigating to protected route is redirected to Welcome',
      (tester) async {
        final firestore = FakeFirebaseFirestore();
        final auth = MockFirebaseAuth(signedIn: false);
        final repository = AuthRepository(auth: auth, firestore: firestore);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [authRepositoryProvider.overrideWithValue(repository)],
            child: Consumer(
              builder: (context, ref, _) {
                final router = ref.watch(routerProvider);
                return MaterialApp.router(routerConfig: router);
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Wayfound'), findsOneWidget);
        expect(find.text('Sign In'), findsOneWidget);
      },
    );

    testWidgets('Signed in user navigating to welcome is redirected to Home', (
      tester,
    ) async {
      final firestore = FakeFirebaseFirestore();
      final auth = MockFirebaseAuth(
        mockUser: MockUser(
          uid: 'user-123',
          email: 'test@example.com',
          displayName: 'Test User',
        ),
      );
      final repository = AuthRepository(auth: auth, firestore: firestore);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(repository)],
          child: Consumer(
            builder: (context, ref, _) {
              final router = ref.watch(routerProvider);
              return MaterialApp.router(routerConfig: router);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('My Trips'), findsOneWidget);
      expect(find.text('Your trips will appear here'), findsOneWidget);
    });
  });
}
