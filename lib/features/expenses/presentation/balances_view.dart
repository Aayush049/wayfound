import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money.dart';
import '../../auth/data/auth_provider.dart';
import '../../trips/data/trips_providers.dart';
import '../../trips/domain/member.dart';
import '../../trips/domain/trip.dart';
import '../data/expenses_providers.dart';

class BalancesView extends ConsumerWidget {
  final Trip trip;

  const BalancesView({super.key, required this.trip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentUser = ref.watch(authUserProvider).asData?.value;
    final currentUid = currentUser?.uid ?? '';

    final membersAsync = ref.watch(tripMembersProvider(trip.id));
    final balances = ref.watch(tripBalancesProvider(trip.id));
    final suggestedPayments = ref.watch(suggestedPaymentsProvider(trip.id));
    final totalSpent = ref.watch(totalTripSpentProvider(trip.id));

    final members = membersAsync.asData?.value ?? <Member>[];
    final memberMap = {for (final m in members) m.uid: m.displayName};

    final myBalance = balances[currentUid] ?? 0;
    final formattedTotalSpent = formatMinorUnits(totalSpent, trip.currency);
    final formattedMyBalance = formatSignedMinorUnits(myBalance, trip.currency);

    // Determine colors & label for user's net balance
    final String myStatusLabel;
    final Color myColor;
    if (myBalance > 0) {
      myStatusLabel = 'You are owed';
      myColor = theme.colorScheme.primary;
    } else if (myBalance < 0) {
      myStatusLabel = 'You owe';
      myColor = theme.colorScheme.error;
    } else {
      myStatusLabel = 'All settled';
      myColor = theme.colorScheme.onSurfaceVariant;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Total Spent & Your Balance Header Cards
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Trip Spent',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          formattedTotalSpent,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Balance',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          formattedMyBalance,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: myColor,
                          ),
                        ),
                        Text(
                          myStatusLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: myColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Member Balances Section
          Text(
            'Member Balances',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: members.length,
              separatorBuilder: (ctx, idx) => const Divider(height: 1),
              itemBuilder: (ctx, idx) {
                final member = members[idx];
                final netBalance = balances[member.uid] ?? 0;
                final formattedAmount = formatSignedMinorUnits(
                  netBalance,
                  trip.currency,
                );

                final String statusText;
                final Color statusColor;

                if (netBalance > 0) {
                  statusText = 'is owed';
                  statusColor = theme.colorScheme.primary;
                } else if (netBalance < 0) {
                  statusText = 'owes';
                  statusColor = theme.colorScheme.error;
                } else {
                  statusText = 'settled';
                  statusColor = theme.colorScheme.onSurfaceVariant;
                }

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    child: Text(
                      member.displayName.isNotEmpty
                          ? member.displayName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: theme.colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    member.uid == currentUid
                        ? '${member.displayName} (You)'
                        : member.displayName,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formattedAmount,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                      Text(
                        statusText,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Suggested Payments Section
          Text(
            'Suggested Payments',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (suggestedPayments.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 48,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'All Settled!',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Everyone is at zero net balance. No payments needed.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: suggestedPayments.length,
                separatorBuilder: (ctx, idx) => const Divider(height: 1),
                itemBuilder: (ctx, idx) {
                  final p = suggestedPayments[idx];
                  final fromName = memberMap[p.fromUid] ?? p.fromUid;
                  final toName = memberMap[p.toUid] ?? p.toUid;
                  final formattedPayment = formatMinorUnits(
                    p.amount,
                    trip.currency,
                  );

                  return ListTile(
                    leading: Icon(
                      Icons.swap_horiz,
                      color: theme.colorScheme.primary,
                    ),
                    title: RichText(
                      text: TextSpan(
                        style: theme.textTheme.bodyMedium,
                        children: [
                          TextSpan(
                            text: fromName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const TextSpan(text: ' pays '),
                          TextSpan(
                            text: toName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    trailing: Text(
                      formattedPayment,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
