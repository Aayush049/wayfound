import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/money.dart';
import '../../trips/domain/member.dart';
import '../domain/expense.dart';
import '../domain/split_logic.dart';

class ExpenseSplitSheet extends StatelessWidget {
  final Expense expense;
  final List<Member> members;
  final String currency;

  const ExpenseSplitSheet({
    super.key,
    required this.expense,
    required this.members,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formattedTotal = formatMinorUnits(expense.amount, currency);
    final shares = splitEqually(expense.amount, expense.participantIds);
    final dateStr = DateFormat.yMMMd().format(expense.date);

    final memberMap = {for (final m in members) m.uid: m.displayName};
    final payerName = memberMap[expense.paidBy] ?? expense.paidBy;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            expense.description,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$formattedTotal · Paid by $payerName on $dateStr',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          Text(
            'Split Details (${expense.participantIds.length} participants)',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: expense.participantIds.length,
              separatorBuilder: (ctx, idx) => const Divider(height: 1),
              itemBuilder: (ctx, idx) {
                final pUid = expense.participantIds[idx];
                final name = memberMap[pUid] ?? pUid;
                final shareAmount = shares[pUid] ?? 0;
                final formattedShare = formatMinorUnits(shareAmount, currency);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          name,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        formattedShare,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
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
