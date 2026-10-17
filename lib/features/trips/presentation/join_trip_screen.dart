import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../auth/data/auth_provider.dart';
import '../../../core/widgets/centered_content.dart';
import '../data/trips_providers.dart';
import '../domain/join_code.dart';
import '../domain/join_preview.dart';
import '../domain/trip.dart';

class JoinTripScreen extends ConsumerStatefulWidget {
  const JoinTripScreen({super.key});

  @override
  ConsumerState<JoinTripScreen> createState() => _JoinTripScreenState();
}

class _JoinTripScreenState extends ConsumerState<JoinTripScreen> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isSearching = false;
  bool _isJoining = false;

  JoinPreview? _preview;
  Trip? _existingTrip;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _searchCode() async {
    setState(() {
      _errorMessage = null;
      _preview = null;
      _existingTrip = null;
    });

    final normalized = normalizeJoinCode(_codeController.text);
    if (!isValidJoinCode(normalized)) {
      setState(() {
        _errorMessage = 'Invalid join code format. Must be 6 characters (letters and numbers).';
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final repo = ref.read(tripRepositoryProvider);
      final preview = await repo.getJoinPreview(normalized);

      if (preview == null) {
        if (!mounted) return;
        setState(() {
          _isSearching = false;
          _errorMessage = 'Invalid code. No trip found matching "$normalized".';
        });
        return;
      }

      // Check if user is already a member of this trip
      final authUser = ref.read(authUserProvider).asData?.value;
      Trip? existing;
      if (authUser != null) {
        final myTrips = ref.read(myTripsProvider).asData?.value ?? [];
        existing = myTrips.cast<Trip?>().firstWhere(
          (t) => t?.id == preview.tripId,
          orElse: () => null,
        );
      }

      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _preview = preview;
        _existingTrip = existing;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _errorMessage = 'Could not lookup code. Please try again.';
      });
    }
  }

  Future<void> _confirmJoin() async {
    if (_preview == null) return;

    final authUser = ref.read(authUserProvider).asData?.value;
    final appUser = ref.read(appUserProvider).asData?.value;

    if (authUser == null) {
      setState(() {
        _errorMessage = 'You must be signed in to join a trip.';
      });
      return;
    }

    final displayName =
        appUser?.displayName ??
        (authUser.email != null && authUser.email!.isNotEmpty
            ? authUser.email!.split('@').first
            : 'Member');
    final photoUrl = appUser?.photoUrl ?? authUser.photoURL;

    setState(() {
      _isJoining = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(tripRepositoryProvider);
      await repo.joinTrip(
        code: _preview!.code,
        tripId: _preview!.tripId,
        userUid: authUser.uid,
        displayName: displayName,
        photoUrl: photoUrl,
        currentMemberCount: _preview!.memberCount,
      );

      if (!mounted) return;

      // Navigate to trip members tab
      context.go('/trip/${_preview!.tripId}/members');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isJoining = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d, yyyy');

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 720;

    Widget bodyContent = SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter the 6-character code provided by the trip organizer:',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

            // Code input field
            TextFormField(
              controller: _codeController,
              decoration: InputDecoration(
                labelText: 'Join Code',
                hintText: 'e.g. ABC234',
                prefixIcon: const Icon(Icons.qr_code_scanner),
                suffixIcon: IconButton(
                  icon: _isSearching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  onPressed: _isSearching || _isJoining ? null : _searchCode,
                ),
              ),
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              maxLength: 8, // Allow typing with dashes before normalization
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s-]')),
              ],
              onFieldSubmitted: (_) => _searchCode(),
            ),
            const SizedBox(height: 16),

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

            // Trip Preview Card
            if (_preview != null) ...[
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.card_travel,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Trip Preview',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _preview!.tripName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: theme.colorScheme.secondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _preview!.destination,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${dateFormat.format(_preview!.startDate)} - ${dateFormat.format(_preview!.endDate)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _preview!.isFull
                              ? theme.colorScheme.errorContainer
                              : theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_preview!.memberCount} of 15 members',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: _preview!.isFull
                                ? theme.colorScheme.onErrorContainer
                                : theme.colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              if (_existingTrip != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You are already a member of this trip.',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () =>
                      context.go('/trip/${_preview!.tripId}/members'),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Open Trip'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ] else if (_preview!.isFull) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.block,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This trip is full (15 of 15 members).',
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const FilledButton(
                  onPressed: null, // Disabled
                  child: Text('Trip is Full'),
                ),
              ] else ...[
                FilledButton(
                  onPressed: _isJoining ? null : _confirmJoin,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                  child: _isJoining
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Join Trip',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ],
          ],
        ),
      ),
    );

    if (!isCompact) {
      bodyContent = CenteredContent(maxWidth: 560, child: bodyContent);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Join Trip with Code')),
      body: bodyContent,
    );
  }
}
