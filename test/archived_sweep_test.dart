import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfound/core/widgets/app_error.dart';
import 'package:wayfound/core/widgets/app_loading.dart';
import 'package:wayfound/features/auth/domain/app_user.dart';
import 'package:wayfound/features/expenses/data/expenses_providers.dart';
import 'package:wayfound/features/expenses/domain/balance_calculator.dart';
import 'package:wayfound/features/expenses/domain/expense.dart';
import 'package:wayfound/features/expenses/presentation/balances_view.dart';
import 'package:wayfound/features/expenses/presentation/expense_card.dart';
import 'package:wayfound/features/expenses/presentation/expenses_tab.dart';
import 'package:wayfound/features/itinerary/data/itinerary_providers.dart';
import 'package:wayfound/features/itinerary/presentation/itinerary_day_section.dart';
import 'package:wayfound/features/itinerary/presentation/itinerary_item_tile.dart';
import 'package:wayfound/features/itinerary/presentation/itinerary_tab.dart';
import 'package:wayfound/features/settlements/data/settlements_providers.dart';
import 'package:wayfound/features/settlements/domain/settlement.dart';
import 'package:wayfound/features/suggestions/data/suggestions_providers.dart';
import 'package:wayfound/features/suggestions/domain/suggestion.dart';
import 'package:wayfound/features/suggestions/presentation/suggestion_card.dart';
import 'package:wayfound/features/suggestions/presentation/suggestions_tab.dart';
import 'package:wayfound/features/suggestions/presentation/vote_buttons.dart';
import 'package:wayfound/features/trips/data/trips_providers.dart';
import 'package:wayfound/features/trips/domain/member.dart';
import 'package:wayfound/features/trips/domain/trip.dart';
import 'package:wayfound/features/trips/presentation/members_tab.dart';

import 'helpers/pump_app.dart';

