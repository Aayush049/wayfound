import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_empty.dart';
import '../../../core/widgets/app_error.dart';
import '../../../core/widgets/app_loading.dart';
import '../../auth/data/auth_provider.dart';
import '../../itinerary/presentation/itinerary_tab.dart';
import '../../suggestions/presentation/suggestions_tab.dart';
import '../data/trips_providers.dart';
import 'members_tab.dart';

class TripDashboardScreen extends ConsumerStatefulWidget {
  final String tripId;
  final String activeTab;

  const TripDashboardScreen({
    super.key,
    required this.tripId,
    this.activeTab = 'members',
  });

  @override
  ConsumerState<TripDashboardScreen> createState() =>
      _TripDashboardScreenState();
}

class _TripDashboardScreenState extends ConsumerState<TripDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const List<String> _tabPaths = [
    'suggestions',
    'itinerary',
    'expenses',
    'members',
  ];

  @override
  void initState() {
    super.initState();
    final initialIndex = _tabPaths.indexOf(widget.activeTab);
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: initialIndex >= 0 ? initialIndex : 3,
    );

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      final newTab = _tabPaths[_tabController.index];
      if (newTab != widget.activeTab) {
        context.go('/trip/${widget.tripId}/$newTab');
      }
    });
  }

  @override
  void didUpdateWidget(covariant TripDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeTab != widget.activeTab) {
      final index = _tabPaths.indexOf(widget.activeTab);
      if (index >= 0 && index != _tabController.index) {
        _tabController.animateTo(index);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tripAsync = ref.watch(tripProvider(widget.tripId));
    final authUser = ref.watch(authUserProvider).asData?.value;

    return tripAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Trip')),
        body: const AppLoading(message: 'Loading trip details...'),
      ),
      error: (err, stack) => Scaffold(
        appBar: AppBar(title: const Text('Trip Error')),
        body: AppError(
          message: 'Unable to access trip: ${err.toString()}',
          onRetry: () => ref.invalidate(tripProvider(widget.tripId)),
        ),
      ),
      data: (trip) {
        // Not found or not a member
        if (trip == null ||
            (authUser != null && !trip.isMember(authUser.uid))) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Trip Not Found'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/home'),
              ),
            ),
            body: AppEmpty(
              title: 'No access to trip',
              message:
                  'This trip does not exist or you are not a member of it.',
              icon: Icons.lock_outline,
              actionLabel: 'Return to My Trips',
              onAction: () => context.go('/home'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  trip.destination,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/home'),
            ),
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.lightbulb_outline), text: 'Suggestions'),
                Tab(icon: Icon(Icons.calendar_today), text: 'Itinerary'),
                Tab(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  text: 'Expenses',
                ),
                Tab(icon: Icon(Icons.people_outline), text: 'Members'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // Tab 0: Suggestions Tab (Phase 3)
              SuggestionsTab(trip: trip),

              // Tab 1: Itinerary Tab (Phase 4)
              ItineraryTab(
                tripId: trip.id,
                startDate: trip.startDate,
                endDate: trip.endDate,
                currency: trip.currency,
                isOrganizer: trip.isOrganizer(authUser?.uid ?? ''),
                isArchived: trip.archived,
              ),

              // Tab 2: Expenses Placeholder TEMP(phase-5)
              const AppEmpty(
                title: 'Expenses Coming Soon',
                message: 'TEMP(phase-5): Log group expenses and see balances in Phase 5.',
                icon: Icons.account_balance_wallet_outlined,
              ),

              // Tab 3: Members Tab (Working!)
              MembersTab(trip: trip),
            ],
          ),
        );
      },
    );
  }
}
