import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/app_empty.dart';
import '../../../core/widgets/app_error.dart';
import '../../../core/widgets/app_loading.dart';
import '../../auth/data/auth_provider.dart';
import '../../expenses/data/expenses_providers.dart';
import '../../settlements/data/settlements_providers.dart';
import '../../settlements/domain/leave_eligibility.dart';
import '../../settlements/domain/settlement.dart';
import '../data/trips_providers.dart';
import '../domain/trip.dart';

class MembersTab extends ConsumerWidget {
  final Trip trip;

  const MembersTab({super.key, required this.trip});

  void _copyInviteCode(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Invite code "$code" copied to clipboard!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleLeaveTrip(
    BuildContext context,
    WidgetRef ref,
    String currentUid,
    Map<String, int> balances,
    List<Settlement> settlements,
  ) async {
    final eligibility = checkLeaveEligibility(
      uid: currentUid,
      organizerId: trip.organizerId,
      balances: balances,
      settlements: settlements,
      currencyCode: trip.currency,
    );

    if (!eligibility.allowed) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Cannot Leave Trip'),
            content: Text(eligibility.reason ?? 'Eligibility check failed.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Trip'),
        content: const Text(
          'Are you sure you want to leave this trip? You won\'t be able to rejoin this trip in this version. Your past expenses stay in the balances, marked (left).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final repo = ref.read(tripRepositoryProvider);
        await repo.leaveTrip(
          tripId: trip.id,
          userUid: currentUid,
          currentMemberIds: trip.memberIds,
        );
        if (context.mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You have left the trip.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to leave trip: $e')));
        }
      }
    }
  }

  Future<void> _handleRemoveMember(
    BuildContext context,
    WidgetRef ref,
    String targetUid,
    String targetName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text(
          'Are you sure you want to remove $targetName from this trip?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final repo = ref.read(tripRepositoryProvider);
        await repo.removeMember(
          tripId: trip.id,
          targetUid: targetUid,
          currentMemberIds: trip.memberIds,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$targetName has been removed.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to remove member: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentUser = ref.watch(authUserProvider).asData?.value;
    final currentUid = currentUser?.uid ?? '';
    final isOrganizer = trip.organizerId == currentUid;

    final membersAsync = ref.watch(tripMembersProvider(trip.id));
    final balances = ref.watch(tripBalancesProvider(trip.id));
    final settlementsAsync = ref.watch(settlementsStreamProvider(trip.id));
    final settlements = settlementsAsync.asData?.value ?? const <Settlement>[];

    final dateFormat = DateFormat('MMM d, yyyy');

    return Column(
      children: [
        // Invite Code Header Box (Visible to all members)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16.0),
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trip Invite Code',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      trip.joinCode,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => _copyInviteCode(context, trip.joinCode),
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy'),
              ),
            ],
          ),
        ),

        // Members List Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Members',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${trip.memberCount} / 15',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        // Members List
        Expanded(
          child: membersAsync.when(
            loading: () => const AppLoading(message: 'Loading members...'),
            error: (err, stack) => AppError(
              message: 'Failed to load members: ${err.toString()}',
              onRetry: () => ref.invalidate(tripMembersProvider(trip.id)),
            ),
            data: (members) {
              if (members.isEmpty) {
                return const AppEmpty(
                  title: 'No active members',
                  message: 'Members will appear here once they join.',
                  icon: Icons.people_outline,
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: members.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final member = members[index];
                  final displayName = member.displayName.isNotEmpty
                      ? member.displayName
                      : 'Member';
                  final initial = displayName[0].toUpperCase();

                  final joinedStr = member.joinedAt != null
                      ? 'Joined ${dateFormat.format(member.joinedAt!)}'
                      : 'Active';

                  final canRemove =
                      isOrganizer &&
                      !member.isOrganizer &&
                      member.uid != currentUid &&
                      !trip.archived;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundColor: member.isOrganizer
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.secondaryContainer,
                      backgroundImage:
                          member.photoUrl != null && member.photoUrl!.isNotEmpty
                          ? NetworkImage(member.photoUrl!)
                          : null,
                      child:
                          (member.photoUrl == null || member.photoUrl!.isEmpty)
                          ? Text(
                              initial,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: member.isOrganizer
                                    ? theme.colorScheme.onPrimaryContainer
                                    : theme.colorScheme.onSecondaryContainer,
                              ),
                            )
                          : null,
                    ),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (member.isOrganizer) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Organizer',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      joinedStr,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: canRemove
                        ? TextButton(
                            onPressed: () => _handleRemoveMember(
                              context,
                              ref,
                              member.uid,
                              displayName,
                            ),
                            child: Text(
                              'Remove',
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          )
                        : null,
                  );
                },
              );
            },
          ),
        ),

        // Leave Trip Button for non-organizers
        if (!isOrganizer && !trip.archived)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(color: theme.colorScheme.error),
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () => _handleLeaveTrip(
                context,
                ref,
                currentUid,
                balances,
                settlements,
              ),
              icon: const Icon(Icons.exit_to_app),
              label: const Text('Leave Trip'),
            ),
          ),
      ],
    );
  }
}
