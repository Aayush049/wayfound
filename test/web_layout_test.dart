import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in_mocks/google_sign_in_mocks.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wayfound/app/router.dart';
import 'package:wayfound/app/theme/app_theme.dart';
import 'package:wayfound/app/theme/theme_provider.dart';
import 'package:wayfound/core/widgets/centered_content.dart';
import 'package:wayfound/features/auth/data/auth_provider.dart';
import 'package:wayfound/features/auth/data/auth_repository.dart';
import 'package:wayfound/features/auth/domain/app_user.dart';
import 'package:wayfound/features/auth/presentation/sign_in_screen.dart';
import 'package:wayfound/features/trips/data/trips_providers.dart';
import 'package:wayfound/features/trips/domain/member.dart';
import 'package:wayfound/features/trips/domain/trip.dart';
import 'package:wayfound/features/trips/presentation/create_trip_screen.dart';
import 'package:wayfound/features/trips/presentation/home_screen.dart';
import 'package:wayfound/features/trips/presentation/trip_card.dart';
import 'package:wayfound/features/trips/presentation/trip_dashboard_screen.dart';

void main() {
  final activeTrip1 = Trip(
    id: 'trip-1',
    name: 'Active Trip 1',
    destination: 'Goa',
    startDate: DateTime(2026, 8, 1),
    endDate: DateTime(2026, 8, 5),
    currency: 'INR',
    organizerId: 'user-123',
    joinCode: 'ABC234',
    memberIds: ['user-123'],
    memberCount: 1,
    archived: false,
  );
  final activeTrip2 = Trip(
    id: 'trip-2',
    name: 'Active Trip 2',
    destination: 'Mumbai',
    startDate: DateTime(2026, 9, 1),
    endDate: DateTime(2026, 9, 5),
    currency: 'INR',
    organizerId: 'user-123',
    joinCode: 'DEF567',
    memberIds: ['user-123'],
    memberCount: 1,
    archived: false,
  );
  final activeTrip3 = Trip(
    id: 'trip-3',
    name: 'Active Trip 3',
    destination: 'Delhi',
    startDate: DateTime(2026, 10, 1),
    endDate: DateTime(2026, 10, 5),
    currency: 'INR',
    organizerId: 'user-123',
    joinCode: 'GHI890',
    memberIds: ['user-123'],
    memberCount: 1,
    archived: false,
  );
  final archivedTrip = Trip(
    id: 'trip-archived',
    name: 'Archived Trip',
    destination: 'Kerala',
    startDate: DateTime(2025, 1, 1),
    endDate: DateTime(2025, 1, 5),
    currency: 'INR',
    organizerId: 'user-123',
    joinCode: 'JKL123',
    memberIds: ['user-123'],
    memberCount: 1,
    archived: true,
  );

  final testTrips = [activeTrip1, activeTrip2, activeTrip3, archivedTrip];
  final mockUser = MockUser(uid: 'user-123', email: 'test@example.com');
  final appUser = AppUser(
    uid: 'user-123',
    email: 'test@example.com',
    displayName: 'Test User',
  );

  Widget buildHomeScreen(List<Trip> trips) {
    SharedPreferences.setMockInitialValues({});
    return ProviderScope(
      key: const Key('home_scope'),
      overrides: [
        myTripsProvider.overrideWithValue(AsyncData(trips)),
        authUserProvider.overrideWithValue(AsyncData(mockUser)),
        appUserProvider.overrideWithValue(AsyncData(appUser)),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: const HomeScreen()),
    );
  }

  final member = Member(
    uid: 'user-123',
    displayName: 'Test User',
    role: 'organizer',
    status: 'active',
    joinedAt: DateTime(2026, 8, 1),
  );

  Widget buildDashboard() {
    return ProviderScope(
      key: const Key('dashboard_scope'),
      overrides: [
        authUserProvider.overrideWithValue(AsyncData(mockUser)),
        appUserProvider.overrideWithValue(AsyncData(appUser)),
        tripProvider('trip-1').overrideWithValue(AsyncData(activeTrip1)),
        tripMembersProvider('trip-1').overrideWithValue(AsyncData([member])),
      ],
      child: const MaterialApp(
        home: TripDashboardScreen(tripId: 'trip-1', activeTab: 'members'),
      ),
    );
  }

  group('Web Layout Tests', () {
    testWidgets(
      'T1: Home grid renders 1 column at 400 wide, 2 columns at 900 wide, and 3 columns at 1300 wide',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.view.devicePixelRatio = 1.0;

        // 400 wide -> 1 column via ListView
        tester.view.physicalSize = const Size(400, 800);
        await tester.pumpWidget(buildHomeScreen(testTrips));
        await tester.pumpAndSettle();

        expect(find.byType(ListView), findsOneWidget);
        expect(find.byType(SliverGrid), findsNothing);
        expect(find.byType(TripCard), findsNWidgets(4));

        // 900 wide -> 2 columns via SliverGrid
        tester.view.physicalSize = const Size(900, 800);
        await tester.pumpWidget(buildHomeScreen(testTrips));
        await tester.pumpAndSettle();

        expect(find.byType(SliverGrid), findsWidgets);
        final grids900 = tester
            .widgetList<SliverGrid>(find.byType(SliverGrid))
            .toList();
        final delegate900 =
            grids900.first.gridDelegate
                as SliverGridDelegateWithFixedCrossAxisCount;
        expect(delegate900.crossAxisCount, equals(2));

        // 1300 wide -> 3 columns via SliverGrid
        tester.view.physicalSize = const Size(1300, 800);
        await tester.pumpWidget(buildHomeScreen(testTrips));
        await tester.pumpAndSettle();

        expect(find.byType(SliverGrid), findsWidgets);
        final grids1300 = tester
            .widgetList<SliverGrid>(find.byType(SliverGrid))
            .toList();
        final delegate1300 =
            grids1300.first.gridDelegate
                as SliverGridDelegateWithFixedCrossAxisCount;
        expect(delegate1300.crossAxisCount, equals(3));

        // Archived header is present and active trips precede archived trips
        expect(
          find.byKey(const Key('home_archived_section_header')),
          findsOneWidget,
        );
        final activeCardPos = tester.getTopLeft(find.text('Active Trip 1'));
        final archivedCardPos = tester.getTopLeft(find.text('Archived Trip'));
        expect(activeCardPos.dy, lessThan(archivedCardPos.dy));
      },
    );

    testWidgets(
      'T2: CenteredContent constrains child to maxWidth at 1300 wide and applies no extra constraint at 400 wide',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.view.devicePixelRatio = 1.0;

        // At 1300 wide
        tester.view.physicalSize = const Size(1300, 800);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CenteredContent(
                maxWidth: 1000,
                child: Container(key: const Key('test_child')),
              ),
            ),
          ),
        );
        final rect1300 = tester.getRect(find.byKey(const Key('test_child')));
        expect(rect1300.width, equals(1000.0));

        // At 400 wide
        tester.view.physicalSize = const Size(400, 800);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CenteredContent(
                maxWidth: 1000,
                child: Container(key: const Key('test_child')),
              ),
            ),
          ),
        );
        final rect400 = tester.getRect(find.byKey(const Key('test_child')));
        expect(rect400.width, equals(400.0));
      },
    );

    testWidgets(
      'T3: Trip dashboard at 1300 wide has left-aligned scrollable TabBar and constrained body; at 400 wide is compact',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.view.devicePixelRatio = 1.0;

        // At 1300 wide
        tester.view.physicalSize = const Size(1300, 800);
        await tester.pumpWidget(buildDashboard());
        await tester.pumpAndSettle();

        final tabBar1300 = tester.widget<TabBar>(find.byType(TabBar));
        expect(tabBar1300.isScrollable, isTrue);
        expect(tabBar1300.tabAlignment, equals(TabAlignment.start));
        expect(find.byType(CenteredContent), findsOneWidget);

        // At 400 wide
        tester.view.physicalSize = const Size(400, 800);
        await tester.pumpWidget(buildDashboard());
        await tester.pumpAndSettle();

        final tabBar400 = tester.widget<TabBar>(find.byType(TabBar));
        expect(tabBar400.isScrollable, isFalse);
        expect(tabBar400.tabAlignment, isNull);
        expect(find.byType(CenteredContent), findsNothing);
      },
    );

    testWidgets(
      'T4: Auth screen at 1300 wide displays 440-wide card; at 400 wide renders directly',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.view.devicePixelRatio = 1.0;

        final firestore = FakeFirebaseFirestore();
        final auth = MockFirebaseAuth();
        final googleSignIn = MockGoogleSignIn();
        final repository = AuthRepository(
          auth: auth,
          googleSignIn: googleSignIn,
          firestore: firestore,
        );
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        Widget buildAuthScreen() {
          return ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              authRepositoryProvider.overrideWithValue(repository),
            ],
            child: const MaterialApp(home: SignInScreen()),
          );
        }

        // At 1300 wide
        tester.view.physicalSize = const Size(1300, 800);
        await tester.pumpWidget(buildAuthScreen());
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('auth_centered_card')), findsOneWidget);
        final cardRect = tester.getRect(
          find.byKey(const Key('auth_centered_card')),
        );
        expect(cardRect.width, equals(440.0));

        // At 400 wide
        tester.view.physicalSize = const Size(400, 800);
        await tester.pumpWidget(buildAuthScreen());
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('auth_centered_card')), findsNothing);
        expect(find.byType(SingleChildScrollView), findsOneWidget);
      },
    );

    testWidgets('T5: URL reflects imperative navigation and restores on pop', (
      tester,
    ) async {
      final firestore = FakeFirebaseFirestore();
      final auth = MockFirebaseAuth(signedIn: true, mockUser: mockUser);
      final repository = AuthRepository(auth: auth, firestore: firestore);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      late GoRouter router;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            authRepositoryProvider.overrideWithValue(repository),
            authUserProvider.overrideWithValue(AsyncData(mockUser)),
            appUserProvider.overrideWithValue(AsyncData(appUser)),
            myTripsProvider.overrideWithValue(const AsyncData([])),
            tripProvider('trip-1').overrideWithValue(AsyncData(activeTrip1)),
            tripMembersProvider('trip-1')
                .overrideWithValue(const AsyncData([])),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              router = ref.watch(routerProvider);
              return MaterialApp.router(routerConfig: router);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.toString(),
        equals('/home'),
      );

      router.push('/trip/trip-1/members');
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.toString(),
        equals('/trip/trip-1/members'),
      );

      router.pop();
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.toString(),
        equals('/home'),
      );
    });

    testWidgets(
      'T6: Compact regression check on Home, Trip Dashboard, and Create Trip at 400 wide',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(400, 800);

        // Home screen at 400
        await tester.pumpWidget(buildHomeScreen(testTrips));
        await tester.pumpAndSettle();
        expect(find.byType(ListView), findsOneWidget);
        expect(find.byType(CenteredContent), findsNothing);

        // Trip Dashboard at 400
        await tester.pumpWidget(buildDashboard());
        await tester.pumpAndSettle();
        expect(find.byType(TabBar), findsOneWidget);
        expect(find.byType(CenteredContent), findsNothing);

        // Create Trip Screen at 400
        await tester.pumpWidget(
          ProviderScope(
            key: const Key('create_scope'),
            overrides: [
              authUserProvider.overrideWithValue(AsyncData(mockUser)),
            ],
            child: const MaterialApp(home: CreateTripScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(SingleChildScrollView), findsOneWidget);
        expect(find.byType(CenteredContent), findsNothing);
      },
    );
  });
}
