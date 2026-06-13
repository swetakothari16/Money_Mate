import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/cute_character_blob.dart';
import '../../../expenses/data/models/expense_model.dart';
import '../../../expenses/providers/expense_providers.dart';
import '../../../budgets/data/models/budget_model.dart';
import '../../../budgets/providers/budget_providers.dart';
import '../../../../core/utils/icon_mapper.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _currentMonth = DateTime.now();
  DateTime _selectedDate = DateTime.now();
  bool _showLegend = false;

  // Navigate to previous month
  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
      // Reset selected date to 1st of the new month to keep context valid
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cute Spends Calendar'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(_showLegend ? Icons.info_rounded : Icons.info_outline_rounded),
            tooltip: 'Show Legend',
            onPressed: () {
              setState(() {
                _showLegend = !_showLegend;
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: expensesAsync.when(
          data: (allExpenses) {
            // 1. Calculate the daily budget limit dynamically
            final budgetStatuses = budgetsAsync.value ?? [];
            final overallMonthlyBudget = budgetStatuses.cast<BudgetStatus?>().firstWhere(
              (status) => status != null && status.budget.category == null && status.budget.period == BudgetPeriod.monthly,
              orElse: () => null,
            );

            final int daysInCurrentMonth = _getDaysInMonth(_currentMonth);
            final double dailyLimit = overallMonthlyBudget != null
                ? (overallMonthlyBudget.budget.limitAmount / daysInCurrentMonth)
                : 1500.0; // Default fallback to 1500 units

            // 2. Filter expenses for the current month being viewed
            final monthlyExpenses = allExpenses.where((e) {
              return e.date.year == _currentMonth.year &&
                  e.date.month == _currentMonth.month &&
                  e.type == TransactionType.expense;
            }).toList();

            // 3. Aggregate spending amounts by day
            final dailySpending = <int, double>{};
            for (final exp in monthlyExpenses) {
              dailySpending[exp.date.day] = (dailySpending[exp.date.day] ?? 0.0) + exp.amount;
            }

            // Calculate total spent in this month
            final double totalMonthSpent = monthlyExpenses.fold(0.0, (sum, exp) => sum + exp.amount);
            final double averageDailySpent = daysInCurrentMonth > 0 ? (totalMonthSpent / daysInCurrentMonth) : 0.0;

            // 4. Construct Calendar grid items
            final firstWeekday = _getFirstWeekdayOfMonth(_currentMonth);
            
            // Assume Monday is first day of the week (standard Flutter calendar)
            // Padding days from previous month
            final int prevMonthPaddingCount = firstWeekday - 1; 
            final prevMonthDateTime = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
            final int daysInPrevMonth = _getDaysInMonth(prevMonthDateTime);

            final List<_CalendarDayItem> cells = [];

            // Add previous month's padding cells
            for (int i = prevMonthPaddingCount - 1; i >= 0; i--) {
              final dayNum = daysInPrevMonth - i;
              cells.add(_CalendarDayItem(
                date: DateTime(prevMonthDateTime.year, prevMonthDateTime.month, dayNum),
                isCurrentMonth: false,
                spendAmount: 0.0, // Don't highlight other months' spending here
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

            // Fill next month's padding cells to make a neat grid (multiples of 7)
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

            // Ensure grid always shows 5 or 6 complete rows (minimum 35, ideally fills grid)
            if (cells.length < 35) {
              final diff = 35 - cells.length;
              final offset = cells.last.date.day;
              for (int day = 1; day <= diff; day++) {
                cells.add(_CalendarDayItem(
                  date: DateTime(nextMonthDateTime.year, nextMonthDateTime.month, offset + day),
                  isCurrentMonth: false,
                  spendAmount: 0.0,
                ));
              }
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

            return CustomScrollView(
              slivers: [
                // ─── Monthly Stats Card ──────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimens.md),
                    child: Column(
                      children: [
                        // Month navigator
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left_rounded, size: 28),
                              onPressed: _prevMonth,
                            ),
                            Text(
                              DateFormat('MMMM yyyy').format(_currentMonth),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right_rounded, size: 28),
                              onPressed: _nextMonth,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Monthly Spending Glass Card
                        GlassCard(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'MONTH TOTAL',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    CurrencyFormatter.format(totalMonthSpent),
                                    style: theme.textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.expense,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                width: 1.5,
                                height: 40,
                                color: theme.colorScheme.outlineVariant.withOpacity(0.4),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'DAILY AVG',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    CurrencyFormatter.format(averageDailySpent),
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ─── Character Legend (Collapsible Info) ────────────────────
                if (_showLegend)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
                      child: Container(
                        padding: const EdgeInsets.all(AppDimens.md),
                        margin: const EdgeInsets.only(bottom: AppDimens.md),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Meet Your Spending Blobs',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildLegendItem(
                              context,
                              level: SpendLevel.saver,
                              amount: 0,
                              limit: dailyLimit,
                              title: 'Saver (₹0)',
                              desc: 'Peaceful sleeping blob. You spent absolutely nothing today!',
                            ),
                            const Divider(height: 16),
                            _buildLegendItem(
                              context,
                              level: SpendLevel.happy,
                              amount: dailyLimit * 0.2,
                              limit: dailyLimit,
                              title: 'Happy (< 40%)',
                              desc: 'Cheerful green blob. Great work keeping expenses light!',
                            ),
                            const Divider(height: 16),
                            _buildLegendItem(
                              context,
                              level: SpendLevel.neutral,
                              amount: dailyLimit * 0.6,
                              limit: dailyLimit,
                              title: 'Neutral (40% - 90%)',
                              desc: 'Curious yellow blob. Standard day with average spending.',
                            ),
                            const Divider(height: 16),
                            _buildLegendItem(
                              context,
                              level: SpendLevel.shocked,
                              amount: dailyLimit * 1.1,
                              limit: dailyLimit,
                              title: 'Shocked (> 90%)',
                              desc: 'Sweating red blob. Watch out, you are near or over budget!',
                            ),
                          ],
                        ),
                      ).animate().slideY(begin: -0.1).fadeIn(),
                    ),
                  ),

                // ─── Weekday Headers ─────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) {
                        return SizedBox(
                          width: 44,
                          child: Center(
                            child: Text(
                              day,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.4),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 6)),

                // ─── Calendar Grid ───────────────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 0.72, // Taller to fit date, blob, and spend label
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

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedDate = item.date;
                              // Also sync month header if tapping padded days
                              if (item.date.month != _currentMonth.month) {
                                _currentMonth = DateTime(item.date.year, item.date.month, 1);
                              }
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.colorScheme.primary.withOpacity(0.12)
                                  : isToday
                                      ? theme.colorScheme.primary.withOpacity(0.04)
                                      : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : isToday
                                        ? theme.colorScheme.primary.withOpacity(0.4)
                                        : Colors.transparent,
                                width: isSelected ? 1.8 : 1.0,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Day number
                                Text(
                                  item.date.day.toString(),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                                    color: item.isCurrentMonth
                                        ? theme.colorScheme.onSurface
                                        : theme.colorScheme.onSurface.withOpacity(0.25),
                                    fontSize: 13,
                                  ),
                                ),

                                // Cute Character Blob
                                Expanded(
                                  child: Center(
                                    child: Opacity(
                                      opacity: item.isCurrentMonth ? 1.0 : 0.4,
                                      child: CuteCharacterBlob(
                                        amount: item.spendAmount,
                                        limit: dailyLimit,
                                        size: 28,
                                        animate: item.isCurrentMonth, // Only animate current month
                                      ),
                                    ),
                                  ),
                                ),

                                // Spend Amount indicator
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                                    child: Text(
                                      item.spendAmount > 0
                                          ? CurrencyFormatter.formatCompact(item.spendAmount)
                                          : '₹0',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: item.spendAmount > 0
                                            ? AppColors.expense.withOpacity(item.isCurrentMonth ? 0.95 : 0.4)
                                            : theme.colorScheme.onSurface.withOpacity(item.isCurrentMonth ? 0.35 : 0.15),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: cells.length,
                    ),
                  ),
                ),
                
                // ─── Selected Day Summary ────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimens.md),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('EEEE, MMM d').format(_selectedDate),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (selectedDayTotal > 0)
                          Text(
                            'Spent: ${CurrencyFormatter.format(selectedDayTotal)}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: AppColors.expense,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // ─── Daily Transaction List ──────────────────────────────────
                if (selectedDayExpenses.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppDimens.md, vertical: 24),
                      child: GlassCard(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          children: [
                            CuteCharacterBlob(
                              amount: 0.0,
                              limit: dailyLimit,
                              size: 72,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'A Perfect Saver Day!',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'No spending records found for this day.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.5),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final expense = selectedDayExpenses[index];
                          return _TransactionRow(expense: expense);
                        },
                        childCount: selectedDayExpenses.length,
                      ),
                    ),
                  ),

                // ─── Add Expense Action ──────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimens.lg),
                    child: FilledButton.icon(
                      onPressed: () {
                        // Push to add transaction screen, passing the selected date
                        context.push(AppRoutes.addExpense, extra: _selectedDate);
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: Text(
                        'Add Spend for ${DateFormat('MMM d').format(_selectedDate)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SliverToBoxAdapter(child: SizedBox(height: AppDimens.xxl)),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error loading calendar: $err')),
        ),
      ),
    );
  }

  // Legend helper widget
  Widget _buildLegendItem(
    BuildContext context, {
    required SpendLevel level,
    required double amount,
    required double limit,
    required String title,
    required String desc,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        CuteCharacterBlob(
          amount: amount,
          limit: limit,
          size: 32,
          animate: false,
        ),
        const SizedBox(width: AppDimens.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ],
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

class _TransactionRow extends StatelessWidget {
  final ExpenseModel expense;

  const _TransactionRow({required this.expense});

  Color _getColorForCategory(String name, Color defaultColor) {
    switch (name.toLowerCase()) {
      case 'food':
      case 'food & dining':
      case 'food & drinks':
        return const Color(0xFFF59E0B);
      case 'transport':
      case 'transportation':
        return const Color(0xFF3B82F6);
      case 'shopping':
        return const Color(0xFFEC4899);
      case 'entertainment':
        return const Color(0xFF8B5CF6);
      case 'health':
      case 'health & medical':
        return const Color(0xFF06B6D4);
      case 'bills':
      case 'bills & utilities':
        return const Color(0xFFEF4444);
      case 'rent':
      case 'rent & housing':
      case 'housing':
        return const Color(0xFF14B8A6);
      case 'salary':
        return const Color(0xFF10B981);
      default:
        return defaultColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIncome = expense.type == TransactionType.income;
    final defaultColor = isIncome ? AppColors.income : AppColors.expense;
    final color = _getColorForCategory(expense.category, defaultColor);
    final icon = IconMapper.getIcon(null, categoryName: expense.category);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.sm),
      child: GlassCard(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: AppDimens.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    expense.category,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppDimens.md),
            Text(
              '${isIncome ? '+' : '-'}${CurrencyFormatter.format(expense.amount)}',
              style: theme.textTheme.titleSmall?.copyWith(
                color: isIncome ? AppColors.income : AppColors.expense,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
