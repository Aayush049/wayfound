import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfound/features/trips/data/trips_providers.dart';
import 'package:wayfound/features/trips/domain/member.dart';
import 'package:wayfound/features/trips/domain/trip.dart';
import 'package:wayfound/features/trips/presentation/members_tab.dart';

import 'helpers/pump_app.dart';

void main() {
  group('MembersTab', () {
    final trip = Trip(
      id: 'trip-123',
      name: 'Goa Trip',
      destination: 'Goa',
      startDate: DateTime(2026, 8, 1),
      endDate: DateTime(2026, 8, 5),
      currency: 'INR',
      organizerId: 'user-organizer',
      joinCode: 'ABC234',
      memberIds: ['user-organizer', 'user-member'],
      memberCount: 2,
      archived: false,
    );

    final organizer = Member(
      uid: 'user-organizer',
      displayName: 'Alice Organizer',
      role: 'organizer',
      status: 'active',
      joinedAt: DateTime(2026, 8, 1),
    );

    final member = Member(
      uid: 'user-member',
      displayName: 'Bob Member',
      role: 'member',
      status: 'active',
      joinedAt: DateTime(2026, 8, 2),
    );

    testWidgets(
      'renders invite code header and members list with organizer badge',
      (tester) async {
        await tester.pumpApp(
          ProviderScope(
            overrides: [
              tripMembersProvider(trip.id)
                  .overrideWithValue(AsyncData([organizer, member])),
            ],
            child: Scaffold(body: MembersTab(trip: trip)),
          ),
        );

        expect(find.text('Trip Invite Code'), findsOneWidget);
        expect(find.text('ABC234'), findsOneWidget);
        expect(find.text('Copy'), findsOneWidget);
        expect(find.text('2 / 15'), findsOneWidget);

        expect(find.text('Alice Organizer'), findsOneWidget);
        expect(find.text('Organizer'), findsOneWidget); // Organizer badge
        expect(find.text('Bob Member'), findsOneWidget);
      },
    );

    testWidgets('copies invite code to clipboard when Copy is tapped', (
      tester,
    ) async {
      await tester.pumpApp(
        ProviderScope(
          overrides: [
            tripMembersProvider(trip.id)
                .overrideWithValue(AsyncData([organizer, member])),
          ],
          child: Scaffold(body: MembersTab(trip: trip)),
        ),
      );

      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();

      expect(
        find.text('Invite code "ABC234" copied to clipboard!'),
        findsOneWidget,
      );
    });
  });
}
