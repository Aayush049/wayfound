import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../auth/data/auth_provider.dart';
import '../data/trips_providers.dart';
import '../domain/currencies.dart';
import '../domain/trip_validators.dart';

class CreateTripScreen extends ConsumerStatefulWidget {
  const CreateTripScreen({super.key});

  @override
  ConsumerState<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends ConsumerState<CreateTripScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _destinationController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedCurrency;

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);
    final lastDate = DateTime(now.year + 5);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : DateTimeRange(
              start: firstDate,
              end: firstDate.add(const Duration(days: 3)),
            ),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Future<void> _submit() async {
    setState(() {
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) return;

    final dateErr = validateDateRange(_startDate, _endDate);
    if (dateErr != null) {
      setState(() {
        _errorMessage = dateErr;
      });
      return;
    }

    final currencyErr = validateCurrencySelection(_selectedCurrency);
    if (currencyErr != null) {
      setState(() {
        _errorMessage = currencyErr;
      });
      return;
    }

    final appUser = ref.read(appUserProvider).asData?.value;
    final authUser = ref.read(authUserProvider).asData?.value;

    if (authUser == null) {
      setState(() {
        _errorMessage = 'You must be signed in to create a trip.';
      });
      return;
    }

    final displayName =
        appUser?.displayName ??
        (authUser.email != null && authUser.email!.isNotEmpty
            ? authUser.email!.split('@').first
            : 'Organizer');
    final photoUrl = appUser?.photoUrl ?? authUser.photoURL;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final repo = ref.read(tripRepositoryProvider);
      final result = await repo.createTrip(
        name: _nameController.text.trim(),
        destination: _destinationController.text.trim(),
        startDate: _startDate!,
        endDate: _endDate!,
        currency: _selectedCurrency!,
        userUid: authUser.uid,
        displayName: displayName,
        photoUrl: photoUrl,
      );

      if (!mounted) return;

      // Navigate to trip members tab
      context.go('/trip/${result.tripId}/members');

      // Show invite code dialog once
      _showInviteCodeDialog(context, result.joinCode);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _showInviteCodeDialog(BuildContext context, String code) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Trip Created!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Share this 6-character invite code with your friends to let them join your trip:',
            ),
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(ctx).colorScheme.primary.withValues(alpha: 0.5),
                  ),
                ),
                child: SelectableText(
                  code,
                  style: Theme.of(ctx).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                    color: Theme.of(ctx).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d, yyyy');

    final dateRangeText = _startDate != null && _endDate != null
        ? '${dateFormat.format(_startDate!)} - ${dateFormat.format(_endDate!)}'
        : 'Select date range';

    return Scaffold(
      appBar: AppBar(title: const Text('Create New Trip')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Trip Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Trip Name *',
                  hintText: 'e.g. Summer in Goa',
                  prefixIcon: Icon(Icons.flight_takeoff),
                ),
                textCapitalization: TextCapitalization.words,
                validator: validateTripName,
              ),
              const SizedBox(height: 16),

              // Destination
              TextFormField(
                controller: _destinationController,
                decoration: const InputDecoration(
                  labelText: 'Destination *',
                  hintText: 'e.g. Goa, India',
                  prefixIcon: Icon(Icons.location_on),
                ),
                textCapitalization: TextCapitalization.words,
                validator: validateDestination,
              ),
              const SizedBox(height: 16),

              // Date Range Picker Button
              InkWell(
                onTap: _isSubmitting ? null : _pickDateRange,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Trip Dates *',
                    prefixIcon: Icon(Icons.date_range),
                  ),
                  child: Text(
                    dateRangeText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _startDate != null
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Currency Dropdown (Required selection, no default!)
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _selectedCurrency,
                decoration: const InputDecoration(
                  labelText: 'Currency *',
                  hintText: 'Select currency (immutable after creation)',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                items: kSupportedCurrencies.map((code) {
                  return DropdownMenuItem<String>(
                    value: code,
                    child: Text(code),
                  );
                }).toList(),
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        setState(() {
                          _selectedCurrency = value;
                        });
                      },
                validator: validateCurrencySelection,
              ),
              const SizedBox(height: 32),

              // Submit Button
              FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Create Trip',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
