import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../expenses/data/models/expense_model.dart';
import '../../expenses/data/repositories/expense_repository.dart';
import '../../categories/providers/category_providers.dart';

// ─── Analytics Period ──────────────────────────────────────────────────

enum AnalyticsPeriod {
  thisWeek,
  thisMonth,
  lastMonth,
  thisYear,
}

/// Provider for the currently selected analytics period.
final analyticsPeriodProvider = StateProvider<AnalyticsPeriod>((ref) => AnalyticsPeriod.thisMonth);

/// Helper to get the actual DateTimeRange for the selected period.
final analyticsDateRangeProvider = Provider<DateTimeRange>((ref) {
  final period = ref.watch(analyticsPeriodProvider);
  final now = DateTime.now();

  switch (period) {
    case AnalyticsPeriod.thisWeek:
      final start = now.subtract(Duration(days: now.weekday - 1));
      return DateTimeRange(
        start: DateTime(start.year, start.month, start.day),
        end: DateTime(now.year, now.month, now.day, 23, 59, 59),
      );
    case AnalyticsPeriod.thisMonth:
      return DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
      );
    case AnalyticsPeriod.lastMonth:
      return DateTimeRange(
        start: DateTime(now.year, now.month - 1, 1),
        end: DateTime(now.year, now.month, 0, 23, 59, 59),
      );
    case AnalyticsPeriod.thisYear:
      return DateTimeRange(
        start: DateTime(now.year, 1, 1),
        end: DateTime(now.year, 12, 31, 23, 59, 59),
      );
  }
});

// ─── Data Providers ────────────────────────────────────────────────────

/// Raw expenses for the selected period.
final analyticsExpensesProvider = FutureProvider.autoDispose<List<ExpenseModel>>((ref) async {
  final range = ref.watch(analyticsDateRangeProvider);
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.getExpensesByDateRange(
    range.start,
    range.end,
    type: TransactionType.expense,
  );
});

// ─── Insights Calculations ──────────────────────────────────────────────

class TopCategoryInsight {
  final String categoryName;
  final double amount;
  final int percentage;
  
  TopCategoryInsight({required this.categoryName, required this.amount, required this.percentage});
}

/// Identifies the top spending category and its percentage of total.
final topSpendingCategoryProvider = FutureProvider.autoDispose<TopCategoryInsight?>((ref) async {
  final expenses = await ref.watch(analyticsExpensesProvider.future);
  if (expenses.isEmpty) return null;

  double total = 0;
  final breakdown = <String, double>{};
  
  for (final expense in expenses) {
    total += expense.amount;
    breakdown[expense.category] = (breakdown[expense.category] ?? 0) + expense.amount;
  }

  if (total == 0 || breakdown.isEmpty) return null;

  var topCategory = '';
  var maxAmount = 0.0;
  
  breakdown.forEach((category, amount) {
    if (amount > maxAmount) {
      maxAmount = amount;
      topCategory = category;
    }
  });

  return TopCategoryInsight(
    categoryName: topCategory,
    amount: maxAmount,
    percentage: (maxAmount / total * 100).round(),
  );
});

/// Calculates average daily spend for the selected period.
final averageDailySpendProvider = FutureProvider.autoDispose<double>((ref) async {
  final expenses = await ref.watch(analyticsExpensesProvider.future);
  if (expenses.isEmpty) return 0.0;

  final range = ref.watch(analyticsDateRangeProvider);
  final now = DateTime.now();
  
  // If period ends in the future, only average over days up to today
  final end = range.end.isAfter(now) ? now : range.end;
  
  // Calculate days in range (minimum 1)
  final days = end.difference(range.start).inDays + 1;
  
  final totalSpend = expenses.fold(0.0, (sum, e) => sum + e.amount);
  return totalSpend / days;
});

// ─── Chart Data Providers ───────────────────────────────────────────────

class DailySpendPoint {
  final int day;
  final double amount;
  DailySpendPoint(this.day, this.amount);
}

/// Provides data points for the line chart (daily spend).
final monthlyTrendProvider = FutureProvider.autoDispose<List<DailySpendPoint>>((ref) async {
  final expenses = await ref.watch(analyticsExpensesProvider.future);
  final range = ref.watch(analyticsDateRangeProvider);
  
  final daysInRange = range.end.difference(range.start).inDays + 1;
  final dailyTotals = List<double>.filled(daysInRange, 0.0);
  
  for (final expense in expenses) {
    final dayIndex = expense.date.difference(range.start).inDays;
    if (dayIndex >= 0 && dayIndex < daysInRange) {
      dailyTotals[dayIndex] += expense.amount;
    }
  }

  return List.generate(daysInRange, (index) => DailySpendPoint(index + 1, dailyTotals[index]));
});

class CategoryChartData {
  final String categoryName;
  final double amount;
  final double percentage;
  final int colorIndex;

  CategoryChartData({
    required this.categoryName,
    required this.amount,
    required this.percentage,
    required this.colorIndex,
  });
}

/// Provides detailed data for the pie chart, merging with categories to get color indexes.
final pieChartDataProvider = FutureProvider.autoDispose<List<CategoryChartData>>((ref) async {
  final expenses = await ref.watch(analyticsExpensesProvider.future);
  final allCategories = await ref.watch(allExpenseCategoriesProvider);
  
  if (expenses.isEmpty) return [];

  final breakdown = <String, double>{};
  double total = 0;
  
  for (final expense in expenses) {
    breakdown[expense.category] = (breakdown[expense.category] ?? 0) + expense.amount;
    total += expense.amount;
  }

  final chartData = <CategoryChartData>[];
  
  breakdown.forEach((name, amount) {
    // Find category to get its color
    final categoryItem = allCategories.whenOrNull(
      data: (cats) => cats.where((c) => c.name == name).firstOrNull,
    );
    
    chartData.add(CategoryChartData(
      categoryName: name,
      amount: amount,
      percentage: (amount / total) * 100,
      colorIndex: categoryItem?.colorIndex ?? 0,
    ));
  });

  // Sort by highest amount
  chartData.sort((a, b) => b.amount.compareTo(a.amount));
  
  return chartData;
});
