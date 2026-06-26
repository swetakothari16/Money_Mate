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

enum CalendarFilterType { expenses, income, total }

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _currentMonth = DateTime.now();
  DateTime _selectedDate = DateTime.now();
  CalendarFilterType _activeFilter = CalendarFilterType.expenses;

  // Format cell values compactly and cleanly without currency symbols
  String _formatCellAmount(double amount) {
    final absAmount = amount.abs();
    if (absAmount == 0) return '';
    
    if (absAmount >= 1000000) {
      final value = absAmount / 1000000;
      return '${amount < 0 ? '-' : ''}${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}M';
    }
    if (absAmount >= 1000) {
      final value = absAmount / 1000;
      return '${amount < 0 ? '-' : ''}${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}K';
    }
    return '${amount < 0 ? '-' : ''}${absAmount.toStringAsFixed(0)}';
  }

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

            // 1. Filter expenses and incomes for the current month being viewed
            final monthlyExpenses = allExpenses.where((e) {
              return e.date.year == _currentMonth.year &&
                  e.date.month == _currentMonth.month &&
                  e.type == TransactionType.expense;
            }).toList();

            final monthlyIncomes = allExpenses.where((e) {
              return e.date.year == _currentMonth.year &&
                  e.date.month == _currentMonth.month &&
                  e.type == TransactionType.income;
            }).toList();

            // Aggregate spending and income amounts by day
            final dailySpending = <int, double>{};
            for (final exp in monthlyExpenses) {
              dailySpending[exp.date.day] = (dailySpending[exp.date.day] ?? 0.0) + exp.amount;
            }

            final dailyIncome = <int, double>{};
            for (final inc in monthlyIncomes) {
              dailyIncome[inc.date.day] = (dailyIncome[inc.date.day] ?? 0.0) + inc.amount;
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
                incomeAmount: 0.0,
              ));
            }

            // Add current month's cells
            for (int day = 1; day <= daysInCurrentMonth; day++) {
              cells.add(_CalendarDayItem(
                date: DateTime(_currentMonth.year, _currentMonth.month, day),
                isCurrentMonth: true,
                spendAmount: dailySpending[day] ?? 0.0,
                incomeAmount: dailyIncome[day] ?? 0.0,
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
                incomeAmount: 0.0,
              ));
            }

            // Get transactions of selected day
            final selectedDayExpenses = allExpenses.where((e) {
              return e.date.year == _selectedDate.year &&
                  e.date.month == _selectedDate.month &&
                  e.date.day == _selectedDate.day;
            }).toList();

            final double selectedDayExpenseTotal = selectedDayExpenses
                .where((e) => e.type == TransactionType.expense)
                .fold(0.0, (sum, e) => sum + e.amount);

            final double selectedDayIncomeTotal = selectedDayExpenses
                .where((e) => e.type == TransactionType.income)
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

            // Group cells into weeks (7 days each)
            final List<List<_CalendarDayItem>> weeks = [];
            for (int i = 0; i < cells.length; i += 7) {
              weeks.add(cells.sublist(i, i + 7));
            }

            return Stack(
              children: [
                CustomScrollView(
                  slivers: [
                    // ─── Top AppBar / Back Navigation ─────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(AppDimens.lg, AppDimens.md, AppDimens.lg, AppDimens.xs),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                if (context.canPop()) {
                                  context.pop();
                                } else {
                                  context.go(AppRoutes.dashboard);
                                }
                              },
                              icon: const Icon(Icons.arrow_back_ios_new_rounded),
                              iconSize: 18,
                              color: theme.colorScheme.onSurface,
                              style: IconButton.styleFrom(
                                backgroundColor: isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white,
                                padding: const EdgeInsets.all(10),
                                shadowColor: Colors.black.withOpacity(0.05),
                                elevation: 1,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              'Calendar',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF111827),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ─── Cute Capitalized Split Layout Calendar ─────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            const leftSectionPadding = EdgeInsets.only(left: 12, right: 6, top: 16, bottom: 12);
                            const rightSectionPadding = EdgeInsets.only(left: 6, right: 12, top: 16, bottom: 12);

                            return Container(
                              decoration: BoxDecoration(
                                color: isDark ? theme.colorScheme.surfaceContainer : Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: isDark ? Colors.grey[800]! : const Color(0xFFE5E7EB),
                                  width: 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.02),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  // Background custom wavy split painter
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(24),
                                      child: CustomPaint(
                                        painter: CalendarSplitBackgroundPainter(isDark: isDark),
                                      ),
                                    ),
                                  ),

                                  // Chibi watermark positioned behind the entire calendar
                                  Positioned.fill(
                                    top: 50,
                                    bottom: 10,
                                    child: IgnorePointer(
                                      child: Opacity(
                                        opacity: isDark ? 0.12 : 0.20,
                                        child: Image.asset(
                                          'assets/images/chibi_character.png',
                                          fit: BoxFit.contain,
                                          alignment: Alignment.center,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Calendar Grid Content
                                  Column(
                                    children: [
                                      // 1. Month / Year Header row
                                      Row(
                                        children: [
                                          Expanded(
                                            flex: 7,
                                            child: Padding(
                                              padding: leftSectionPadding,
                                              child: Row(
                                                children: [
                                                  IconButton(
                                                    constraints: const BoxConstraints(),
                                                    padding: EdgeInsets.zero,
                                                    icon: const Icon(Icons.chevron_left_rounded, color: Color(0xFFB91C1C), size: 28),
                                                    onPressed: _prevMonth,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    DateFormat('MMMM').format(_currentMonth).toUpperCase(),
                                                    style: const TextStyle(
                                                      color: Color(0xFFB91C1C),
                                                      fontWeight: FontWeight.w900,
                                                      fontSize: 22,
                                                      letterSpacing: 1.2,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  IconButton(
                                                    constraints: const BoxConstraints(),
                                                    padding: EdgeInsets.zero,
                                                    icon: const Icon(Icons.chevron_right_rounded, color: Color(0xFFB91C1C), size: 28),
                                                    onPressed: _nextMonth,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 3,
                                            child: Padding(
                                              padding: rightSectionPadding,
                                              child: Center(
                                                child: Text(
                                                  DateFormat('yyyy').format(_currentMonth),
                                                  style: const TextStyle(
                                                    color: Color(0xFFB91C1C),
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 22,
                                                    letterSpacing: 1.2,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 8),

                                      // 2. Weekday circle headers row
                                      Row(
                                        children: [
                                          Expanded(
                                            flex: 7,
                                            child: Padding(
                                              padding: leftSectionPadding.copyWith(top: 0, bottom: 0),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                                children: ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI'].map((day) {
                                                  final isSunday = day == 'SUN';
                                                  return Container(
                                                    width: 32,
                                                    height: 32,
                                                    decoration: BoxDecoration(
                                                      color: isSunday
                                                          ? const Color(0xFFB91C1C)
                                                          : (isDark ? const Color(0xFF854D0E) : const Color(0xFFFEF08A)),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    alignment: Alignment.center,
                                                    child: Text(
                                                      day,
                                                      style: TextStyle(
                                                        color: isSunday
                                                            ? Colors.white
                                                            : (isDark ? Colors.white : const Color(0xFF1E293B)),
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 8,
                                                      ),
                                                    ),
                                                  );
                                                }).toList(),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 3,
                                            child: Padding(
                                              padding: rightSectionPadding.copyWith(top: 0, bottom: 0),
                                              child: Center(
                                                child: Container(
                                                  width: 32,
                                                  height: 32,
                                                  decoration: const BoxDecoration(
                                                    color: Color(0xFFB91C1C),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: const Text(
                                                    'SAT',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 8,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 12),

                                      // 3. Weeks rows
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: Column(
                                          children: weeks.map((week) {
                                            final leftDays = week.sublist(0, 6);
                                            final rightDay = week[6];

                                            return Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 4),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    flex: 7,
                                                    child: Padding(
                                                      padding: leftSectionPadding.copyWith(top: 0, bottom: 0),
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                                                        children: leftDays.map((dayItem) {
                                                          return Expanded(
                                                            child: Padding(
                                                              padding: const EdgeInsets.symmetric(horizontal: 2),
                                                              child: _buildDayCell(context, dayItem),
                                                            ),
                                                          );
                                                        }).toList(),
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 3,
                                                    child: Padding(
                                                      padding: rightSectionPadding.copyWith(top: 0, bottom: 0),
                                                      child: Center(
                                                        child: _buildDayCell(context, rightDay),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // ─── Calendar Filter Segmented Control ──────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg, vertical: AppDimens.sm),
                        child: _buildFilterTabs(context),
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
                                        color: isDark ? Colors.white : const Color(0xFF111827),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Daily transaction summary',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurface.withOpacity(0.45),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Income',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: theme.colorScheme.onSurface.withOpacity(0.45),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      CurrencyFormatter.format(selectedDayIncomeTotal),
                                      style: const TextStyle(
                                        color: AppColors.income,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Expense',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: theme.colorScheme.onSurface.withOpacity(0.45),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      CurrencyFormatter.format(selectedDayExpenseTotal),
                                      style: TextStyle(
                                        color: selectedDayExpenseTotal > 0 ? AppColors.expense : (isDark ? Colors.grey[500] : const Color(0xFF9CA3AF)),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
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
                              color: isDark ? theme.colorScheme.surfaceContainer : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isDark ? Colors.grey[800]! : const Color(0xFFE5E7EB)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0x2210B981) : const Color(0xFFECFDF5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Text('😴', style: TextStyle(fontSize: 22)),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'A Perfect Saver Day!',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isDark ? Colors.white : const Color(0xFF111827),
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
                                    color: isDark ? theme.colorScheme.surfaceContainer : Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: isDark ? Colors.grey[800]! : const Color(0xFFE5E7EB)),
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
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: isDark ? Colors.white : const Color(0xFF111827),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 3),
                                            // Category Pill Badge
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isDark ? theme.colorScheme.surfaceContainerHighest : const Color(0xFFF3F4F6),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                ExpenseCategory.getLabel(expense.category),
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  color: isDark ? Colors.grey[350] : const Color(0xFF4B5563),
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
                                          color: expense.type == TransactionType.income ? AppColors.income : (isDark ? Colors.white : const Color(0xFF111827)),
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
                                color: isDark ? Colors.white : const Color(0xFF111827),
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
                              bgColor = isDark ? const Color(0x22EF4444) : const Color(0xFFFFEEEC);
                              borderColor = null;
                            } else if (index == 1) {
                              bgColor = isDark ? const Color(0x223B82F6) : const Color(0xFFE8F2FF);
                              borderColor = null;
                            } else {
                              bgColor = isDark ? theme.colorScheme.surfaceContainer : Colors.white;
                              borderColor = isDark ? Colors.grey[800] : const Color(0xFFE5E7EB);
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
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isDark ? Colors.grey[400] : const Color(0xFF4B5563),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '₹${CurrencyFormatter.formatCompact(amount).replaceAll('₹', '')}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isDark ? Colors.white : const Color(0xFF111827),
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
                            color: isDark ? const Color(0xFF332B1E) : const Color(0xFFFFF9E6), // Beige/Gold background
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFFFFC043).withOpacity(0.2) : const Color(0xFFFFD970), // Circle color
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
                                      children: [
                                        const Text('😊', style: TextStyle(fontSize: 13)),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Smart Saver',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF78350F),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    RichText(
                                      text: TextSpan(
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E),
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

  // Segmented switch selector for Expenses / Income / Total filters
  Widget _buildFilterTabs(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 40,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surfaceContainerHighest : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: CalendarFilterType.values.map((filter) {
          final isSelected = _activeFilter == filter;
          String label = '';
          Color activeColor = theme.colorScheme.primary;

          switch (filter) {
            case CalendarFilterType.expenses:
              label = 'Expenses';
              activeColor = AppColors.expense;
              break;
            case CalendarFilterType.income:
              label = 'Income';
              activeColor = AppColors.income;
              break;
            case CalendarFilterType.total:
              label = 'Total';
              activeColor = AppColors.transfer;
              break;
          }

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _activeFilter = filter;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? (isDark ? Colors.grey[800] : Colors.white) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? activeColor
                        : (isDark ? Colors.grey[400] : const Color(0xFF4B5563)),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDayCell(BuildContext context, _CalendarDayItem item) {
    if (!item.isCurrentMonth) {
      return const SizedBox(height: 55);
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isSelected = item.date.year == _selectedDate.year &&
        item.date.month == _selectedDate.month &&
        item.date.day == _selectedDate.day;

    final isToday = item.date.year == DateTime.now().year &&
        item.date.month == DateTime.now().month &&
        item.date.day == DateTime.now().day;

    final isSunday = item.date.weekday == DateTime.sunday;
    final isSaturday = item.date.weekday == DateTime.saturday;
    final isWeekend = isSunday || isSaturday;

    // Determine display amount and badge colors based on active filter
    double displayAmount = 0.0;
    Color badgeBgColor = Colors.transparent;
    Color badgeTextColor = Colors.white;

    if (_activeFilter == CalendarFilterType.expenses) {
      displayAmount = item.spendAmount;
      badgeBgColor = AppColors.expense;
    } else if (_activeFilter == CalendarFilterType.income) {
      displayAmount = item.incomeAmount;
      badgeBgColor = AppColors.income;
    } else {
      displayAmount = item.netAmount;
      if (displayAmount > 0) {
        badgeBgColor = AppColors.income;
      } else if (displayAmount < 0) {
        badgeBgColor = AppColors.expense;
      }
    }

    final cellBgColor = isSelected
        ? (isDark ? theme.colorScheme.primary.withOpacity(0.15) : const Color(0xFFE8F2FF))
        : Colors.transparent;

    final cellBorderColor = isSelected
        ? theme.colorScheme.primary
        : isToday
            ? theme.colorScheme.primary.withOpacity(0.5)
            : Colors.transparent;

    final dateColor = isWeekend
        ? const Color(0xFFB91C1C) // Red for weekend date numbers
        : (isDark ? Colors.white : const Color(0xFF111827));

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDate = item.date;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 55,
        decoration: BoxDecoration(
          color: cellBgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cellBorderColor,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              item.date.day.toString(),
              style: TextStyle(
                fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                color: dateColor,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            if (displayAmount != 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                decoration: BoxDecoration(
                  color: badgeBgColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _formatCellAmount(displayAmount),
                  style: TextStyle(
                    fontSize: 7.5,
                    fontWeight: FontWeight.w800,
                    color: badgeTextColor,
                  ),
                ),
              )
            else
              const SizedBox(height: 11), // placeholder matching height of badge
          ],
        ),
      ),
    );
  }
}

class _CalendarDayItem {
  final DateTime date;
  final bool isCurrentMonth;
  final double spendAmount;
  final double incomeAmount;

  double get netAmount => incomeAmount - spendAmount;

  _CalendarDayItem({
    required this.date,
    required this.isCurrentMonth,
    required this.spendAmount,
    required this.incomeAmount,
  });
}

class CalendarSplitBackgroundPainter extends CustomPainter {
  final bool isDark;
  CalendarSplitBackgroundPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paintLeft = Paint()
      ..color = isDark ? const Color(0xFF1E293B) : Colors.white
      ..style = PaintingStyle.fill;

    final paintRight = Paint()
      ..color = isDark ? const Color(0xFF2A3437) : const Color(0xFFD4E2E0)
      ..style = PaintingStyle.fill;

    // Draw left background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paintLeft);

    // Draw right background with wavy left edge
    final splitX = size.width * 7 / 10;
    final path = Path();
    path.moveTo(splitX, 0);

    // Create a wavy line down to the bottom
    for (double y = 0; y <= size.height; y += 10) {
      // Deterministic sine/cosine wave pattern for wavy/hand-drawn look
      final dx = math.sin(y * 0.04) * 2.5 + math.cos(y * 0.1) * 1.5;
      path.lineTo(splitX + dx, y);
    }
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 0);
    path.close();

    canvas.drawPath(path, paintRight);
  }

  @override
  bool shouldRepaint(covariant CalendarSplitBackgroundPainter oldDelegate) {
    return oldDelegate.isDark != isDark;
  }
}
