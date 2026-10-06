import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/theme_provider.dart';
import '../../auth/data/auth_provider.dart';

// Tab destinations for the main navigation (Section 5.1)
final List<NavigationDestination> kTabDestinations = [
  const NavigationDestination(
    icon: Icon(Icons.home_outlined),
    selectedIcon: Icon(Icons.home),
    label: 'Home',
  ),
  const NavigationDestination(
    icon: Icon(Icons.explore_outlined),
    selectedIcon: Icon(Icons.explore),
    label: 'Trips',
  ),
  const NavigationDestination(
    icon: Icon(Icons.lightbulb_outline),
    selectedIcon: Icon(Icons.lightbulb),
    label: 'Ideas',
  ),
  const NavigationDestination(
    icon: Icon(Icons.account_balance_wallet_outlined),
    selectedIcon: Icon(Icons.account_balance_wallet),
    label: 'Expenses',
  ),
];

/// Home screen with tab-based navigation shell.
/// Uses bottom navigation bar with 4 tabs as per the app design.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authUser = ref.watch(authUserProvider);

    final user = authUser.asData?.value;
    final displayName =
        user?.displayName ?? user?.email?.split('@').first ?? '';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Trips'),
        actions: [
          // Quick theme toggle button (Section 14.3)
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            tooltip: 'Toggle Theme',
            onPressed: () {
              ref.read(themeProvider.notifier).toggleTheme(theme.brightness);
            },
          ),
          // User Avatar button reaching Settings screen
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              onTap: () => context.go('/settings'),
              child: Tooltip(
                message: 'Settings',
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  backgroundImage:
                      user?.photoURL != null && user!.photoURL!.isNotEmpty
                      ? NetworkImage(user.photoURL!)
                      : null,
                  child: (user?.photoURL == null || user!.photoURL!.isEmpty)
                      ? Text(
                          initial,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          // Tab 0: Home (current trips overview)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.luggage, size: 64),
                SizedBox(height: 16),
                Text('Your trips will appear here'),
              ],
            ),
          ),
          // Tab 1: Trips (browse/join trips)
          Center(child: Text('Trips Tab')),
          // Tab 2: Ideas (suggestions for active trip)
          Center(child: Text('Ideas Tab')),
          // Tab 3: Expenses (expenses and settlements)
          Center(child: Text('Expenses Tab')),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: kTabDestinations,
      ),
    );
  }
}
