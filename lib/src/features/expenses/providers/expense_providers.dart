import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/models/expense_model.dart';
import '../data/repositories/expense_repository.dart';

// ═══════════════════════════════════════════════════════════════════════════
// EXPENSE LIST PROVIDER (AsyncNotifier)
// ═══════════════════════════════════════════════════════════════════════════

/// Manages the list of all expenses with full CRUD capabilities.
///
/// Uses [AsyncNotifier] so the UI can:
/// - Show loading states during initial fetch
/// - React to errors with proper fallbacks
/// - Auto-refresh when the database changes (via Isar's watchLazy)
///
/// Usage in UI:
/// ```dart
/// final expensesAsync = ref.watch(expenseListProvider);
/// expensesAsync.when(
///   data: (expenses) => ListView(...),
///   loading: () => CircularProgressIndicator(),
///   error: (e, st) => Text('Error: $e'),
/// );
/// ```
class ExpenseListNotifier extends AsyncNotifier<List<ExpenseModel>> {
  late final ExpenseRepository _repository;
  StreamSubscription<void>? _watchSubscription;

  @override
  Future<List<ExpenseModel>> build() async {
    _repository = ref.watch(expenseRepositoryProvider);

    // Listen to database changes and refetch when data changes.
    // ref.onDispose cancels the subscription when the provider is disposed.
    _watchSubscription?.cancel();
    _watchSubscription = _repository.watchExpenses().listen((_) {
      _refetch();
    });
    ref.onDispose(() => _watchSubscription?.cancel());

    return _repository.getAllExpenses();
  }

  /// Refetches data without resetting to loading state.
  /// Keeps the current data visible while refreshing.
  Future<void> _refetch() async {
    state = AsyncData(await _repository.getAllExpenses());
  }

  /// Adds a new expense. Returns the assigned Isar ID.
  Future<int> addExpense({
    required String title,
    required double amount,
    required DateTime date,
    required TransactionType type,
    required String category,
    String? note,
    PaymentMethod paymentMethod = PaymentMethod.cash,
    List<String> tags = const [],
    bool isRecurring = false,
    String? receiptPath,
  }) async {
    final expense = ExpenseModel()
      ..title = title
      ..amount = amount
      ..date = date
      ..type = type
      ..category = category
      ..note = note
      ..paymentMethod = paymentMethod
      ..tags = tags
      ..isRecurring = isRecurring
      ..receiptPath = receiptPath
      ..uuid = const Uuid().v4()
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();

    return _repository.addExpense(expense);
  }

  /// Updates an existing expense.
  Future<void> updateExpense(ExpenseModel expense) async {
    await _repository.updateExpense(expense);
  }

  /// Deletes a single expense by ID.
  Future<bool> deleteExpense(int id) async {
    return _repository.deleteExpense(id);
  }

  /// Deletes multiple expenses by their IDs.
  Future<void> deleteMultiple(List<int> ids) async {
    await _repository.deleteMultiple(ids);
  }

  /// Searches expenses by title, note, or category.
  Future<List<ExpenseModel>> search(String query) async {
    if (query.trim().isEmpty) {
      return state.value ?? [];
    }
    return _repository.searchExpenses(query);
  }
}

/// The main expense list provider.
final expenseListProvider =
    AsyncNotifierProvider<ExpenseListNotifier, List<ExpenseModel>>(
  ExpenseListNotifier.new,
);

// ═══════════════════════════════════════════════════════════════════════════
// FILTERED / DERIVED PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

/// Currently selected date range filter for the expenses list.
final expenseDateRangeProvider = StateProvider<DateTimeRange?>((ref) => null);

/// Currently selected transaction type filter.
final expenseTypeFilterProvider = StateProvider<TransactionType?>((ref) => null);

/// Currently selected category filter.
final expenseCategoryFilterProvider = StateProvider<String?>((ref) => null);

