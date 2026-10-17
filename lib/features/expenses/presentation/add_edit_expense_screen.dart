import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/money.dart';
import '../../../core/widgets/app_error.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/centered_content.dart';
import '../../auth/data/auth_provider.dart';
import '../../trips/data/trips_providers.dart';
import '../../trips/domain/currencies.dart';
import '../../trips/domain/member.dart';
import '../data/expenses_providers.dart';
import '../domain/expense_validators.dart';
import '../domain/split_logic.dart';

class AddEditExpenseScreen extends ConsumerStatefulWidget {
  final String tripId;
  final String? expenseId;

  const AddEditExpenseScreen({super.key, required this.tripId, this.expenseId});

  bool get isEditing => expenseId != null && expenseId!.isNotEmpty;

  @override
  ConsumerState<AddEditExpenseScreen> createState() =>
      _AddEditExpenseScreenState();
}

class _AddEditExpenseScreenState extends ConsumerState<AddEditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String? _selectedPaidBy;
  final Set<String> _selectedParticipants = {};

  bool _isLoading = false;
  bool _hasInitialData = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _returnToExpenses() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/trip/${widget.tripId}/expenses');
    }
  }

  void _initializeDefaults(List<Member> activeMembers, String currentUid) {
    if (_hasInitialData) return;

    if (!widget.isEditing) {
      _hasInitialData = true;
      // Default paidBy to current user if active member, else first member
      final activeUids = activeMembers.map((m) => m.uid).toList();
      if (activeUids.contains(currentUid)) {
        _selectedPaidBy = currentUid;
      } else if (activeUids.isNotEmpty) {
        _selectedPaidBy = activeUids.first;
      }
      // Default all active members checked
      _selectedParticipants.addAll(activeUids);
    }
  }

  void _prefillData(
    String description,
    int amount,
    String paidBy,
    List<String> participantIds,
    DateTime date,
    String currency,
    List<Member> activeMembers,
  ) {
    if (_hasInitialData) return;
    _hasInitialData = true;

    _descriptionController.text = description;

    final digits = getMinorUnitDigits(currency);
    if (digits == 0) {
      _amountController.text = amount.toString();
    } else {
      _amountController.text = (amount / 100.0).toStringAsFixed(digits);
    }

    _selectedPaidBy = paidBy;
    _selectedDate = date;

    final activeUids = activeMembers.map((m) => m.uid).toSet();
    _selectedParticipants.addAll(
      participantIds.where((uid) => activeUids.contains(uid)),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submit(String currency, List<String> activeMemberUids) async {
    if (!_formKey.currentState!.validate()) return;

    final (amountInMinorUnits, parseErr) = tryParseMinorUnits(
      _amountController.text.trim(),
      currency,
    );

    final amountErr =
        parseErr ?? ExpenseValidators.validateAmount(amountInMinorUnits);
    if (amountErr != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(amountErr),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final paidByErr = ExpenseValidators.validatePaidBy(
      _selectedPaidBy,
      activeMemberUids,
    );
    if (paidByErr != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(paidByErr),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final participantList = _selectedParticipants.toList();
    final partsErr = ExpenseValidators.validateParticipants(
      participantList,
      activeMemberUids,
    );
    if (partsErr != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(partsErr),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final currentUser = ref.read(authUserProvider).asData?.value;
    if (currentUser == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('You must be signed in.')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final repository = ref.read(expenseRepositoryProvider);

      if (widget.isEditing) {
        await repository.updateExpense(
          tripId: widget.tripId,
          expenseId: widget.expenseId!,
          amount: amountInMinorUnits!,
          description: _descriptionController.text.trim(),
          paidBy: _selectedPaidBy!,
          participantIds: participantList,
          date: _selectedDate,
        );
      } else {
        await repository.createExpense(
          tripId: widget.tripId,
          amount: amountInMinorUnits!,
          description: _descriptionController.text.trim(),
          paidBy: _selectedPaidBy!,
          participantIds: participantList,
          createdBy: currentUser.uid,
          date: _selectedDate,
        );
      }

      if (mounted) {
        _returnToExpenses();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tripAsync = ref.watch(tripProvider(widget.tripId));
    final membersAsync = ref.watch(tripMembersProvider(widget.tripId));
    final currentUser = ref.watch(authUserProvider).asData?.value;
    final currentUid = currentUser?.uid ?? '';

    return tripAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(
          title: Text(widget.isEditing ? 'Edit Expense' : 'Add Expense'),
        ),
        body: const AppLoading(message: 'Loading trip details...'),
      ),
      error: (err, stack) => Scaffold(
        appBar: AppBar(
          title: Text(widget.isEditing ? 'Edit Expense' : 'Add Expense'),
        ),
        body: AppError(
          message: 'Failed to load trip: ${err.toString()}',
          onRetry: () => ref.invalidate(tripProvider(widget.tripId)),
        ),
      ),
      data: (trip) {
        if (trip == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Trip Not Found')),
            body: const Center(child: Text('Trip does not exist.')),
          );
        }

        final activeMembers = membersAsync.asData?.value ?? <Member>[];
        final activeMemberUids = activeMembers.map((m) => m.uid).toList();
        final memberMap = {for (final m in activeMembers) m.uid: m.displayName};

        _initializeDefaults(activeMembers, currentUid);

        // If editing, watch expenses stream to prefill
        if (widget.isEditing) {
          final expensesAsync = ref.watch(
            expensesStreamProvider(widget.tripId),
          );
          final expenses = expensesAsync.asData?.value ?? [];
          final expense = expenses.firstWhere(
            (e) => e.id == widget.expenseId,
            orElse: () => throw Exception('Expense not found'),
          );

          _prefillData(
            expense.description,
            expense.amount,
            expense.paidBy,
            expense.participantIds,
            expense.date,
            trip.currency,
            activeMembers,
          );
        }

        final currencySymbol =
            kCurrencyDetails[trip.currency.toUpperCase()]?.symbol ??
            trip.currency;

        // Compute live split preview safely
        final (parsedAmount, _) = tryParseMinorUnits(
          _amountController.text.trim(),
          trip.currency,
        );
        final liveShares = (parsedAmount != null && parsedAmount > 0)
            ? splitEqually(parsedAmount, _selectedParticipants.toList())
            : const <String, int>{};

        final allSelected =
            activeMembers.isNotEmpty &&
            _selectedParticipants.length == activeMembers.length;

        final screenWidth = MediaQuery.sizeOf(context).width;
        final isCompact = screenWidth < 720;

        Widget bodyContent = SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Description Field
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description *',
                    hintText: 'e.g. Dinner at Beach Shack',
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                  maxLength: 100,
                  validator: ExpenseValidators.validateDescription,
                ),
                const SizedBox(height: 16),

                // Amount Field
                TextFormField(
                  controller: _amountController,
                  decoration: InputDecoration(
                    labelText: 'Amount *',
                    hintText: getMinorUnitDigits(trip.currency) == 0
                        ? 'e.g. 1500'
                        : 'e.g. 45.50',
                    prefixText: '$currencySymbol ',
                    prefixIcon: const Icon(Icons.payments_outlined),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (val) {
                    setState(() {}); // Trigger live share preview rebuild
                    _formKey.currentState?.validate();
                  },
                  validator: (val) =>
                      ExpenseValidators.validateAmountInput(val, trip.currency),
                ),
                const SizedBox(height: 16),

                // Date Picker Button
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date *',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(
                      DateFormat.yMMMd().format(_selectedDate),
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Paid By Dropdown
                DropdownButtonFormField<String>(
                  initialValue: _selectedPaidBy,
                  decoration: const InputDecoration(
                    labelText: 'Paid By *',
                    prefixIcon: Icon(Icons.person_outlined),
                  ),
                  items: activeMembers.map((member) {
                    return DropdownMenuItem<String>(
                      value: member.uid,
                      child: Text(
                        member.uid == currentUid
                            ? '${member.displayName} (You)'
                            : member.displayName,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedPaidBy = val;
                      });
                    }
                  },
                  validator: (val) =>
                      ExpenseValidators.validatePaidBy(val, activeMemberUids),
                ),
                const SizedBox(height: 24),

                // Participants Header & Select All Checkbox
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Split Among (${_selectedParticipants.length}/${activeMembers.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: allSelected,
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                _selectedParticipants.addAll(activeMemberUids);
                              } else {
                                _selectedParticipants.clear();
                              }
                            });
                          },
                        ),
                        const Text('Select all'),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Participants Checkbox List
                Card(
                  child: Column(
                    children: activeMembers.map((member) {
                      final isChecked = _selectedParticipants.contains(
                        member.uid,
                      );
                      return CheckboxListTile(
                        value: isChecked,
                        title: Text(
                          member.uid == currentUid
                              ? '${member.displayName} (You)'
                              : member.displayName,
                        ),
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedParticipants.add(member.uid);
                            } else {
                              _selectedParticipants.remove(member.uid);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),

                // Live Share Preview Card (hidden when amount is invalid or zero/empty)
                if (_selectedParticipants.isNotEmpty &&
                    parsedAmount != null &&
                    parsedAmount > 0) ...[
                  Card(
                    color: theme.colorScheme.surfaceContainerHigh,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Live Share Preview',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ..._selectedParticipants.map((pUid) {
                            final name = memberMap[pUid] ?? pUid;
                            final share = liveShares[pUid] ?? 0;
                            final formattedShare = formatMinorUnits(
                              share,
                              trip.currency,
                            );
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: theme.textTheme.bodyMedium,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    formattedShare,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Submit Button
                FilledButton(
                  onPressed: _isLoading
                      ? null
                      : () => _submit(trip.currency, activeMemberUids),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(widget.isEditing ? 'Save Changes' : 'Add Expense'),
                ),
              ],
            ),
          ),
        );

        if (!isCompact) {
          bodyContent = CenteredContent(maxWidth: 560, child: bodyContent);
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.isEditing ? 'Edit Expense' : 'Add Expense'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _returnToExpenses,
            ),
          ),
          body: bodyContent,
        );
      },
    );
  }
}
