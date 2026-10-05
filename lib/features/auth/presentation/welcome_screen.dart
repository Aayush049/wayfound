import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// TEMP(phase-1): Placeholder Welcome Screen for Phase 0 setup testing.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 120,
                  errorBuilder: (context, error, stackTrace) =>
                      Icon(Icons.explore, size: 96, color: colorScheme.primary),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Wayfound',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Collaborative trip planner for groups',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              // TEMP(phase-1): Temporary button to navigate to Home for Phase 0 testing
              ElevatedButton(
                onPressed: () => context.go('/home'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                ),
                child: const Text('Go to Home (TEMP)'),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
