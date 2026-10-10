import 'package:flutter/material.dart';

import '../domain/trip_days.dart';

class DayPickerSheet extends StatelessWidget {
  final DateTime startDate;
  final int totalDays;
  final int? currentDayIndex;
  final ValueChanged<int> onDaySelected;

  const DayPickerSheet({
    super.key,
    required this.startDate,
    required this.totalDays,
    this.currentDayIndex,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Day',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: totalDays,
                itemBuilder: (context, index) {
                  final header = formatDayHeader(startDate, index);
                  final isCurrent = currentDayIndex == index;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isCurrent
                          ? theme.colorScheme.secondaryContainer
                          : theme.colorScheme.surfaceContainerHighest,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: isCurrent
                              ? theme.colorScheme.onSecondaryContainer
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      header,
                      style: TextStyle(
                        fontWeight: isCurrent
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    trailing: isCurrent
                        ? Chip(
                            label: const Text('Current'),
                            backgroundColor:
                                theme.colorScheme.secondaryContainer,
                            labelStyle: TextStyle(
                              color: theme.colorScheme.onSecondaryContainer,
                              fontSize: 12,
                            ),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).pop();
                      onDaySelected(index);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
