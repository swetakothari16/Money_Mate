import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/routing/app_router.dart';

/// Main scaffold shell with bottom navigation bar.
/// Wraps all tabbed routes via GoRouter's ShellRoute.
class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith(AppRoutes.analytics)) return 2;
    if (location.startsWith(AppRoutes.settings)) return 3;
    if (location.startsWith(AppRoutes.transactions)) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentIndex = _currentIndex(context);

    return Scaffold(
      body: child,
      floatingActionButton: FloatingActionButton(
        heroTag: 'addExpense',
        onPressed: () => context.push(AppRoutes.addExpense),
        child: const Icon(Icons.add_rounded, size: 28),
      ).animate().scale(
            duration: 400.ms,
            curve: Curves.elasticOut,
          ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: theme.colorScheme.outlineVariant.withOpacity(0.1),
              width: 1,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (index) => _onTap(context, index),
          animationDuration: const Duration(milliseconds: 400),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'Transactions',
            ),
            NavigationDestination(
              icon: Icon(Icons.analytics_outlined),
              selectedIcon: Icon(Icons.analytics_rounded),
              label: 'Analytics',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.dashboard);
      case 1:
        context.go(AppRoutes.transactions);
      case 2:
        context.go(AppRoutes.analytics);
      case 3:
        context.go(AppRoutes.settings);
    }
  }
}