void main() {
  group('Archived Sweep Tests (B & C)', () {
    const orgUid = 'user_org';
    const memberUid = 'user_mem';
    const tripId = 'sweep_trip_1';

    final mockOrgUser = MockUser(uid: orgUid, email: 'org@test.com');
    final mockMemberUser = MockUser(uid: memberUid, email: 'mem@test.com');

    final orgAppUser = AppUser(
      uid: orgUid,
      email: 'org@test.com',
      displayName: 'Alice Organizer',
    );
    final memAppUser = AppUser(
      uid: memberUid,
      email: 'mem@test.com',
      displayName: 'Bob Member',
    );

    final orgMember = Member(
      uid: orgUid,
      displayName: 'Alice Organizer',
      role: 'organizer',
      status: 'active',
      joinedAt: DateTime(2026, 1, 1),
    );
    final regularMember = Member(
      uid: memberUid,
      displayName: 'Bob Member',
      role: 'member',
      status: 'active',
      joinedAt: DateTime(2026, 1, 2),
    );

    Trip createTrip({required bool archived}) {
      return Trip(
        id: tripId,
        name: 'Alpine Trek',
        destination: 'Swiss Alps',
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 10),
        currency: 'USD',
        organizerId: orgUid,
        joinCode: 'ALP123',
        memberIds: const [orgUid, memberUid],
        memberCount: 2,
        archived: archived,
      );
    }

    final activeTrip = createTrip(archived: false);
    final archivedTrip = createTrip(archived: true);

    // -------------------------------------------------------------------------
    // 1. Suggestions Tab & Card
    // -------------------------------------------------------------------------
    group('Suggestions Tab and Card', () {
      final testSuggestion = Suggestion(
        id: 'sugg_1',
        tripId: tripId,
        title: 'Hike to Matterhorn Base',
        note: 'Breathtaking sunrise views',
        estimatedCost: 2000,
        category: 'activity',
        authorId: orgUid,
        upCount: 3,
        downCount: 1,
        status: 'pending',
        createdAt: DateTime(2026, 8, 1),
      );

      testWidgets(
        'add suggestion FAB and empty action are present when active',
        (tester) async {
          await tester.pumpApp(
            Scaffold(body: SuggestionsTab(trip: activeTrip)),
            authUserValue: AsyncData(mockOrgUser),
            appUserValue: AsyncData(orgAppUser),
            overrides: [
              suggestionsStreamProvider(tripId)
                  .overrideWithValue(const AsyncData([])),
              tripMembersProvider(tripId)
                  .overrideWithValue(AsyncData([orgMember, regularMember])),
            ],
          );

          expect(find.byType(FloatingActionButton), findsOneWidget);
          expect(find.text('Add Suggestion'), findsWidgets);
        },
      );

      testWidgets(
        'add suggestion FAB and empty action are absent when archived',
        (tester) async {
          await tester.pumpApp(
            Scaffold(body: SuggestionsTab(trip: archivedTrip)),
            authUserValue: AsyncData(mockOrgUser),
            appUserValue: AsyncData(orgAppUser),
            overrides: [
              suggestionsStreamProvider(tripId)
                  .overrideWithValue(const AsyncData([])),
              tripMembersProvider(tripId)
                  .overrideWithValue(AsyncData([orgMember, regularMember])),
            ],
          );

          expect(find.byType(FloatingActionButton), findsNothing);
          expect(find.text('Add Suggestion'), findsNothing);
          expect(find.text('No suggestions yet'), findsOneWidget);
        },
      );

      testWidgets(
        'suggestion card edit/delete menu is present on active trip and absent on archived trip',
        (tester) async {
          // (a) Active trip
          await tester.pumpApp(
            Scaffold(
              body: SuggestionCard(
                suggestion: testSuggestion,
                currency: 'USD',
                currentUserId: orgUid,
                isOrganizer: true,
                members: [orgMember, regularMember],
                isArchived: false,
              ),
            ),
            authUserValue: AsyncData(mockOrgUser),
            appUserValue: AsyncData(orgAppUser),
          );

          expect(find.byType(PopupMenuButton<String>), findsOneWidget);

          // (b) Archived trip
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();

          await tester.pumpApp(
            Scaffold(
              body: SuggestionCard(
                suggestion: testSuggestion,
                currency: 'USD',
                currentUserId: orgUid,
                isOrganizer: true,
                members: [orgMember, regularMember],
                isArchived: true,
              ),
            ),
            authUserValue: AsyncData(mockOrgUser),
            appUserValue: AsyncData(orgAppUser),
          );

          expect(find.byType(PopupMenuButton<String>), findsNothing);
          expect(find.text('Hike to Matterhorn Base'), findsOneWidget);
        },
      );

      testWidgets(
        'vote buttons are enabled on active trip and disabled on archived trip',
        (tester) async {
          // (a) Active trip
          await tester.pumpApp(
            Scaffold(
              body: SuggestionCard(
                suggestion: testSuggestion,
                currency: 'USD',
                currentUserId: orgUid,
                isOrganizer: true,
                members: [orgMember, regularMember],
                isArchived: false,
              ),
            ),
            authUserValue: AsyncData(mockOrgUser),
            appUserValue: AsyncData(orgAppUser),
          );

          final activeVoteButtons = tester.widget<VoteButtons>(
            find.byType(VoteButtons),
          );
          expect(activeVoteButtons.onUpVote, isNotNull);
          expect(activeVoteButtons.onDownVote, isNotNull);

          // (b) Archived trip
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();

          await tester.pumpApp(
            Scaffold(
              body: SuggestionCard(
                suggestion: testSuggestion,
                currency: 'USD',
                currentUserId: orgUid,
                isOrganizer: true,
                members: [orgMember, regularMember],
                isArchived: true,
              ),
            ),
            authUserValue: AsyncData(mockOrgUser),
            appUserValue: AsyncData(orgAppUser),
          );

          final archivedVoteButtons = tester.widget<VoteButtons>(
            find.byType(VoteButtons),
          );
          expect(archivedVoteButtons.onUpVote, isNull);
          expect(archivedVoteButtons.onDownVote, isNull);

          // Counts and score stay readable
          expect(find.text('3'), findsOneWidget);
          expect(find.text('1'), findsOneWidget);

          // Tapping disabled vote button does not throw or trigger action
          await tester.tap(find.byTooltip('Upvote'));
          await tester.pump();
        },
      );
    });

    // -------------------------------------------------------------------------
    // 2. Expenses Tab & Expense Card
    // -------------------------------------------------------------------------
    group('Expenses Tab and Expense Card', () {
      final testExpense = Expense(
        id: 'exp_1',
        description: 'Alpine Chalet Dinner',
        amount: 8000,
        paidBy: orgUid,
        participantIds: [orgUid, memberUid],
        date: DateTime(2026, 8, 2),
        createdBy: orgUid,
        createdAt: DateTime(2026, 8, 2),
      );

      testWidgets(
        'add expense FAB and empty action are present on active trip',
        (tester) async {
          await tester.pumpApp(
            ExpensesTab(trip: activeTrip),
            authUserValue: AsyncData(mockOrgUser),
            appUserValue: AsyncData(orgAppUser),
            overrides: [
              expensesStreamProvider(tripId)
                  .overrideWithValue(const AsyncData([])),
              tripMembersProvider(tripId)
                  .overrideWithValue(AsyncData([orgMember, regularMember])),
              tripAllMembersProvider(tripId)
                  .overrideWithValue(AsyncData([orgMember, regularMember])),
              settlementsStreamProvider(tripId)
                  .overrideWithValue(const AsyncData([])),
            ],
          );

          expect(find.byType(FloatingActionButton), findsOneWidget);
          expect(find.text('Add Expense'), findsWidgets);
        },
      );

      testWidgets(
        'add expense FAB and empty action are absent on archived trip',
        (tester) async {
          await tester.pumpApp(
            ExpensesTab(trip: archivedTrip),
            authUserValue: AsyncData(mockOrgUser),
            appUserValue: AsyncData(orgAppUser),
            overrides: [
              expensesStreamProvider(tripId)
                  .overrideWithValue(const AsyncData([])),
              tripMembersProvider(tripId)
                  .overrideWithValue(AsyncData([orgMember, regularMember])),
              tripAllMembersProvider(tripId)
                  .overrideWithValue(AsyncData([orgMember, regularMember])),
              settlementsStreamProvider(tripId)
                  .overrideWithValue(const AsyncData([])),
            ],
          );

          expect(find.byType(FloatingActionButton), findsNothing);
          expect(find.text('Add Expense'), findsNothing);
          expect(find.text('No expenses yet'), findsOneWidget);
        },
      );

      testWidgets(
        'expense card edit/delete menu is present on active trip and absent on archived trip',
        (tester) async {
          // (a) Active trip
          await tester.pumpApp(
            Scaffold(
              body: ExpenseCard(
                expense: testExpense,
                currency: 'USD',
                members: [orgMember, regularMember],
                canManage: true,
                isArchived: false,
              ),
            ),
            authUserValue: AsyncData(mockOrgUser),
            appUserValue: AsyncData(orgAppUser),
          );

          expect(find.byType(PopupMenuButton<String>), findsOneWidget);

          // (b) Archived trip
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();

          await tester.pumpApp(
            Scaffold(
              body: ExpenseCard(
                expense: testExpense,
                currency: 'USD',
                members: [orgMember, regularMember],
                canManage: true,
                isArchived: true,
              ),
            ),
            authUserValue: AsyncData(mockOrgUser),
            appUserValue: AsyncData(orgAppUser),
          );

          expect(find.byType(PopupMenuButton<String>), findsNothing);
          expect(find.text('Alpine Chalet Dinner'), findsOneWidget);
          expect(find.textContaining('80.00'), findsOneWidget);
        },
      );
    });

    // -------------------------------------------------------------------------
    // 3. Balances View
    // -------------------------------------------------------------------------
    group('Balances View', () {
      final testExpense = Expense(
        id: 'exp_2',
        description: 'Ski Rental',
        amount: 6000,
        paidBy: orgUid,
        participantIds: [orgUid, memberUid],
        date: DateTime(2026, 8, 3),
        createdBy: orgUid,
        createdAt: DateTime(2026, 8, 3),
      );

      final pendingSettlement = Settlement(
        id: 'settle_pend_1',
        fromUid: memberUid,
        toUid: orgUid,
        amount: 2000,
        status: SettlementStatus.pending,
        createdAt: DateTime(2026, 8, 4),
      );

      testWidgets(
        'suggested payment Mark as Paid button shown on active trip, hidden on archived trip',
        (tester) async {
          // (a) Active trip (Bob owes Alice 30.00)
          await tester.pumpApp(
            Scaffold(body: BalancesView(trip: activeTrip)),
            authUserValue: AsyncData(mockMemberUser),
            appUserValue: AsyncData(memAppUser),
            overrides: [
              expensesStreamProvider(tripId)
                  .overrideWithValue(AsyncData([testExpense])),
              tripAllMembersProvider(tripId)
                  .overrideWithValue(AsyncData([orgMember, regularMember])),
              tripMembersProvider(tripId)
                  .overrideWithValue(AsyncData([orgMember, regularMember])),
              tripBalancesProvider(tripId)
                  .overrideWithValue({orgUid: 3000, memberUid: -3000}),
              suggestedPaymentsProvider(tripId).overrideWithValue([
                SuggestedPayment(
                  fromUid: memberUid,
                  toUid: orgUid,
                  amount: 3000,
                ),
              ]),
              totalTripSpentProvider(tripId).overrideWithValue(6000),
              settlementsStreamProvider(tripId)
                  .overrideWithValue(const AsyncData([])),
            ],
          );

          expect(find.text('Mark as Paid'), findsOneWidget);

          // (b) Archived trip
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();

          await tester.pumpApp(
            Scaffold(body: BalancesView(trip: archivedTrip)),
            authUserValue: AsyncData(mockMemberUser),
            appUserValue: AsyncData(memAppUser),
            overrides: [
              expensesStreamProvider(tripId)
                  .overrideWithValue(AsyncData([testExpense])),
              tripAllMembersProvider(tripId)
                  .overrideWithValue(AsyncData([orgMember, regularMember])),
              tripMembersProvider(tripId)
                  .overrideWithValue(AsyncData([orgMember, regularMember])),
              tripBalancesProvider(tripId)
                  .overrideWithValue({orgUid: 3000, memberUid: -3000}),
              suggestedPaymentsProvider(tripId).overrideWithValue([
                SuggestedPayment(
                  fromUid: memberUid,
                  toUid: orgUid,
                  amount: 3000,
                ),
              ]),
              totalTripSpentProvider(tripId).overrideWithValue(6000),
              settlementsStreamProvider(tripId)
                  .overrideWithValue(const AsyncData([])),
            ],
          );

          expect(find.text('Mark as Paid'), findsNothing);
          expect(find.text('Member Balances'), findsOneWidget);
          expect(find.text('Total Trip Spent'), findsOneWidget);
        },
      );

      testWidgets(
        'pending settlement action buttons (Confirm/Reject/Cancel) shown on active trip, hidden on archived trip',
        (tester) async {
          // (a) Active trip, organizer view: sees Confirm and Reject
          await tester.pumpApp(
            Scaffold(body: BalancesView(trip: activeTrip)),
            authUserValue: AsyncData(mockOrgUser),
            appUserValue: AsyncData(orgAppUser),
            overrides: [
              expensesStreamProvider(tripId)
                  .overrideWithValue(AsyncData([testExpense])),
              tripAllMembersProvider(tripId)
                  .overrideWithValue(AsyncData([orgMember, regularMember])),
              tripMembersProvider(tripId)
                  .overrideWithValue(AsyncData([orgMember, regularMember])),
              tripBalancesProvider(tripId)
                  .overrideWithValue({orgUid: 3000, memberUid: -3000}),
              suggestedPaymentsProvider(tripId).overrideWithValue([]),
              totalTripSpentProvider(tripId).overrideWithValue(6000),
              settlementsStreamProvider(tripId)
                  .overrideWithValue(AsyncData([pendingSettlement])),
            ],
          );

          expect(find.text('Confirm'), findsOneWidget);
          expect(find.text('Reject'), findsOneWidget);

          // (b) Archived trip, organizer view: actions hidden
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();

          await tester.pumpApp(
            Scaffold(body: BalancesView(trip: archivedTrip)),
            authUserValue: AsyncData(mockOrgUser),
            appUserValue: AsyncData(orgAppUser),
            overrides: [
              expensesStreamProvider(tripId)
                  .overrideWithValue(AsyncData([testExpense])),
              tripAllMembersProvider(tripId)
                  .overrideWithValue(AsyncData([orgMember, regularMember])),
              tripMembersProvider(tripId)
                  .overrideWithValue(AsyncData([orgMember, regularMember])),
              tripBalancesProvider(tripId)
                  .overrideWithValue({orgUid: 3000, memberUid: -3000}),
              suggestedPaymentsProvider(tripId).overrideWithValue([]),
              totalTripSpentProvider(tripId).overrideWithValue(6000),
              settlementsStreamProvider(tripId)
                  .overrideWithValue(AsyncData([pendingSettlement])),
            ],
          );

          expect(find.text('Confirm'), findsNothing);
          expect(find.text('Reject'), findsNothing);
          expect(find.text('Awaiting confirmation'), findsOneWidget);

          // (c) Active trip, payer view: sees Cancel
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();

          await tester.pumpApp(
            Scaffold(body: BalancesView(trip: activeTrip)),
            authUserValue: AsyncData(mockMemberUser),
            appUserValue: AsyncData(memAppUser),
            overrides: [
              expensesStreamProvider(tripId)
                  .overrideWithValue(AsyncData([testExpense])),
              tripAllMembersProvider(tripId)
                  .overrideWithValue(AsyncData([orgMember, regularMember])),
              tripMembersProvider(tripId)
                  .overrideWithValue(AsyncData([orgMember, regularMember])),
              tripBalancesProvider(tripId)
                  .overrideWithValue({orgUid: 3000, memberUid: -3000}),
              suggestedPaymentsProvider(tripId).overrideWithValue([]),
              totalTripSpentProvider(tripId).overrideWithValue(6000),
              settlementsStreamProvider(tripId)
                  .overrideWithValue(AsyncData([pendingSettlement])),
            ],
          );

          expect(find.text('Cancel'), findsOneWidget);

          // (d) Archived trip, payer view: Cancel hidden
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();

          await tester.pumpApp(
            Scaffold(body: BalancesView(trip: archivedTrip)),
            authUserValue: AsyncData(mockMemberUser),
            appUserValue: AsyncData(memAppUser),
            overrides: [
              expensesStreamProvider(tripId)
                  .overrideWithValue(AsyncData([testExpense])),
              tripAllMembersProvider(tripId)
                  .overrideWithValue(AsyncData([orgMember, regularMember])),
              tripMembersProvider(tripId)
                  .overrideWithValue(AsyncData([orgMember, regularMember])),
              tripBalancesProvider(tripId)
                  .overrideWithValue({orgUid: 3000, memberUid: -3000}),
              suggestedPaymentsProvider(tripId).overrideWithValue([]),
              totalTripSpentProvider(tripId).overrideWithValue(6000),
              settlementsStreamProvider(tripId)
                  .overrideWithValue(AsyncData([pendingSettlement])),
            ],
          );

          expect(find.text('Cancel'), findsNothing);
        },
      );

      testWidgets(
        'BalancesView displays AppLoading while any stream is loading',
        (tester) async {
          await tester.pumpApp(
            Scaffold(body: BalancesView(trip: activeTrip)),
            authUserValue: AsyncData(mockOrgUser),
            appUserValue: AsyncData(orgAppUser),
            overrides: [
              expensesStreamProvider(tripId)
                  .overrideWithValue(const AsyncLoading()),
              tripAllMembersProvider(tripId)
                  .overrideWithValue(AsyncData([orgMember, regularMember])),
              settlementsStreamProvider(tripId)
                  .overrideWithValue(const AsyncData([])),
            ],
          );

          expect(find.byType(AppLoading), findsOneWidget);
          expect(find.text('Loading balances...'), findsOneWidget);
        },
      );

      testWidgets(
        'BalancesView displays AppError when any stream has an error',
        (tester) async {
          await tester.pumpApp(
            Scaffold(body: BalancesView(trip: activeTrip)),
            authUserValue: AsyncData(mockOrgUser),
            appUserValue: AsyncData(orgAppUser),
            overrides: [
              expensesStreamProvider(tripId).overrideWithValue(
                AsyncError(Exception('Network timeout'), StackTrace.empty),
              ),
              tripAllMembersProvider(tripId)
                  .overrideWithValue(AsyncData([orgMember, regularMember])),
              settlementsStreamProvider(tripId)
                  .overrideWithValue(const AsyncData([])),
            ],
          );

          expect(find.byType(AppError), findsOneWidget);
          expect(
            find.text('Failed to load balances: Exception: Network timeout'),
            findsOneWidget,
          );
        },
      );
    });

    // -------------------------------------------------------------------------
    // 4. Itinerary Tab & Components
    // -------------------------------------------------------------------------
    group('Itinerary Tab and Components', () {
      final scheduledSugg = Suggestion(
        id: 'sugg_it_1',
        tripId: tripId,
        title: 'Cable car ride',
        note: 'High altitude cable car',
        estimatedCost: 4500,
        category: 'transport',
        authorId: orgUid,
        status: 'scheduled',
        dayIndex: 0,
        order: 0,
        upCount: 0,
        downCount: 0,
        createdAt: DateTime(2026, 8, 1),
      );

      testWidgets(
        'itinerary add suggestion to day button present when active, absent when archived',
        (tester) async {
          // (a) Active trip
          await tester.pumpApp(
            Scaffold(
              body: ItineraryTab(
                tripId: tripId,
                startDate: activeTrip.startDate,
                endDate: activeTrip.endDate,
                currency: 'USD',
                isOrganizer: true,
                isArchived: false,
              ),
            ),
            authUserValue: AsyncData(mockOrgUser),
            appUserValue: AsyncData(orgAppUser),
            overrides: [
              groupedItineraryProvider(tripId).overrideWithValue(
                AsyncData({
                  0: [scheduledSugg],
                }),
              ),
            ],
          );

          expect(find.byIcon(Icons.add), findsWidgets);

          // (b) Archived trip
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();

          await tester.pumpApp(
            Scaffold(
              body: ItineraryTab(
                tripId: tripId,
                startDate: activeTrip.startDate,
                endDate: activeTrip.endDate,
                currency: 'USD',
                isOrganizer: true,
                isArchived: true,
              ),
            ),
            authUserValue: AsyncData(mockOrgUser),
            appUserValue: AsyncData(orgAppUser),
            overrides: [
              groupedItineraryProvider(tripId).overrideWithValue(
                AsyncData({
                  0: [scheduledSugg],
                }),
              ),
            ],
          );

          expect(find.byIcon(Icons.add), findsNothing);
          expect(find.text('Cable car ride'), findsOneWidget);
        },
      );

      testWidgets('itinerary day section add button obeys isArchived', (
        tester,
      ) async {
        // Active
        await tester.pumpApp(
          Scaffold(
            body: ItineraryDaySection(
              dayIndex: 0,
              startDate: activeTrip.startDate,
              items: [scheduledSugg],
              currency: 'USD',
              isOrganizer: true,
              isArchived: false,
              onAddSuggestion: () {},
              onMoveItem: (_) {},
              onUnscheduleItem: (_) {},
            ),
          ),
        );

        expect(find.byIcon(Icons.add), findsOneWidget);

        // Archived
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();

        await tester.pumpApp(
          Scaffold(
            body: ItineraryDaySection(
              dayIndex: 0,
              startDate: activeTrip.startDate,
              items: [scheduledSugg],
              currency: 'USD',
              isOrganizer: true,
              isArchived: true,
              onAddSuggestion: () {},
              onMoveItem: (_) {},
              onUnscheduleItem: (_) {},
            ),
          ),
        );

        expect(find.byIcon(Icons.add), findsNothing);
        expect(find.text('Cable car ride'), findsOneWidget);
      });

      testWidgets(
        'itinerary item tile options menu present when active, absent when archived',
        (tester) async {
          // Active
          await tester.pumpApp(
            Scaffold(
              body: ItineraryItemTile(
                suggestion: scheduledSugg,
                currency: 'USD',
                isOrganizer: true,
                isArchived: false,
              ),
            ),
          );

          expect(find.byType(PopupMenuButton<String>), findsOneWidget);

          // Archived
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();

          await tester.pumpApp(
            Scaffold(
              body: ItineraryItemTile(
                suggestion: scheduledSugg,
                currency: 'USD',
                isOrganizer: true,
                isArchived: true,
              ),
            ),
          );

          expect(find.byType(PopupMenuButton<String>), findsNothing);
          expect(find.text('Cable car ride'), findsOneWidget);
        },
      );
    });

    // -------------------------------------------------------------------------
    // 5. Members Tab
    // -------------------------------------------------------------------------
    group('Members Tab', () {
      testWidgets(
        'Leave trip button present for member on active trip, absent on archived trip',
        (tester) async {
          // (a) Active trip
          await tester.pumpApp(
            Scaffold(body: MembersTab(trip: activeTrip)),
            authUserValue: AsyncData(mockMemberUser),
            appUserValue: AsyncData(memAppUser),
            overrides: [
              tripMembersProvider(tripId)
                  .overrideWithValue(AsyncData([orgMember, regularMember])),
              tripAllMembersProvider(tripId)
                  .overrideWithValue(AsyncData([orgMember, regularMember])),
              tripBalancesProvider(tripId).overrideWithValue({}),
              settlementsStreamProvider(tripId)
                  .overrideWithValue(const AsyncData([])),
            ],
          );

          expect(find.text('Leave Trip'), findsOneWidget);

          // (b) Archived trip
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();

          await tester.pumpApp(
            Scaffold(body: MembersTab(trip: archivedTrip)),
            authUserValue: AsyncData(mockMemberUser),
            appUserValue: AsyncData(memAppUser),
            overrides: [
              tripMembersProvider(tripId)
                  .overrideWithValue(AsyncData([orgMember, regularMember])),
              tripAllMembersProvider(tripId)
                  .overrideWithValue(AsyncData([orgMember, regularMember])),
              tripBalancesProvider(tripId).overrideWithValue({}),
              settlementsStreamProvider(tripId)
                  .overrideWithValue(const AsyncData([])),
            ],
          );

          expect(find.text('Leave Trip'), findsNothing);
          expect(find.text('Bob Member'), findsOneWidget);
        },
      );

      testWidgets(
        'Remove member button present for organizer on active trip, absent on archived trip',
        (tester) async {
          // (a) Active trip
          await tester.pumpApp(
            Scaffold(body: MembersTab(trip: activeTrip)),
            authUserValue: AsyncData(mockOrgUser),
            appUserValue: AsyncData(orgAppUser),
            overrides: [
              tripMembersProvider(tripId)
                  .overrideWithValue(AsyncData([orgMember, regularMember])),
              tripAllMembersProvider(tripId)
                  .overrideWithValue(AsyncData([orgMember, regularMember])),
              tripBalancesProvider(tripId).overrideWithValue({}),
              settlementsStreamProvider(tripId)
                  .overrideWithValue(const AsyncData([])),
            ],
          );

          expect(find.text('Remove'), findsOneWidget);

          // (b) Archived trip
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();

          await tester.pumpApp(
            Scaffold(body: MembersTab(trip: archivedTrip)),
            authUserValue: AsyncData(mockOrgUser),
            appUserValue: AsyncData(orgAppUser),
            overrides: [
              tripMembersProvider(tripId)
                  .overrideWithValue(AsyncData([orgMember, regularMember])),
              tripAllMembersProvider(tripId)
                  .overrideWithValue(AsyncData([orgMember, regularMember])),
              tripBalancesProvider(tripId).overrideWithValue({}),
              settlementsStreamProvider(tripId)
                  .overrideWithValue(const AsyncData([])),
            ],
          );

          expect(find.text('Remove'), findsNothing);
          expect(find.text('Bob Member'), findsOneWidget);
        },
      );
    });
  });
}
