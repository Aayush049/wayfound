import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/money.dart';
import '../../../core/widgets/app_error.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/centered_content.dart';
import '../../auth/data/auth_provider.dart';
import '../../trips/data/trips_providers.dart';
import '../../trips/domain/currencies.dart';
import '../data/suggestions_providers.dart';
import '../domain/suggestion_category.dart';
import '../domain/suggestion_validators.dart';

class AddEditSuggestionScreen extends ConsumerStatefulWidget {
  final String tripId;
  final String? suggestionId;

  const AddEditSuggestionScreen({
    super.key,
    required this.tripId,
    this.suggestionId,
  });

  bool get isEditing => suggestionId != null && suggestionId!.isNotEmpty;

  @override
  ConsumerState<AddEditSuggestionScreen> createState() =>
      _AddEditSuggestionScreenState();
}

class _AddEditSuggestionScreenState
    extends ConsumerState<AddEditSuggestionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  final _costController = TextEditingController();

  String _selectedCategory = 'other';
  bool _isLoading = false;
  bool _hasInitialData = false;

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    _costController.dispose();
    super.dispose();
  }

  void _prefillData(
    String title,
    String note,
    String category,
    int? estimatedCost,
    String currency,
  ) {
    if (_hasInitialData) return;
    _hasInitialData = true;

    _titleController.text = title;
    _noteController.text = note;
    _selectedCategory = category;

    if (estimatedCost != null) {
      final digits = getMinorUnitDigits(currency);
      if (digits == 0) {
        _costController.text = estimatedCost.toString();
      } else {
        _costController.text = (estimatedCost / 100.0).toStringAsFixed(digits);
      }
    }
  }

  void _returnToSuggestions() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/trip/${widget.tripId}/suggestions');
    }
  }

  Future<void> _submit(String currency) async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authUserProvider).asData?.value;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('You must be signed in.')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final title = _titleController.text.trim();
      final note = _noteController.text.trim();
      final category = _selectedCategory;
      final costInput = _costController.text.trim();
      final estimatedCost = parseMinorUnits(costInput, currency);

      final repository = ref.read(suggestionRepositoryProvider);

      if (widget.isEditing) {
        await repository.updateSuggestion(
          tripId: widget.tripId,
          suggestionId: widget.suggestionId!,
          title: title,
          note: note,
          estimatedCost: estimatedCost,
          category: category,
        );
      } else {
        await repository.createSuggestion(
          tripId: widget.tripId,
          title: title,
          note: note,
          estimatedCost: estimatedCost,
          category: category,
          authorId: user.uid,
        );
      }

      if (mounted) {
        _returnToSuggestions();
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
    final tripAsync = ref.watch(tripProvider(widget.tripId));

    return tripAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(
          title: Text(widget.isEditing ? 'Edit Idea' : 'Add Idea'),
        ),
        body: const AppLoading(message: 'Loading trip details...'),
      ),
      error: (err, stack) => Scaffold(
        appBar: AppBar(
          title: Text(widget.isEditing ? 'Edit Idea' : 'Add Idea'),
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

        // If editing, watch suggestions stream to prefill
        if (widget.isEditing) {
          final suggestionsAsync = ref.watch(
            suggestionsStreamProvider(widget.tripId),
          );

          final suggestions = suggestionsAsync.asData?.value ?? [];
          final suggestion = suggestions.firstWhere(
            (s) => s.id == widget.suggestionId,
            orElse: () => throw Exception('Suggestion not found'),
          );

          _prefillData(
            suggestion.title,
            suggestion.note,
            suggestion.category,
            suggestion.estimatedCost,
            trip.currency,
          );
        }

        final currencySymbol =
            kCurrencyDetails[trip.currency.toUpperCase()]?.symbol ??
            trip.currency;

        final screenWidth = MediaQuery.sizeOf(context).width;
        final isCompact = screenWidth < 720;

        Widget bodyContent = SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title Field
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title *',
                    hintText: 'e.g. Visit Aguada Fort',
                    prefixIcon: Icon(Icons.title),
                  ),
                  maxLength: 80,
                  validator: SuggestionValidators.validateTitle,
                ),
                const SizedBox(height: 16),

                // Category Dropdown
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category *',
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: kSuggestionCategories.map((catKey) {
                    final info = getCategoryInfo(catKey);
                    return DropdownMenuItem<String>(
                      value: catKey,
                      child: Row(
                        children: [
                          Icon(info.icon, size: 20),
                          const SizedBox(width: 8),
                          Text(info.label),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedCategory = val;
                      });
                    }
                  },
                  validator: SuggestionValidators.validateCategory,
                ),
                const SizedBox(height: 16),

                // Estimated Cost Field (Optional)
                TextFormField(
                  controller: _costController,
                  decoration: InputDecoration(
                    labelText: 'Estimated Cost (Optional)',
                    hintText: getMinorUnitDigits(trip.currency) == 0
                        ? 'e.g. 500'
                        : 'e.g. 125.50',
                    prefixText: '$currencySymbol ',
                    prefixIcon: const Icon(Icons.payments_outlined),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (val) => SuggestionValidators.validateCostInput(
                    val,
                    trip.currency,
                  ),
                ),
                const SizedBox(height: 16),

                // Note Field (Optional)
                TextFormField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    labelText: 'Note (Optional)',
                    hintText: 'Add details, link, or notes...',
                    prefixIcon: Icon(Icons.notes),
                  ),
                  maxLines: 4,
                  maxLength: 500,
                  validator: SuggestionValidators.validateNote,
                ),
                const SizedBox(height: 32),

                // Submit Button
                FilledButton(
                  onPressed: _isLoading ? null : () => _submit(trip.currency),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          widget.isEditing ? 'Save Changes' : 'Add Suggestion',
                        ),
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
            title: Text(
              widget.isEditing ? 'Edit Suggestion' : 'Add Suggestion',
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _returnToSuggestions,
            ),
          ),
          body: bodyContent,
        );
      },
    );
  }
}
