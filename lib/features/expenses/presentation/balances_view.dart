import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money.dart';
import '../../auth/data/auth_provider.dart';
import '../../settlements/data/settlement_repository.dart';
import '../../settlements/data/settlements_providers.dart';
import '../../settlements/domain/settlement.dart';
import '../../settlements/domain/settlement_validators.dart';
import '../../trips/data/trips_providers.dart';
import '../../trips/domain/currencies.dart';
import '../../trips/domain/member.dart';
import '../../trips/domain/trip.dart';
import '../data/expenses_providers.dart';
import '../domain/balance_calculator.dart';

class BalancesView extends ConsumerWidget {
  final Trip trip;

  const BalancesView({super.key, required this.trip});

  void _showMarkAsPaidSheet(
    BuildContext context,
    SuggestedPayment payment,
    String receiverName,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => MarkAsPaidSheet(
        trip: trip,
        payment: payment,
        receiverName: receiverName,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentUser = ref.watch(authUserProvider).asData?.value;
    final currentUid = currentUser?.uid ?? '';

    final membersAsync = ref.watch(tripAllMembersProvider(trip.id));
    final balances = ref.watch(tripBalancesProvider(trip.id));
    final suggestedPayments = ref.watch(suggestedPaymentsProvider(trip.id));
    final totalSpent = ref.watch(totalTripSpentProvider(trip.id));
    final settlementsAsync = ref.watch(settlementsStreamProvider(trip.id));

    final members = membersAsync.asData?.value ?? <Member>[];
    final memberMap = {for (final m in members) m.uid: m.displayName};
    final settlements = settlementsAsync.asData?.value ?? <Settlement>[];

    final myBalance = balances[currentUid] ?? 0;
    final formattedTotalSpent = formatMinorUnits(totalSpent, trip.currency);
    final formattedMyBalance = formatSignedMinorUnits(myBalance, trip.currency);

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

                final nameDisplay = member.uid == currentUid
                    ? '${member.displayName} (You)'
                    : member.displayName;
                final labelDisplay = member.isActive
                    ? nameDisplay
                    : '$nameDisplay (left)';

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
                    labelDisplay,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: member.isActive
                          ? null
                          : theme.colorScheme.onSurfaceVariant,
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
                  final isMyPayment = p.fromUid == currentUid;

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
                    subtitle: Text(formattedPayment),
                    trailing: isMyPayment && !trip.archived
                        ? FilledButton.tonal(
                            onPressed: () => _showMarkAsPaidSheet(
                              context,
                              p,
                              toName,
                            ),
                            child: const Text('Mark as Paid'),
                          )
                        : Text(
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
          const SizedBox(height: 24),

          // Payments History / Pending Section
          Text(
            'Payments History',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (settlements.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No payments recorded yet.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: settlements.length,
                separatorBuilder: (ctx, idx) => const Divider(height: 1),
                itemBuilder: (ctx, idx) {
                  final s = settlements[idx];
                  final fromName = memberMap[s.fromUid] ?? s.fromUid;
                  final toName = memberMap[s.toUid] ?? s.toUid;
                  final formattedAmount = formatMinorUnits(s.amount, trip.currency);

                  final String statusLabel;
                  final Color statusColor;
                  final Color statusBg;

                  switch (s.status) {
                    case SettlementStatus.confirmed:
                      statusLabel = 'Confirmed';
                      statusColor = theme.colorScheme.onSecondaryContainer;
                      statusBg = theme.colorScheme.secondaryContainer;
                      break;
                    case SettlementStatus.rejected:
                      statusLabel = 'Rejected';
                      statusColor = theme.colorScheme.onErrorContainer;
                      statusBg = theme.colorScheme.errorContainer;
                      break;
                    case SettlementStatus.pending:
                      statusLabel = 'Awaiting confirmation';
                      statusColor = theme.colorScheme.onErrorContainer;
                      statusBg = theme.colorScheme.tertiaryContainer;
                      break;
                  }

                  final isMyPayment = s.fromUid == currentUid;
                  final isMyReceiver = s.toUid == currentUid;
                  final isOrganizer = trip.organizerId == currentUid && s.fromUid != currentUid;
                  final canActOnPending = s.status == SettlementStatus.pending && !trip.archived;

                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '$fromName paid $toName',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              formattedAmount,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: statusBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                statusLabel,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (canActOnPending && isMyPayment)
                              TextButton.icon(
                                onPressed: () async {
                                  await ref
                                      .read(settlementRepositoryProvider)
                                      .cancelPending(
                                        tripId: trip.id,
                                        settlementId: s.id,
                                      );
                                },
                                icon: const Icon(Icons.cancel_outlined, size: 16),
                                label: const Text('Cancel'),
                              ),
                            if (canActOnPending && (isMyReceiver || isOrganizer)) ...[
                              TextButton(
                                onPressed: () async {
                                  await ref
                                      .read(settlementRepositoryProvider)
                                      .resolve(
                                        tripId: trip.id,
                                        settlementId: s.id,
                                        confirmed: false,
                                      );
                                },
                                child: Text(
                                  'Reject',
                                  style: TextStyle(color: theme.colorScheme.error),
                                ),
                              ),
                              const SizedBox(width: 4),
                              FilledButton(
                                onPressed: () async {
                                  await ref
                                      .read(settlementRepositoryProvider)
                                      .resolve(
                                        tripId: trip.id,
                                        settlementId: s.id,
                                        confirmed: true,
                                      );
                                },
                                child: const Text('Confirm'),
                              ),
                            ],
                          ],
                        ),
                      ],
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

class MarkAsPaidSheet extends ConsumerStatefulWidget {
  final Trip trip;
  final SuggestedPayment payment;
  final String receiverName;

  const MarkAsPaidSheet({
    super.key,
    required this.trip,
    required this.payment,
    required this.receiverName,
  });

  @override
  ConsumerState<MarkAsPaidSheet> createState() => _MarkAsPaidSheetState();
}

class _MarkAsPaidSheetState extends ConsumerState<MarkAsPaidSheet> {
  late final TextEditingController _amountController;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final digits = getMinorUnitDigits(widget.trip.currency);
    final major = digits == 0
        ? widget.payment.amount.toString()
        : (widget.payment.amount / 100.0).toStringAsFixed(digits);
    _amountController = TextEditingController(text: major);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final err = validateSettlementAmount(
      _amountController.text,
      widget.trip.currency,
      widget.payment.amount,
    );
    if (err != null) {
      setState(() => _errorMessage = err);
      return;
    }

    final (parsedVal, parseErr) = tryParseMinorUnits(
      _amountController.text,
      widget.trip.currency,
    );
    if (parseErr != null || parsedVal == null) {
      setState(() => _errorMessage = parseErr ?? 'Invalid amount');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      final repo = ref.read(settlementRepositoryProvider);
      await repo.createPending(
        tripId: widget.trip.id,
        fromUid: widget.payment.fromUid,
        toUid: widget.payment.toUid,
        amount: parsedVal,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment marked as paid (awaiting confirmation).'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Mark Payment as Paid',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Recording payment to ${widget.receiverName}. Suggested amount: ${formatMinorUnits(widget.payment.amount, widget.trip.currency)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount (${widget.trip.currency})',
              errorText: _errorMessage,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isLoading ? null : _submit,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit Payment'),
          ),
        ],
      ),
    );
  }
}
