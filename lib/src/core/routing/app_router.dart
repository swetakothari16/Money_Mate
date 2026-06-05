import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/transactions/presentation/screens/transactions_screen.dart';
import '../../features/analytics/presentation/screens/analytics_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/expenses/presentation/screens/add_expense_screen.dart';
import '../../features/statement_import/presentation/screens/statement_import_screen.dart';
import '../../features/budgets/presentation/screens/add_budget_screen.dart';
import '../../features/budgets/presentation/screens/budgets_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/onboarding/presentation/screens/setup_screen.dart';
import '../../core/providers/preferences_provider.dart';
import '../navigation/app_shell.dart';

/// Named route paths.
abstract class AppRoutes {
  static const String dashboard = '/';
  static const String login = '/login';
  static const String setup = '/setup';
  static const String transactions = '/transactions';
  static const String budgets = '/budgets';
  static const String addExpense = '/expenses/add';
  static const String statementImport = '/expenses/import';
  static const String addBudget = '/budgets/add';
  static const String analytics = '/analytics';
  static const String settings = '/settings';
}

/// Global GoRouter provider.
final appRouterProvider = Provider<GoRouter>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  final hasCompletedOnboarding = ref.watch(onboardingProvider);

  return GoRouter(
    initialLocation: AppRoutes.dashboard,
    debugLogDiagnostics: false,
    refreshListenable: GoRouterRefreshStream(authRepo.authStateChanges),
    redirect: (context, state) {
      final user = authRepo.currentUser;
      final isLoggingIn = state.matchedLocation == AppRoutes.login;
      final isOnboarding = state.matchedLocation == AppRoutes.setup;

      if (user == null) {
        return AppRoutes.login;
      }

      if (!hasCompletedOnboarding) {
        if (isOnboarding) return null;
        return AppRoutes.setup;
      }

      if (isLoggingIn || isOnboarding) {
        if (user.isAnonymous && isLoggingIn) {
          return null;
        }
        return AppRoutes.dashboard;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: LoginScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.setup,
        name: 'setup',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: SetupScreen(),
        ),
      ),
      // ─── Shell Route for Bottom Navigation ────────────────────────
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(child: child);
        },
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            name: 'dashboard',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DashboardScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.transactions,
            name: 'transactions',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: TransactionsScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.budgets,
            name: 'budgets',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: BudgetsScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.analytics,
            name: 'analytics',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AnalyticsScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.settings,
            name: 'settings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsScreen(),
            ),
          ),
        ],
      ),

      // ─── Full-Screen Routes (no bottom nav) ──────────────────────
      GoRoute(
        path: AppRoutes.addExpense,
        name: 'addExpense',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const AddExpenseScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.statementImport,
        name: 'statementImport',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const StatementImportScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.addBudget,
        name: 'addBudget',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const AddBudgetScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            );
          },
        ),
      ),
    ],
  );
});

class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((dynamic _) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
