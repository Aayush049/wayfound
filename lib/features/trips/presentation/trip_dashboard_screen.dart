import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_empty.dart';
import '../../../core/widgets/app_error.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/centered_content.dart';
import '../../auth/data/auth_provider.dart';
import '../../expenses/presentation/expenses_tab.dart';
import '../../itinerary/presentation/itinerary_tab.dart';
import '../../suggestions/presentation/suggestions_tab.dart';
import '../data/trips_providers.dart';
import '../domain/trip.dart';
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

  Future<void> _handleArchiveTrip(
    BuildContext context,
    WidgetRef ref,
    Trip trip,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive trip'),
        content: const Text(
          'The trip becomes read-only for everyone and this cannot be undone in this version.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Archive trip'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final repo = ref.read(tripRepositoryProvider);
        await repo.archiveTrip(trip.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Trip archived.')));
        }
      } on FirebaseException catch (e) {
        if (context.mounted) {
          final message = e.code == 'permission-denied'
              ? "You can't archive this trip."
              : "Couldn't archive the trip. Please try again.";
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(message)));
        }
      } catch (e) {
        if (context.mounted) {
          final message = e.toString().contains('permission-denied')
              ? "You can't archive this trip."
              : "Couldn't archive the trip. Please try again.";
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(message)));
        }
      }
    }
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

        final isOrganizer = authUser != null && trip.isOrganizer(authUser.uid);

        final screenWidth = MediaQuery.sizeOf(context).width;
        final isCompact = screenWidth < 720;

        Widget bodyContent = Column(
          children: [
            if (trip.archived)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 16,
                ),
                color: theme.colorScheme.surfaceContainerHighest,
                child: Row(
                  children: [
                    Icon(
                      Icons.archive_outlined,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This trip is archived and read-only.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: TabBarView(
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

                  // Tab 2: Expenses Tab (Phase 5)
                  ExpensesTab(trip: trip),

                  // Tab 3: Members Tab (Working!)
                  MembersTab(trip: trip),
                ],
              ),
            ),
          ],
        );

        if (!isCompact) {
          bodyContent = CenteredContent(maxWidth: 1000, child: bodyContent);
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
            actions: [
              if (trip.archived)
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Archived',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              if (isOrganizer && !trip.archived)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'Trip options',
                  onSelected: (value) {
                    if (value == 'archive') {
                      _handleArchiveTrip(context, ref, trip);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem<String>(
                      value: 'archive',
                      child: Text('Archive trip'),
                    ),
                  ],
                ),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: !isCompact,
              tabAlignment: !isCompact ? TabAlignment.start : null,
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
          body: bodyContent,
        );
      },
    );
  }
}
