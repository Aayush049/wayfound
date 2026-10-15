import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfound/app/theme/app_theme.dart';
import 'package:wayfound/features/auth/data/auth_provider.dart';
import 'package:wayfound/features/expenses/data/expenses_providers.dart';
import 'package:wayfound/features/expenses/domain/balance_calculator.dart';
import 'package:wayfound/features/expenses/presentation/balances_view.dart';
import 'package:wayfound/features/settlements/data/settlements_providers.dart';
import 'package:wayfound/features/settlements/domain/settlement.dart';
import 'package:wayfound/features/trips/data/trips_providers.dart';
import 'package:wayfound/features/trips/domain/member.dart';
import 'package:wayfound/features/trips/domain/trip.dart';
import 'package:wayfound/features/trips/presentation/members_tab.dart';

void main() {
  final now = DateTime(2026, 11, 1);
  const tripId = 'trip_overflow';
  final trip = Trip(
    id: tripId,
    name: 'Euro Trip with Long Name to Test Layout Overflows',
    destination: 'Switzerland and France',
    startDate: now,
    endDate: now.add(const Duration(days: 7)),
    currency: 'USD',
    organizerId: 'org_user',
    joinCode: 'SWISS1',
    memberIds: const ['org_user', 'mem_alice', 'mem_bob'],
    memberCount: 3,
    archived: false,
    createdAt: now,
  );

  final orgMember = Member(
    uid: 'org_user',
    displayName: 'Organizer Dan with Long Name',
    role: 'organizer',
    status: 'active',
    joinedAt: now,
  );

  final aliceMember = Member(
    uid: 'mem_alice',
    displayName: 'Alice Member with Long Name',
    role: 'member',
    status: 'active',
    joinedAt: now,
  );

  final bobMember = Member(
    uid: 'mem_bob',
    displayName: 'Bob Member with Long Name',
    role: 'member',
    status: 'active',
    joinedAt: now,
  );

  final sConfirmed = Settlement(
    id: 's_conf',
    fromUid: 'mem_alice',
    toUid: 'org_user',
    amount: 1550,
    status: SettlementStatus.confirmed,
    createdAt: now,
    resolvedAt: now,
  );

  final sRejected = Settlement(
    id: 's_rej',
    fromUid: 'mem_bob',
    toUid: 'org_user',
    amount: 2500,
    status: SettlementStatus.rejected,
    createdAt: now,
    resolvedAt: now,
  );

  final sPending = Settlement(
    id: 's_pen',
    fromUid: 'mem_alice',
    toUid: 'org_user',
    amount: 875,
    status: SettlementStatus.pending,
    createdAt: now,
  );

  final mockOrg = MockUser(
    uid: 'org_user',
    email: 'org@test.com',
    displayName: 'Organizer Dan with Long Name',
    photoURL: '',
  );

  final mockAlice = MockUser(
    uid: 'mem_alice',
    email: 'alice@test.com',
    displayName: 'Alice Member with Long Name',
    photoURL: '',
  );

  final screenSizes = [
    (320.0, 568.0), // iPhone SE 1st gen
    (360.0, 640.0), // Budget Android
  ];

  final themeModes = [ThemeMode.light, ThemeMode.dark];

  group('Settlements Overflow Tests (O1)', () {
    testWidgets(
      'O1.1 BalancesView all sections populated without overflow at small screens and 1.3 text scale',
      (tester) async {
        for (final (width, height) in screenSizes) {
          for (final themeMode in themeModes) {
            tester.view.physicalSize = Size(width * 2, height * 2);
            tester.view.devicePixelRatio = 2.0;
            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            });

            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  authUserProvider.overrideWithValue(AsyncData(mockOrg)),
                  tripAllMembersProvider(trip.id).overrideWithValue(
                    AsyncData([orgMember, aliceMember, bobMember]),
                  ),
                  tripMembersProvider(trip.id).overrideWithValue(
                    AsyncData([orgMember, aliceMember, bobMember]),
                  ),
                  tripBalancesProvider(trip.id).overrideWithValue({
                    'org_user': 2425,
                    'mem_alice': -1550,
                    'mem_bob': -875,
                  }),
                  totalTripSpentProvider(trip.id).overrideWithValue(15000),
                  settlementsStreamProvider(trip.id).overrideWithValue(
                    AsyncData([sConfirmed, sRejected, sPending]),
                  ),
                ],
                child: MaterialApp(
                  theme: AppTheme.lightTheme,
                  darkTheme: AppTheme.darkTheme,
                  themeMode: themeMode,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: const TextScaler.linear(1.3)),
                    child: child!,
                  ),
                  home: Scaffold(body: BalancesView(trip: trip)),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(find.text('Payments History'), findsOneWidget);
            expect(find.text('Suggested Payments'), findsOneWidget);

            await tester.pumpWidget(const SizedBox());
          }
        }
      },
    );

    testWidgets(
      'O1.2 MembersTab without overflow at small screens and 1.3 text scale',
      (tester) async {
        for (final (width, height) in screenSizes) {
          for (final themeMode in themeModes) {
            tester.view.physicalSize = Size(width * 2, height * 2);
            tester.view.devicePixelRatio = 2.0;
            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            });

            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  authUserProvider.overrideWithValue(AsyncData(mockAlice)),
                  tripMembersProvider(trip.id).overrideWithValue(
                    AsyncData([orgMember, aliceMember, bobMember]),
                  ),
                  tripBalancesProvider(trip.id).overrideWithValue({
                    'org_user': 0,
                    'mem_alice': 0,
                    'mem_bob': 0,
                  }),
                  settlementsStreamProvider(trip.id)
                      .overrideWithValue(const AsyncData([])),
                ],
                child: MaterialApp(
                  theme: AppTheme.lightTheme,
                  darkTheme: AppTheme.darkTheme,
                  themeMode: themeMode,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: const TextScaler.linear(1.3)),
                    child: child!,
                  ),
                  home: Scaffold(body: MembersTab(trip: trip)),
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
            expect(find.text('Leave Trip'), findsOneWidget);

            await tester.pumpWidget(const SizedBox());
          }
        }
      },
    );

    testWidgets(
      'O1.3 MarkAsPaidSheet without overflow at small screens and 1.3 text scale',
      (tester) async {
        for (final (width, height) in screenSizes) {
          for (final themeMode in themeModes) {
            tester.view.physicalSize = Size(width * 2, height * 2);
            tester.view.devicePixelRatio = 2.0;
            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            });

            await tester.pumpWidget(
              ProviderScope(
                child: MaterialApp(
                  theme: AppTheme.lightTheme,
                  darkTheme: AppTheme.darkTheme,
                  themeMode: themeMode,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: const TextScaler.linear(1.3)),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: SingleChildScrollView(
                      child: MarkAsPaidSheet(
                        trip: trip,
                        payment: const SuggestedPayment(
                          fromUid: 'mem_alice',
                          toUid: 'org_user',
                          amount: 3500,
                        ),
                        receiverName: 'Organizer Dan with Long Name',
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
            expect(find.text('Mark Payment as Paid'), findsOneWidget);

            await tester.pumpWidget(const SizedBox());
          }
        }
      },
    );

    testWidgets(
      'O1.4 Leave Dialog and Remove Dialog without overflow at small screens and 1.3 text scale',
      (tester) async {
        for (final (width, height) in screenSizes) {
          for (final themeMode in themeModes) {
            tester.view.physicalSize = Size(width * 2, height * 2);
            tester.view.devicePixelRatio = 2.0;
            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            });

            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  authUserProvider.overrideWithValue(AsyncData(mockAlice)),
                  tripMembersProvider(trip.id)
                      .overrideWithValue(AsyncData([orgMember, aliceMember])),
                  tripBalancesProvider(trip.id)
                      .overrideWithValue({'org_user': 0, 'mem_alice': 0}),
                  settlementsStreamProvider(trip.id)
                      .overrideWithValue(const AsyncData([])),
                ],
                child: MaterialApp(
                  theme: AppTheme.lightTheme,
                  darkTheme: AppTheme.darkTheme,
                  themeMode: themeMode,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: const TextScaler.linear(1.3)),
                    child: child!,
                  ),
                  home: Scaffold(body: MembersTab(trip: trip)),
                ),
              ),
            );
            await tester.pumpAndSettle();

            // Open Leave Dialog
            await tester.tap(find.text('Leave Trip'));
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
            expect(
              find.textContaining('Are you sure you want to leave this trip?'),
              findsOneWidget,
            );

            // Dismiss Leave Dialog
            await tester.tap(find.text('Cancel'));
            await tester.pumpAndSettle();

            await tester.pumpWidget(const SizedBox());

            // Now test Remove Dialog as organizer
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  authUserProvider.overrideWithValue(AsyncData(mockOrg)),
                  tripMembersProvider(trip.id)
                      .overrideWithValue(AsyncData([orgMember, aliceMember])),
                  tripBalancesProvider(trip.id)
                      .overrideWithValue({'org_user': 0, 'mem_alice': 0}),
                  settlementsStreamProvider(trip.id)
                      .overrideWithValue(const AsyncData([])),
                ],
                child: MaterialApp(
                  theme: AppTheme.lightTheme,
                  darkTheme: AppTheme.darkTheme,
                  themeMode: themeMode,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: const TextScaler.linear(1.3)),
                    child: child!,
                  ),
                  home: Scaffold(body: MembersTab(trip: trip)),
                ),
              ),
            );
            await tester.pumpAndSettle();

            // Open Remove Dialog
            await tester.tap(find.text('Remove'));
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
            expect(find.text('Remove Member'), findsOneWidget);

            // Dismiss Remove Dialog
            await tester.tap(find.text('Cancel'));
            await tester.pumpAndSettle();

            await tester.pumpWidget(const SizedBox());
          }
        }
      },
    );
  });
}
