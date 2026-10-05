import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfound/core/widgets/app_empty.dart';
import 'package:wayfound/core/widgets/app_error.dart';
import 'package:wayfound/core/widgets/app_loading.dart';
import 'package:wayfound/core/widgets/async_value_widget.dart';

void main() {
  group('Shared Widgets Tests', () {
    testWidgets('AppLoading renders indicator and optional message', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AppLoading(message: 'Loading trips...')),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading trips...'), findsOneWidget);
    });

    testWidgets('AppError renders message and triggers onRetry', (
      tester,
    ) async {
      var retryTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppError(
              message: 'Failed to connect',
              onRetry: () => retryTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Failed to connect'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      expect(retryTapped, isTrue);
    });

    testWidgets('AppEmpty renders title, message, and action button', (
      tester,
    ) async {
      var actionTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppEmpty(
              title: 'No Trips Found',
              message: 'Create your first trip to get started',
              actionLabel: 'Create Trip',
              onAction: () => actionTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('No Trips Found'), findsOneWidget);
      expect(
        find.text('Create your first trip to get started'),
        findsOneWidget,
      );
      expect(find.text('Create Trip'), findsOneWidget);

      await tester.tap(find.text('Create Trip'));
      expect(actionTapped, isTrue);
    });

    testWidgets('AsyncValueWidget handles data, loading, and error states', (
      tester,
    ) async {
      // Data state
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AsyncValueWidget<String>(
              value: const AsyncValue.data('Success Data'),
              data: (val) => Text(val),
            ),
          ),
        ),
      );
      expect(find.text('Success Data'), findsOneWidget);

      // Loading state
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AsyncValueWidget<String>(
              value: const AsyncValue<String>.loading(),
              data: (val) => Text(val),
            ),
          ),
        ),
      );
      expect(find.byType(AppLoading), findsOneWidget);

      // Error state
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AsyncValueWidget<String>(
              value: AsyncValue<String>.error(
                'An error occurred',
                StackTrace.empty,
              ),
              data: (val) => Text(val),
            ),
          ),
        ),
      );
      expect(find.byType(AppError), findsOneWidget);
      expect(find.textContaining('An error occurred'), findsOneWidget);
    });
  });
}
