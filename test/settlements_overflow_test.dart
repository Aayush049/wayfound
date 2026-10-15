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

  final bobLeftMember = Member(
    uid: 'mem_bob',
    displayName: 'Bob Member with Long Name',
    role: 'member',
    status: 'left',
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

  void setupViewport(WidgetTester tester, double width, double height) {
    tester.view.physicalSize = Size(width * 2, height * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Widget wrapWithThemeAndScaler({
    required Widget child,
    required ThemeMode themeMode,
    double textScale = 1.3,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: c!,
      ),
      home: Scaffold(body: child),
    );
  }

  Future<void> pumpBalancesView(
    WidgetTester tester,
    double width,
    double height,
    ThemeMode themeMode,
  ) async {
    setupViewport(tester, width, height);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authUserProvider.overrideWithValue(AsyncData(mockOrg)),
          tripAllMembersProvider(trip.id).overrideWithValue(
            AsyncData([orgMember, aliceMember, bobLeftMember]),
          ),
          tripMembersProvider(trip.id).overrideWithValue(
            AsyncData([orgMember, aliceMember, bobLeftMember]),
          ),
          tripBalancesProvider(trip.id).overrideWithValue({
            'org_user': 2425,
            'mem_alice': -1550,
            'mem_bob': -875,
          }),
          totalTripSpentProvider(trip.id).overrideWithValue(15000),
          settlementsStreamProvider(trip.id)
              .overrideWithValue(AsyncData([sConfirmed, sRejected, sPending])),
        ],
        child: wrapWithThemeAndScaler(
          themeMode: themeMode,
          child: BalancesView(trip: trip),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpMembersTab({
    required WidgetTester tester,
    required double width,
    required double height,
    required ThemeMode themeMode,
    required bool isOrganizer,
  }) async {
    setupViewport(tester, width, height);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authUserProvider.overrideWithValue(
            AsyncData(isOrganizer ? mockOrg : mockAlice),
          ),
          tripMembersProvider(
            trip.id,
          ).overrideWithValue(AsyncData([orgMember, aliceMember, bobMember])),
          tripBalancesProvider(trip.id)
              .overrideWithValue({'org_user': 0, 'mem_alice': 0, 'mem_bob': 0}),
          settlementsStreamProvider(trip.id)
              .overrideWithValue(const AsyncData([])),
        ],
        child: wrapWithThemeAndScaler(
          themeMode: themeMode,
          child: MembersTab(trip: trip),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpMarkAsPaidSheet(
    WidgetTester tester,
    double width,
    double height,
    ThemeMode themeMode,
  ) async {
    setupViewport(tester, width, height);
    await tester.pumpWidget(
      ProviderScope(
        child: wrapWithThemeAndScaler(
          themeMode: themeMode,
          child: SingleChildScrollView(
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
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpLeaveDialogBlocked(
    WidgetTester tester,
    double width,
    double height,
    ThemeMode themeMode,
  ) async {
    setupViewport(tester, width, height);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authUserProvider.overrideWithValue(AsyncData(mockAlice)),
          tripMembersProvider(
            trip.id,
          ).overrideWithValue(AsyncData([orgMember, aliceMember, bobMember])),
          tripBalancesProvider(trip.id).overrideWithValue({
            'org_user': 1550,
            'mem_alice': -1550,
            'mem_bob': 0,
          }),
          settlementsStreamProvider(trip.id)
              .overrideWithValue(const AsyncData([])),
        ],
        child: wrapWithThemeAndScaler(
          themeMode: themeMode,
          child: MembersTab(trip: trip),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave Trip'));
    await tester.pumpAndSettle();
  }

  Future<void> pumpLeaveDialogAllowed(
    WidgetTester tester,
    double width,
    double height,
    ThemeMode themeMode,
  ) async {
    setupViewport(tester, width, height);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authUserProvider.overrideWithValue(AsyncData(mockAlice)),
          tripMembersProvider(
            trip.id,
          ).overrideWithValue(AsyncData([orgMember, aliceMember, bobMember])),
          tripBalancesProvider(trip.id)
              .overrideWithValue({'org_user': 0, 'mem_alice': 0, 'mem_bob': 0}),
          settlementsStreamProvider(trip.id)
              .overrideWithValue(const AsyncData([])),
        ],
        child: wrapWithThemeAndScaler(
          themeMode: themeMode,
          child: MembersTab(trip: trip),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave Trip'));
    await tester.pumpAndSettle();
  }

  Future<void> pumpRemoveDialog(
    WidgetTester tester,
    double width,
    double height,
    ThemeMode themeMode,
  ) async {
    setupViewport(tester, width, height);
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
        child: wrapWithThemeAndScaler(
          themeMode: themeMode,
          child: MembersTab(trip: trip),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
  }

  group('Settlements Overflow Matrix Tests (O1)', () {
    // Surface 1: BalancesView with pending+confirmed+rejected settlements and a (left) member
    testWidgets('O1.1 BalancesView (320x568, Light, 1.3x text)', (
      tester,
    ) async {
      await pumpBalancesView(tester, 320, 568, ThemeMode.light);
      expect(tester.takeException(), isNull);
      expect(find.text('Payments History'), findsOneWidget);
    });

    testWidgets('O1.2 BalancesView (320x568, Dark, 1.3x text)', (tester) async {
      await pumpBalancesView(tester, 320, 568, ThemeMode.dark);
      expect(tester.takeException(), isNull);
      expect(find.text('Payments History'), findsOneWidget);
    });

    testWidgets('O1.3 BalancesView (360x640, Light, 1.3x text)', (
      tester,
    ) async {
      await pumpBalancesView(tester, 360, 640, ThemeMode.light);
      expect(tester.takeException(), isNull);
      expect(find.text('Payments History'), findsOneWidget);
    });

    testWidgets('O1.4 BalancesView (360x640, Dark, 1.3x text)', (tester) async {
      await pumpBalancesView(tester, 360, 640, ThemeMode.dark);
      expect(tester.takeException(), isNull);
      expect(find.text('Payments History'), findsOneWidget);
    });

    // Surface 2: MembersTab as organizer
    testWidgets('O1.5 MembersTab as organizer (320x568, Light, 1.3x text)', (
      tester,
    ) async {
      await pumpMembersTab(
        tester: tester,
        width: 320,
        height: 568,
        themeMode: ThemeMode.light,
        isOrganizer: true,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Remove'), findsWidgets);
    });

    testWidgets('O1.6 MembersTab as organizer (320x568, Dark, 1.3x text)', (
      tester,
    ) async {
      await pumpMembersTab(
        tester: tester,
        width: 320,
        height: 568,
        themeMode: ThemeMode.dark,
        isOrganizer: true,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Remove'), findsWidgets);
    });

    testWidgets('O1.7 MembersTab as organizer (360x640, Light, 1.3x text)', (
      tester,
    ) async {
      await pumpMembersTab(
        tester: tester,
        width: 360,
        height: 640,
        themeMode: ThemeMode.light,
        isOrganizer: true,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Remove'), findsWidgets);
    });

    testWidgets('O1.8 MembersTab as organizer (360x640, Dark, 1.3x text)', (
      tester,
    ) async {
      await pumpMembersTab(
        tester: tester,
        width: 360,
        height: 640,
        themeMode: ThemeMode.dark,
        isOrganizer: true,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Remove'), findsWidgets);
    });

    // Surface 3: MembersTab as plain member
    testWidgets('O1.9 MembersTab as plain member (320x568, Light, 1.3x text)', (
      tester,
    ) async {
      await pumpMembersTab(
        tester: tester,
        width: 320,
        height: 568,
        themeMode: ThemeMode.light,
        isOrganizer: false,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Leave Trip'), findsOneWidget);
    });

    testWidgets('O1.10 MembersTab as plain member (320x568, Dark, 1.3x text)', (
      tester,
    ) async {
      await pumpMembersTab(
        tester: tester,
        width: 320,
        height: 568,
        themeMode: ThemeMode.dark,
        isOrganizer: false,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Leave Trip'), findsOneWidget);
    });

    testWidgets(
      'O1.11 MembersTab as plain member (360x640, Light, 1.3x text)',
      (tester) async {
        await pumpMembersTab(
          tester: tester,
          width: 360,
          height: 640,
          themeMode: ThemeMode.light,
          isOrganizer: false,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Leave Trip'), findsOneWidget);
      },
    );

    testWidgets('O1.12 MembersTab as plain member (360x640, Dark, 1.3x text)', (
      tester,
    ) async {
      await pumpMembersTab(
        tester: tester,
        width: 360,
        height: 640,
        themeMode: ThemeMode.dark,
        isOrganizer: false,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Leave Trip'), findsOneWidget);
    });

    // Surface 4: MarkAsPaidSheet
    testWidgets('O1.13 MarkAsPaidSheet (320x568, Light, 1.3x text)', (
      tester,
    ) async {
      await pumpMarkAsPaidSheet(tester, 320, 568, ThemeMode.light);
      expect(tester.takeException(), isNull);
      expect(find.text('Mark Payment as Paid'), findsOneWidget);
    });

    testWidgets('O1.14 MarkAsPaidSheet (320x568, Dark, 1.3x text)', (
      tester,
    ) async {
      await pumpMarkAsPaidSheet(tester, 320, 568, ThemeMode.dark);
      expect(tester.takeException(), isNull);
      expect(find.text('Mark Payment as Paid'), findsOneWidget);
    });

    testWidgets('O1.15 MarkAsPaidSheet (360x640, Light, 1.3x text)', (
      tester,
    ) async {
      await pumpMarkAsPaidSheet(tester, 360, 640, ThemeMode.light);
      expect(tester.takeException(), isNull);
      expect(find.text('Mark Payment as Paid'), findsOneWidget);
    });

    testWidgets('O1.16 MarkAsPaidSheet (360x640, Dark, 1.3x text)', (
      tester,
    ) async {
      await pumpMarkAsPaidSheet(tester, 360, 640, ThemeMode.dark);
      expect(tester.takeException(), isNull);
      expect(find.text('Mark Payment as Paid'), findsOneWidget);
    });

    // Surface 5: Leave dialog (blocked)
    testWidgets('O1.17 Leave dialog blocked (320x568, Light, 1.3x text)', (
      tester,
    ) async {
      await pumpLeaveDialogBlocked(tester, 320, 568, ThemeMode.light);
      expect(tester.takeException(), isNull);
      expect(find.text('Cannot Leave Trip'), findsOneWidget);
    });

    testWidgets('O1.18 Leave dialog blocked (320x568, Dark, 1.3x text)', (
      tester,
    ) async {
      await pumpLeaveDialogBlocked(tester, 320, 568, ThemeMode.dark);
      expect(tester.takeException(), isNull);
      expect(find.text('Cannot Leave Trip'), findsOneWidget);
    });

    testWidgets('O1.19 Leave dialog blocked (360x640, Light, 1.3x text)', (
      tester,
    ) async {
      await pumpLeaveDialogBlocked(tester, 360, 640, ThemeMode.light);
      expect(tester.takeException(), isNull);
      expect(find.text('Cannot Leave Trip'), findsOneWidget);
    });

    testWidgets('O1.20 Leave dialog blocked (360x640, Dark, 1.3x text)', (
      tester,
    ) async {
      await pumpLeaveDialogBlocked(tester, 360, 640, ThemeMode.dark);
      expect(tester.takeException(), isNull);
      expect(find.text('Cannot Leave Trip'), findsOneWidget);
    });

    // Surface 6: Leave dialog (allowed)
    testWidgets('O1.21 Leave dialog allowed (320x568, Light, 1.3x text)', (
      tester,
    ) async {
      await pumpLeaveDialogAllowed(tester, 320, 568, ThemeMode.light);
      expect(tester.takeException(), isNull);
      expect(find.text('Leave Trip'), findsNWidgets(2));
    });

    testWidgets('O1.22 Leave dialog allowed (320x568, Dark, 1.3x text)', (
      tester,
    ) async {
      await pumpLeaveDialogAllowed(tester, 320, 568, ThemeMode.dark);
      expect(tester.takeException(), isNull);
      expect(find.text('Leave Trip'), findsNWidgets(2));
    });

    testWidgets('O1.23 Leave dialog allowed (360x640, Light, 1.3x text)', (
      tester,
    ) async {
      await pumpLeaveDialogAllowed(tester, 360, 640, ThemeMode.light);
      expect(tester.takeException(), isNull);
      expect(find.text('Leave Trip'), findsNWidgets(2));
    });

    testWidgets('O1.24 Leave dialog allowed (360x640, Dark, 1.3x text)', (
      tester,
    ) async {
      await pumpLeaveDialogAllowed(tester, 360, 640, ThemeMode.dark);
      expect(tester.takeException(), isNull);
      expect(find.text('Leave Trip'), findsNWidgets(2));
    });

    // Surface 7: Remove dialog
    testWidgets('O1.25 Remove dialog (320x568, Light, 1.3x text)', (
      tester,
    ) async {
      await pumpRemoveDialog(tester, 320, 568, ThemeMode.light);
      expect(tester.takeException(), isNull);
      expect(find.text('Remove Member'), findsOneWidget);
    });

    testWidgets('O1.26 Remove dialog (320x568, Dark, 1.3x text)', (
      tester,
    ) async {
      await pumpRemoveDialog(tester, 320, 568, ThemeMode.dark);
      expect(tester.takeException(), isNull);
      expect(find.text('Remove Member'), findsOneWidget);
    });

    testWidgets('O1.27 Remove dialog (360x640, Light, 1.3x text)', (
      tester,
    ) async {
      await pumpRemoveDialog(tester, 360, 640, ThemeMode.light);
      expect(tester.takeException(), isNull);
      expect(find.text('Remove Member'), findsOneWidget);
    });

    testWidgets('O1.28 Remove dialog (360x640, Dark, 1.3x text)', (
      tester,
    ) async {
      await pumpRemoveDialog(tester, 360, 640, ThemeMode.dark);
      expect(tester.takeException(), isNull);
      expect(find.text('Remove Member'), findsOneWidget);
    });

    // Baseline viewports
    testWidgets('O1.29 Standard phone: Pixel 7 412x915 at 1.0 text scale', (
      tester,
    ) async {
      setupViewport(tester, 412, 915);
      await pumpBalancesView(tester, 412, 915, ThemeMode.light);
      expect(tester.takeException(), isNull);
    });

    testWidgets('O1.30 Tablet layout: iPad 10th gen 820x1180', (tester) async {
      setupViewport(tester, 820, 1180);
      await pumpBalancesView(tester, 820, 1180, ThemeMode.light);
      expect(tester.takeException(), isNull);
    });

    testWidgets('O1.31 Landscape orientation: 844x390', (tester) async {
      setupViewport(tester, 844, 390);
      await pumpBalancesView(tester, 844, 390, ThemeMode.light);
      expect(tester.takeException(), isNull);
    });
  });
}
