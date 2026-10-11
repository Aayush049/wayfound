import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_empty.dart';
import '../../../core/widgets/app_error.dart';
import '../../../core/widgets/app_loading.dart';
import '../../auth/data/auth_provider.dart';
import '../../trips/data/trips_providers.dart';
import '../../trips/domain/member.dart';
import '../../trips/domain/trip.dart';
import '../data/expenses_providers.dart';
import 'balances_view.dart';
import 'expense_card.dart';

enum ExpenseTabSegment { expenses, balances }

class ExpensesTab extends ConsumerStatefulWidget {
  final Trip trip;

  const ExpensesTab({super.key, required this.trip});

  @override
  ConsumerState<ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends ConsumerState<ExpensesTab> {
  ExpenseTabSegment _selectedSegment = ExpenseTabSegment.expenses;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = ref.watch(authUserProvider).asData?.value;
    final currentUid = currentUser?.uid ?? '';

    final expensesAsync = ref.watch(expensesStreamProvider(widget.trip.id));
    final membersAsync = ref.watch(tripAllMembersProvider(widget.trip.id));

    final isArchived = widget.trip.archived;
    final isOrganizer = widget.trip.isOrganizer(currentUid);

    return Scaffold(
      body: Column(
        children: [
          const SizedBox(height: 12),
          // Segmented Control
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ExpenseTabSegment>(
              segments: const [
                ButtonSegment(
                  value: ExpenseTabSegment.expenses,
                  label: Text('Expenses'),
                  icon: Icon(Icons.receipt_outlined),
                ),
                ButtonSegment(
                  value: ExpenseTabSegment.balances,
                  label: Text('Balances'),
                  icon: Icon(Icons.account_balance_outlined),
                ),
              ],
              selected: {_selectedSegment},
              onSelectionChanged: (newSelection) {
                setState(() {
                  _selectedSegment = newSelection.first;
                });
              },
            ),
          ),
          const SizedBox(height: 8),

          // Content body based on active segment
          Expanded(
            child: _selectedSegment == ExpenseTabSegment.balances
                ? BalancesView(trip: widget.trip)
                : expensesAsync.when(
                    loading: () =>
                        const AppLoading(message: 'Loading expenses...'),
                    error: (err, stack) => AppError(
                      message: 'Failed to load expenses: ${err.toString()}',
                      onRetry: () => ref.invalidate(
                        expensesStreamProvider(widget.trip.id),
                      ),
                    ),
                    data: (expenses) {
                      final members = membersAsync.asData?.value ?? <Member>[];

                      if (expenses.isEmpty) {
                        return AppEmpty(
                          title: 'No expenses yet',
                          message:
                              'Record group expenses to easily split costs among members.',
                          icon: Icons.account_balance_wallet_outlined,
                          actionLabel: isArchived ? null : 'Add Expense',
                          onAction: isArchived
                              ? null
                              : () => context.push(
                                  '/trip/${widget.trip.id}/expenses/add',
                                ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.only(top: 8, bottom: 80),
                        itemCount: expenses.length,
                        itemBuilder: (ctx, idx) {
                          final expense = expenses[idx];
                          final canManage =
                              !isArchived &&
                              (expense.createdBy == currentUid || isOrganizer);

                          return ExpenseCard(
                            expense: expense,
                            currency: widget.trip.currency,
                            members: members,
                            canManage: canManage,
                            onEdit: () {
                              context.push(
                                '/trip/${widget.trip.id}/expenses/${expense.id}/edit',
                              );
                            },
                            onDelete: () async {
                              try {
                                final repo = ref.read(
                                  expenseRepositoryProvider,
                                );
                                await repo.deleteExpense(
                                  tripId: widget.trip.id,
                                  expenseId: expense.id,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Expense deleted.'),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Failed to delete expense: ${e.toString()}',
                                      ),
                                      backgroundColor: theme.colorScheme.error,
                                    ),
                                  );
                                }
                              }
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton:
          (!isArchived && _selectedSegment == ExpenseTabSegment.expenses)
          ? FloatingActionButton.extended(
              onPressed: () =>
                  context.push('/trip/${widget.trip.id}/expenses/add'),
              icon: const Icon(Icons.add),
              label: const Text('Add Expense'),
            )
          : null,
    );
  }
}
