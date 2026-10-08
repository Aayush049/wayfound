import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/money.dart';
import '../../trips/domain/member.dart';
import '../data/suggestions_providers.dart';
import '../domain/suggestion.dart';
import '../domain/suggestion_category.dart';
import '../domain/vote.dart';
import 'vote_buttons.dart';

class SuggestionCard extends ConsumerStatefulWidget {
  final Suggestion suggestion;
  final String currency;
  final String currentUserId;
  final bool isOrganizer;
  final List<Member> members;

  const SuggestionCard({
    super.key,
    required this.suggestion,
    required this.currency,
    required this.currentUserId,
    required this.isOrganizer,
    required this.members,
  });

  @override
  ConsumerState<SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends ConsumerState<SuggestionCard> {
  bool _isVoteInFlight = false;

  bool get _canEditOrDelete =>
      widget.suggestion.authorId == widget.currentUserId || widget.isOrganizer;

  String get _authorName {
    final member = widget.members.firstWhere(
      (m) => m.uid == widget.suggestion.authorId,
      orElse: () => Member(
        uid: widget.suggestion.authorId,
        displayName: 'Former member',
        role: 'member',
        status: 'left',
        joinedAt: DateTime.now(),
      ),
    );
    return member.displayName.isEmpty ? 'Former member' : member.displayName;
  }

  Future<void> _handleVote(int targetVoteValue) async {
    if (_isVoteInFlight) return;

    setState(() {
      _isVoteInFlight = true;
    });

    try {
      final repo = ref.read(suggestionRepositoryProvider);
      await repo.castVote(
        tripId: widget.suggestion.tripId,
        suggestionId: widget.suggestion.id,
        userUid: widget.currentUserId,
        targetVoteValue: targetVoteValue,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to vote: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVoteInFlight = false;
        });
      }
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Suggestion'),
        content: const Text(
          'Are you sure you want to delete this suggestion? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final repo = ref.read(suggestionRepositoryProvider);
        await repo.deleteSuggestion(
          tripId: widget.suggestion.tripId,
          suggestionId: widget.suggestion.id,
        );
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Suggestion deleted')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete: ${e.toString()}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryInfo = getCategoryInfo(widget.suggestion.category);

    final myVoteAsync = ref.watch(
      myVoteStreamProvider((
        tripId: widget.suggestion.tripId,
        suggestionId: widget.suggestion.id,
        userUid: widget.currentUserId,
      )),
    );
    final Vote? myVote = myVoteAsync.asData?.value;

    final costText = widget.suggestion.estimatedCost != null
        ? formatMinorUnits(widget.suggestion.estimatedCost!, widget.currency)
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Category chip, Score badge & Overflow menu
            Row(
              children: [
                Chip(
                  avatar: Icon(categoryInfo.icon, size: 16),
                  label: Text(categoryInfo.label),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                const Spacer(),
                // Score Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Score: ${widget.suggestion.score >= 0 ? '+' : ''}${widget.suggestion.score}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_canEditOrDelete) ...[
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      if (value == 'edit') {
                        context.go(
                          '/trip/${widget.suggestion.tripId}/suggestions/${widget.suggestion.id}/edit',
                        );
                      } else if (value == 'delete') {
                        _confirmDelete();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete,
                              size: 20,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Delete',
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),

            const SizedBox(height: 8),

            // Title
            Text(
              widget.suggestion.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            // Note (if present)
            if (widget.suggestion.note.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                widget.suggestion.note,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Footer: Cost & Author info on left, Vote buttons on right
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (costText != null) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.payments_outlined,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              costText,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        'By $_authorName',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                VoteButtons(
                  upCount: widget.suggestion.upCount,
                  downCount: widget.suggestion.downCount,
                  myVote: myVote,
                  isInFlight: _isVoteInFlight,
                  onUpVote: () => _handleVote(1),
                  onDownVote: () => _handleVote(-1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
