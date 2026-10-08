import 'package:flutter/material.dart';

import '../domain/vote.dart';

class VoteButtons extends StatelessWidget {
  final int upCount;
  final int downCount;
  final Vote? myVote;
  final VoidCallback? onUpVote;
  final VoidCallback? onDownVote;
  final bool isInFlight;

  const VoteButtons({
    super.key,
    required this.upCount,
    required this.downCount,
    this.myVote,
    this.onUpVote,
    this.onDownVote,
    this.isInFlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isUpSelected = myVote?.isUp ?? false;
    final isDownSelected = myVote?.isDown ?? false;

    final activeColor = colorScheme.secondary;
    final inactiveColor = colorScheme.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Upvote Button
        Semantics(
          label: 'Upvote',
          button: true,
          selected: isUpSelected,
          child: Tooltip(
            message: 'Upvote',
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: isInFlight ? null : onUpVote,
              child: Container(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: isUpSelected
                      ? activeColor.withValues(alpha: 0.15)
                      : Colors.transparent,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isUpSelected ? Icons.thumb_up : Icons.thumb_up_outlined,
                      size: 20,
                      color: isUpSelected ? activeColor : inactiveColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$upCount',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: isUpSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isUpSelected ? activeColor : inactiveColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Downvote Button
        Semantics(
          label: 'Downvote',
          button: true,
          selected: isDownSelected,
          child: Tooltip(
            message: 'Downvote',
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: isInFlight ? null : onDownVote,
              child: Container(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: isDownSelected
                      ? activeColor.withValues(alpha: 0.15)
                      : Colors.transparent,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isDownSelected
                          ? Icons.thumb_down
                          : Icons.thumb_down_outlined,
                      size: 20,
                      color: isDownSelected ? activeColor : inactiveColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$downCount',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: isDownSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isDownSelected ? activeColor : inactiveColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