/// Filtered expenses based on active filters.
///
/// Watches the main expense list and all filter providers, returning
/// a derived subset. This is efficient because filtering happens
/// in-memory on the already-loaded data.
final filteredExpensesProvider = Provider<AsyncValue<List<ExpenseModel>>>((ref) {
  final expensesAsync = ref.watch(expenseListProvider);
  final dateRange = ref.watch(expenseDateRangeProvider);
  final typeFilter = ref.watch(expenseTypeFilterProvider);
  final categoryFilter = ref.watch(expenseCategoryFilterProvider);

  return expensesAsync.whenData((expenses) {
    var filtered = expenses;

    // Apply date range filter
    if (dateRange != null) {
      filtered = filtered.where((e) {
        return e.date.isAfter(dateRange.start.subtract(const Duration(days: 1))) &&
            e.date.isBefore(dateRange.end.add(const Duration(days: 1)));
      }).toList();
    }

    // Apply type filter
    if (typeFilter != null) {
      filtered = filtered.where((e) => e.type == typeFilter).toList();
    }

    // Apply category filter
    if (categoryFilter != null) {
      filtered = filtered.where((e) => e.category == categoryFilter).toList();
    }

    return filtered;
  });
});

/// Groups expenses by date for section headers in the transactions list.
final groupedExpensesProvider =
    Provider<AsyncValue<Map<DateTime, List<ExpenseModel>>>>((ref) {
  return ref.watch(filteredExpensesProvider).whenData((expenses) {
    final grouped = <DateTime, List<ExpenseModel>>{};
    for (final expense in expenses) {
      // Normalize to date-only (strip time)
      final dateKey = DateTime(expense.date.year, expense.date.month, expense.date.day);
      grouped.putIfAbsent(dateKey, () => []).add(expense);
    }
    return grouped;
  });
});

// ═══════════════════════════════════════════════════════════════════════════
// SUMMARY / AGGREGATION PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

/// Summary data for the dashboard balance card.
class ExpenseSummary {
  final double totalIncome;
  final double totalExpense;
  final double balance;
  final int transactionCount;

  const ExpenseSummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
    required this.transactionCount,
  });

  factory ExpenseSummary.empty() => const ExpenseSummary(
        totalIncome: 0,
        totalExpense: 0,
        balance: 0,
        transactionCount: 0,
      );
}

/// Provides computed summary (income, expense, balance) from all expenses.
///
/// This re-computes whenever the expense list changes thanks to
/// Riverpod's dependency tracking.
final expenseSummaryProvider = Provider<AsyncValue<ExpenseSummary>>((ref) {
  return ref.watch(expenseListProvider).whenData((expenses) {
    double totalIncome = 0;
    double totalExpense = 0;

    for (final e in expenses) {
      if (e.type == TransactionType.income) {
        totalIncome += e.amount;
      } else if (e.type == TransactionType.expense) {
        totalExpense += e.amount;
      }
    }

    return ExpenseSummary(
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      balance: totalIncome - totalExpense,
      transactionCount: expenses.length,
    );
  });
});

/// Provides a category breakdown map for charts.
/// Returns `Map<String, double>` where keys are category names
/// and values are total amounts.
final categoryBreakdownProvider =
    FutureProvider.family<Map<String, double>, DateTimeRange>((ref, range) async {
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.getCategoryBreakdown(range.start, range.end);
});

/// Provides the most recent N expenses for the dashboard.
final recentExpensesProvider =
    FutureProvider.autoDispose<List<ExpenseModel>>((ref) async {
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.getAllExpenses(limit: 5);
});

/// The total number of transactions (for stats display).
final transactionCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.getTransactionCount();
});

/// Today's total spending.
final todaysSpendingProvider = FutureProvider.autoDispose<double>((ref) async {
  final repo = ref.watch(expenseRepositoryProvider);
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
  final expenses = await repo.getExpensesByDateRange(startOfDay, endOfDay, type: TransactionType.expense);
  return expenses.fold(0.0, (sum, e) => sum + e.amount);
});

/// Current month's total spending.
final currentMonthSpendingProvider = FutureProvider.autoDispose<double>((ref) async {
  final repo = ref.watch(expenseRepositoryProvider);
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);
  final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
  final expenses = await repo.getExpensesByDateRange(startOfMonth, endOfMonth, type: TransactionType.expense);
  return expenses.fold(0.0, (sum, e) => sum + e.amount);
});
