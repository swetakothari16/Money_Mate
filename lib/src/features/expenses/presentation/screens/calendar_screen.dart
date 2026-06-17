import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/providers/preferences_provider.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../expenses/data/models/expense_model.dart';
import '../../../expenses/providers/expense_providers.dart';
import '../../../budgets/data/models/budget_model.dart';
import '../../../budgets/providers/budget_providers.dart';
import '../../../../core/utils/icon_mapper.dart';
import '../../../../core/enums/expense_category.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _currentMonth = DateTime.now();
  DateTime _selectedDate = DateTime.now();

  // Navigate to previous month
  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
      _selectedDate = DateTime(_currentMonth.year, _currentMonth.month, 1);
    });
  }

  // Navigate to next month
  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
      _selectedDate = DateTime(_currentMonth.year, _currentMonth.month, 1);
    });
  }

  // Get days in current month
  int _getDaysInMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0).day;
  }

  // Helper to extract weekday of 1st day (1 = Mon, 7 = Sun)
  int _getFirstWeekdayOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1).weekday;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Watch all expenses
    final expensesAsync = ref.watch(expenseListProvider);

    // Watch budget statuses to calculate dynamic daily limit
    final budgetsAsync = ref.watch(allBudgetStatusesProvider);

    // Watch user's name
    final userName = ref.watch(userNameProvider) ?? 'Sweta';

    return Scaffold(
      backgroundColor: isDark ? theme.colorScheme.surface : const Color(0xFFFAFAFA),
      body: SafeArea(
        child: expensesAsync.when(
          data: (allExpenses) {
            final budgetStatuses = budgetsAsync.value ?? [];
            final overallMonthlyBudget = budgetStatuses.cast<BudgetStatus?>().firstWhere(
              (status) => status != null && status.budget.category == null && status.budget.period == BudgetPeriod.monthly,
              orElse: () => null,
            );

            final int daysInCurrentMonth = _getDaysInMonth(_currentMonth);
            final double budgetLimit = overallMonthlyBudget != null
                ? overallMonthlyBudget.budget.limitAmount
                : 20000.0; // Default budget limit fallback
            
            final double dailyLimit = budgetLimit / daysInCurrentMonth;

            // 1. Filter expenses for the current month being viewed
            final monthlyExpenses = allExpenses.where((e) {
              return e.date.year == _currentMonth.year &&
                  e.date.month == _currentMonth.month &&
                  e.type == TransactionType.expense;
            }).toList();

            // Aggregate spending amounts by day
            final dailySpending = <int, double>{};
            for (final exp in monthlyExpenses) {
              dailySpending[exp.date.day] = (dailySpending[exp.date.day] ?? 0.0) + exp.amount;
            }

            // Calculate total spent in this month
            final double totalMonthSpent = monthlyExpenses.fold(0.0, (sum, exp) => sum + exp.amount);
            final double remainingAmount = budgetLimit - totalMonthSpent;

            // 2. Construct Sunday-First Calendar grid items
            final firstWeekday = _getFirstWeekdayOfMonth(_currentMonth);
            
            // Sunday is 7 in Dart. If 1st is Sunday, we need 0 padding cells.
            // If 1st is Monday (1), we need 1 padding cell.
            // If 1st is Saturday (6), we need 6 padding cells.
            final int prevMonthPaddingCount = firstWeekday % 7; 
            final prevMonthDateTime = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
            final int daysInPrevMonth = _getDaysInMonth(prevMonthDateTime);

            final List<_CalendarDayItem> cells = [];

            // Add previous month's padding cells
            for (int i = prevMonthPaddingCount - 1; i >= 0; i--) {
              final dayNum = daysInPrevMonth - i;
              cells.add(_CalendarDayItem(
                date: DateTime(prevMonthDateTime.year, prevMonthDateTime.month, dayNum),
                isCurrentMonth: false,
                spendAmount: 0.0,
              ));
            }

            // Add current month's cells
            for (int day = 1; day <= daysInCurrentMonth; day++) {
              cells.add(_CalendarDayItem(
                date: DateTime(_currentMonth.year, _currentMonth.month, day),
                isCurrentMonth: true,
                spendAmount: dailySpending[day] ?? 0.0,
              ));
            }

            // Fill next month's padding cells to make complete rows
            final int totalCellsSoFar = cells.length;
            final int nextMonthPaddingCount = (7 - (totalCellsSoFar % 7)) % 7;
            final nextMonthDateTime = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
            for (int day = 1; day <= nextMonthPaddingCount; day++) {
              cells.add(_CalendarDayItem(
                date: DateTime(nextMonthDateTime.year, nextMonthDateTime.month, day),
                isCurrentMonth: false,
                spendAmount: 0.0,
              ));
            }

            // Get transactions of selected day
            final selectedDayExpenses = allExpenses.where((e) {
              return e.date.year == _selectedDate.year &&
                  e.date.month == _selectedDate.month &&
                  e.date.day == _selectedDate.day;
            }).toList();

            final double selectedDayTotal = selectedDayExpenses
                .where((e) => e.type == TransactionType.expense)
                .fold(0.0, (sum, e) => sum + e.amount);

            // Compute category insights for this month
            final categoryTotals = <String, double>{};
            for (final exp in monthlyExpenses) {
              categoryTotals[exp.category] = (categoryTotals[exp.category] ?? 0.0) + exp.amount;
            }

            final sortedCategories = categoryTotals.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));

            // Smart Saver Days Calculation
            int withinBudgetDaysCount = 0;
            for (int day = 1; day <= daysInCurrentMonth; day++) {
              final spent = dailySpending[day] ?? 0.0;
              if (spent <= dailyLimit) {
                withinBudgetDaysCount++;
              }
            }

            return Stack(
              children: [
                CustomScrollView(
                  slivers: [
                    // ─── Welcome Header ───────────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(AppDimens.lg, AppDimens.lg, AppDimens.lg, AppDimens.sm),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
                                  child: Text(
                                    userName.isNotEmpty ? userName[0].toUpperCase() : 'S',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppDimens.md),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Welcome back,',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface.withOpacity(0.55),
                                      ),
                                    ),
                                    Text(
                                      'Hello, $userName 👋',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            IconButton(
                              onPressed: () {
                                // Dynamic feature callback
                              },
                              icon: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F2FF),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.bolt_rounded,
                                  color: Color(0xFF3B82F6),
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05),
                      ),
                    ),

                    // ─── Spent Summary Card ───────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg, vertical: AppDimens.sm),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isDark ? Colors.transparent : Colors.blue.withOpacity(0.05),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.025),
                                blurRadius: 15,
                                spreadRadius: 2,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Monthly Spent',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurface.withOpacity(0.45),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    CurrencyFormatter.format(totalMonthSpent),
                                    style: theme.textTheme.headlineLarge?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF111827),
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.trending_up_rounded,
                                    color: Color(0xFF111827),
                                    size: 24,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF3F4F6),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: const [
                                              Icon(Icons.circle, color: Color(0xFF9CA3AF), size: 8),
                                              SizedBox(width: 6),
                                              Text(
                                                'Budget',
                                                style: TextStyle(
                                                  color: Color(0xFF6B7280),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            CurrencyFormatter.format(budgetLimit),
                                            style: const TextStyle(
                                              color: Color(0xFF111827),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: const Color(0xFFE5E7EB)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: const [
                                              Icon(Icons.calendar_today_rounded, color: Color(0xFF111827), size: 10),
                                              SizedBox(width: 6),
                                              Text(
                                                'Remaining',
                                                style: TextStyle(
                                                  color: Color(0xFF111827),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            CurrencyFormatter.format(remainingAmount),
                                            style: TextStyle(
                                              color: remainingAmount >= 0 ? const Color(0xFF111827) : AppColors.expense,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ).animate().fadeIn(duration: 500.ms, delay: 100.ms).slideY(begin: 0.05),
                      ),
                    ),

                    // ─── Your Spending Calendar Header ────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(AppDimens.lg, AppDimens.lg, AppDimens.lg, AppDimens.sm),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Your Spending Calendar',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF111827),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Month Selector Pill
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    constraints: const BoxConstraints(),
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(Icons.chevron_left_rounded, size: 20, color: Color(0xFF4B5563)),
                                    onPressed: _prevMonth,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    DateFormat('MMM yyyy').format(_currentMonth),
                                    style: const TextStyle(
                                      color: Color(0xFF111827),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    constraints: const BoxConstraints(),
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF4B5563)),
                                    onPressed: _nextMonth,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ).animate().fadeIn(duration: 400.ms, delay: 150.ms),
                      ),
                    ),

                    // ─── Weekday Headers (Sunday First) ───────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg, vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((day) {
                            return SizedBox(
                              width: 44,
                              child: Center(
                                child: Text(
                                  day,
                                  style: TextStyle(
                                    color: const Color(0xFF9CA3AF),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ).animate().fadeIn(duration: 400.ms, delay: 180.ms),
                      ),
                    ),

                    // ─── Calendar Grid (Sunday First) ─────────────────────────
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.49, // Tall pill shape
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = cells[index];
                            final isSelected = item.date.year == _selectedDate.year &&
                                item.date.month == _selectedDate.month &&
                                item.date.day == _selectedDate.day;

                            final isToday = item.date.year == DateTime.now().year &&
                                item.date.month == DateTime.now().month &&
                                item.date.day == DateTime.now().day;

                            // Determine emoji based on daily spending
                            String statusEmoji = '😴';
                            if (item.spendAmount <= 0) {
                              statusEmoji = '😴';
                            } else if (item.spendAmount <= dailyLimit * 0.4) {
                              statusEmoji = '😊';
                            } else if (item.spendAmount <= dailyLimit * 0.9) {
                              statusEmoji = '😐';
                            } else {
                              statusEmoji = '😱';
                            }

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedDate = item.date;
                                  if (item.date.month != _currentMonth.month) {
                                    _currentMonth = DateTime(item.date.year, item.date.month, 1);
                                  }
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFE8F2FF)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF3B82F6)
                                        : isToday
                                            ? const Color(0xFF93C5FD)
                                            : const Color(0xFFE5E7EB),
                                    width: isSelected ? 1.5 : 1.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.015),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Day number
                                    Text(
                                      item.date.day.toString(),
                                      style: TextStyle(
                                        fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                                        color: item.isCurrentMonth
                                            ? const Color(0xFF111827)
                                            : const Color(0xFFD1D5DB),
                                        fontSize: 12,
                                      ),
                                    ),

                                    // Emoji status face
                                    Opacity(
                                      opacity: item.isCurrentMonth ? 1.0 : 0.35,
                                      child: Text(
                                        statusEmoji,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),

                                    // Spent Amount
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 2.0),
                                        child: Text(
                                          item.spendAmount > 0
                                              ? '₹${CurrencyFormatter.formatCompact(item.spendAmount).replaceAll('₹', '')}'
                                              : '₹0',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: item.spendAmount > 0
                                                ? (item.spendAmount > dailyLimit * 0.9 ? AppColors.expense : const Color(0xFF4B5563))
                                                : const Color(0xFF9CA3AF),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ).animate().fadeIn(duration: 350.ms, delay: (100 + index * 5).ms);
                          },
                          childCount: cells.length,
                        ),
                      ),
                    ),

                    // ─── Selected Day Summary Header ──────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(AppDimens.lg, AppDimens.xl, AppDimens.lg, AppDimens.xs),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text('📅', style: TextStyle(fontSize: 14)),
                                    const SizedBox(width: 6),
                                    Text(
                                      DateFormat('MMMM d, yyyy').format(_selectedDate),
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF111827),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Daily expenditure summary',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurface.withOpacity(0.45),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Total Spent',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: theme.colorScheme.onSurface.withOpacity(0.45),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.format(selectedDayTotal),
                                  style: TextStyle(
                                    color: selectedDayTotal > 0 ? AppColors.expense : const Color(0xFF9CA3AF),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ).animate().fadeIn(duration: 450.ms, delay: 250.ms),
                      ),
                    ),

                    // ─── Daily Transaction List ──────────────────────────────
                    if (selectedDayExpenses.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg, vertical: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFECFDF5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Text('😴', style: TextStyle(fontSize: 22)),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'A Perfect Saver Day!',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Color(0xFF111827),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'No spending records found for this day.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: theme.colorScheme.onSurface.withOpacity(0.45),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg, vertical: 8),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final expense = selectedDayExpenses[index];
                              final defaultColor = expense.type == TransactionType.income ? AppColors.income : AppColors.expense;
                              
                              Color iconColor = const Color(0xFF3B82F6);
                              switch (expense.category.toLowerCase()) {
                                case 'food':
                                case 'food & dining':
                                case 'food & drinks':
                                  iconColor = const Color(0xFFF59E0B);
                                  break;
                                case 'transport':
                                case 'transportation':
                                  iconColor = const Color(0xFF3B82F6);
                                  break;
                                case 'shopping':
                                  iconColor = const Color(0xFFEC4899);
                                  break;
                                case 'entertainment':
                                  iconColor = const Color(0xFF8B5CF6);
                                  break;
                                case 'health':
                                case 'health & medical':
                                  iconColor = const Color(0xFF06B6D4);
                                  break;
                                case 'bills':
                                case 'bills & utilities':
                                  iconColor = const Color(0xFFEF4444);
                                  break;
                                case 'rent':
                                case 'rent & housing':
                                case 'housing':
                                  iconColor = const Color(0xFF14B8A6);
                                  break;
                                case 'salary':
                                  iconColor = const Color(0xFF10B981);
                              }

                              final icon = IconMapper.getIcon(null, categoryName: expense.category);

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: const Color(0xFFE5E7EB)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: iconColor.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(icon, color: iconColor, size: 20),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              expense.title,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: Color(0xFF111827),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 3),
                                            // Category Pill Badge
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF3F4F6),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                ExpenseCategory.getLabel(expense.category),
                                                style: const TextStyle(
                                                  fontSize: 9,
                                                  color: Color(0xFF4B5563),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '${expense.type == TransactionType.income ? '+' : '-'}${CurrencyFormatter.format(expense.amount)}',
                                        style: TextStyle(
                                          color: expense.type == TransactionType.income ? AppColors.income : const Color(0xFF111827),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            childCount: selectedDayExpenses.length,
                          ),
                        ),
                      ),

                    // ─── Spending Insights Header ────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(AppDimens.lg, AppDimens.lg, AppDimens.lg, AppDimens.sm),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Spending Insights',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF111827),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                context.go(AppRoutes.analytics);
                              },
                              child: const Text(
                                'View All',
                                style: TextStyle(
                                  color: Color(0xFF3B82F6),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
                      ),
                    ),

                    // ─── Spending Insights Cards ─────────────────────────────
                    SliverToBoxAdapter(
                      child: Container(
                        height: 94,
                        padding: const EdgeInsets.only(left: AppDimens.lg),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: 3,
                          itemBuilder: (context, index) {
                            String categoryLabel = 'Shopping';
                            double amount = 0.0;
                            String iconEmoji = '🛍️';
                            Color bgColor = Colors.white;
                            Color? borderColor = const Color(0xFFE5E7EB);

                            // Load dynamically from calculations if indices match
                            if (index < sortedCategories.length) {
                              final entry = sortedCategories[index];
                              categoryLabel = ExpenseCategory.getLabel(entry.key);
                              amount = entry.value;
                              
                              switch (entry.key.toLowerCase()) {
                                case 'food':
                                case 'food & dining':
                                case 'food & drinks':
                                  categoryLabel = 'Food';
                                  iconEmoji = '🐷';
                                  break;
                                case 'transport':
                                case 'transportation':
                                  categoryLabel = 'Travel';
                                  iconEmoji = '🚗';
                                  break;
                                case 'shopping':
                                  categoryLabel = 'Shopping';
                                  iconEmoji = '🛍️';
                                  break;
                                default:
                                  iconEmoji = '🏷️';
                              }
                            } else {
                              // Defaults for padding to show exactly 3 cards
                              if (index == 1) {
                                categoryLabel = 'Travel';
                                iconEmoji = '🚗';
                              } else if (index == 2) {
                                categoryLabel = 'Shopping';
                                iconEmoji = '🛍️';
                              } else {
                                categoryLabel = 'Food';
                                iconEmoji = '🐷';
                              }
                            }

                            // Dynamic style based on list position (Peach/Blue/Outline)
                            if (index == 0) {
                              bgColor = const Color(0xFFFFEEEC);
                              borderColor = null;
                            } else if (index == 1) {
                              bgColor = const Color(0xFFE8F2FF);
                              borderColor = null;
                            }

                            return Container(
                              width: 104,
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(20),
                                border: borderColor != null ? Border.all(color: borderColor) : null,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text(iconEmoji, style: const TextStyle(fontSize: 16)),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        categoryLabel,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF4B5563),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '₹${CurrencyFormatter.formatCompact(amount).replaceAll('₹', '')}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF111827),
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ).animate().fadeIn(duration: 500.ms, delay: 350.ms),
                      ),
                    ),

                    // ─── Smart Saver Tip Card ─────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg, vertical: 24),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF9E6), // Beige/Gold background
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFFD970), // Circle color
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Text('🏦', style: TextStyle(fontSize: 24)),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: const [
                                        Text('😊', style: TextStyle(fontSize: 13)),
                                        SizedBox(width: 4),
                                        Text(
                                          'Smart Saver',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: Color(0xFF78350F),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    RichText(
                                      text: TextSpan(
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF92400E),
                                          height: 1.35,
                                        ),
                                        children: [
                                          const TextSpan(text: 'Great Job! '),
                                          const TextSpan(text: 'You stayed within budget for '),
                                          TextSpan(
                                            text: '$withinBudgetDaysCount days',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          const TextSpan(text: ' this month. Keep it up!'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(duration: 500.ms, delay: 400.ms),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 100)), // Bottom nav padding
                  ],
                ),

                // ─── Floating Action Button (+) ─────────────────────────────
                Positioned(
                  bottom: 24,
                  right: 24,
                  child: FloatingActionButton(
                    heroTag: 'calendarAddExpense',
                    onPressed: () {
                      context.push(AppRoutes.addExpense, extra: _selectedDate);
                    },
                    shape: const CircleBorder(),
                    backgroundColor: const Color(0xFF67E8F9), // Bright light blue (+) FAB
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error loading calendar: $err')),
        ),
      ),
    );
  }
}

class _CalendarDayItem {
  final DateTime date;
  final bool isCurrentMonth;
  final double spendAmount;

  _CalendarDayItem({
    required this.date,
    required this.isCurrentMonth,
    required this.spendAmount,
  });
}
