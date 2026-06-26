import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/budget_model.dart';
import '../data/repositories/budget_repository.dart';
import '../../expenses/data/repositories/expense_repository.dart';
import '../../expenses/data/models/expense_model.dart';

// ═══════════════════════════════════════════════════════════════════════════
// BUDGET LIST PROVIDER (AsyncNotifier)
// ═══════════════════════════════════════════════════════════════════════════

/// Manages the list of all budgets with CRUD capabilities.
class BudgetListNotifier extends AsyncNotifier<List<BudgetModel>> {
  late BudgetRepository _repository;
  StreamSubscription<void>? _watchSubscription;

  @override
  Future<List<BudgetModel>> build() async {
    _repository = ref.watch(budgetRepositoryProvider);

    _watchSubscription?.cancel();
    _watchSubscription = _repository.watchBudgets().listen((_) {
      _refetch();
    });
    ref.onDispose(() => _watchSubscription?.cancel());

    return _repository.getActiveBudgets();
  }

  Future<void> _refetch() async {
    state = AsyncData(await _repository.getActiveBudgets());
  }

  /// Creates a new budget and returns its Isar ID.
  Future<int> addBudget({
    required String name,
    required double limitAmount,
    required BudgetPeriod period,
    String? category,
    required DateTime startDate,
    required DateTime endDate,
    double alertThreshold = 0.8,
    bool notifyOnThreshold = true,
  }) async {
    final budget = BudgetModel()
      ..name = name
      ..limitAmount = limitAmount
      ..period = period
      ..category = category
      ..startDate = startDate
      ..endDate = endDate
      ..alertThreshold = alertThreshold
      ..notifyOnThreshold = notifyOnThreshold
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();

    return _repository.addBudget(budget);
  }

  /// Updates an existing budget.
  Future<void> updateBudget(BudgetModel budget) async {
    await _repository.updateBudget(budget);
  }

  /// Soft-deletes a budget by marking it inactive.
  Future<void> deactivateBudget(BudgetModel budget) async {
    budget.isActive = false;
    await _repository.updateBudget(budget);
  }

  /// Permanently deletes a budget.
  Future<bool> deleteBudget(int id) async {
    return _repository.deleteBudget(id);
  }
}

/// The main budget list provider.
final budgetListProvider =
    AsyncNotifierProvider<BudgetListNotifier, List<BudgetModel>>(
  BudgetListNotifier.new,
);

// ═══════════════════════════════════════════════════════════════════════════
// BUDGET STATUS / PROGRESS PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

/// Holds computed budget status for a single budget.
class BudgetStatus {
  final BudgetModel budget;
  final double spentAmount;
  final double remainingAmount;
  final double progress; // 0.0 – 1.0+
  final bool isOverBudget;
  final bool isNearThreshold;

  const BudgetStatus({
    required this.budget,
    required this.spentAmount,
    required this.remainingAmount,
    required this.progress,
    required this.isOverBudget,
    required this.isNearThreshold,
  });
}

/// Provides the [BudgetStatus] for a specific budget.
///
/// Computes [spentAmount] from the expense collection at query time
/// rather than storing it on the budget model. This prevents stale
/// data when expenses are added/deleted.
final budgetStatusProvider =
    FutureProvider.family<BudgetStatus, BudgetModel>((ref, budget) async {
  final expenseRepo = ref.watch(expenseRepositoryProvider);

  // Calculate total spent in the budget's date range & category
  double spent;
  if (budget.category != null) {
    spent = await expenseRepo.getTotalByCategory(
      budget.category!,
      budget.startDate,
      budget.endDate,
    );
  } else {
    // Overall budget: sum all expenses in the date range
    final expenses = await expenseRepo.getExpensesByDateRange(
      budget.startDate,
      budget.endDate,
      type: TransactionType.expense,
    );
    spent = expenses.fold<double>(0.0, (sum, e) => sum + e.amount);
  }

  final remaining = budget.limitAmount - spent;
  final progress = budget.limitAmount > 0 ? spent / budget.limitAmount : 0.0;

  return BudgetStatus(
    budget: budget,
    spentAmount: spent,
    remainingAmount: remaining,
    progress: progress,
    isOverBudget: spent > budget.limitAmount,
    isNearThreshold: progress >= budget.alertThreshold && !progress.isNaN,
  );
});

/// Provides budget statuses for ALL active budgets at once.
///
/// Useful for the dashboard overview that shows multiple budget bars.
final allBudgetStatusesProvider =
    FutureProvider<List<BudgetStatus>>((ref) async {
  final budgets = await ref.watch(budgetListProvider.future);
  final expenseRepo = ref.watch(expenseRepositoryProvider);

  final statuses = <BudgetStatus>[];

  for (final budget in budgets) {
    double spent;
    if (budget.category != null) {
      spent = await expenseRepo.getTotalByCategory(
        budget.category!,
        budget.startDate,
        budget.endDate,
      );
    } else {
      final expenses = await expenseRepo.getExpensesByDateRange(
        budget.startDate,
        budget.endDate,
        type: TransactionType.expense,
      );
      spent = expenses.fold<double>(0.0, (sum, e) => sum + e.amount);
    }

    final remaining = budget.limitAmount - spent;
    final progress = budget.limitAmount > 0 ? spent / budget.limitAmount : 0.0;

    statuses.add(BudgetStatus(
      budget: budget,
      spentAmount: spent,
      remainingAmount: remaining,
      progress: progress,
      isOverBudget: spent > budget.limitAmount,
      isNearThreshold: progress >= budget.alertThreshold && !progress.isNaN,
    ));
  }

  return statuses;
});
