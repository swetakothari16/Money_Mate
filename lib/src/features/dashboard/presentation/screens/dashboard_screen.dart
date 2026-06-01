import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../expenses/data/models/expense_model.dart';
import '../../../expenses/providers/expense_providers.dart';
import '../../../budgets/providers/budget_providers.dart';
import '../../../../core/utils/icon_mapper.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    final expenseSummaryAsync = ref.watch(expenseSummaryProvider);
    final todaysSpendingAsync = ref.watch(todaysSpendingProvider);
    final recentExpensesAsync = ref.watch(recentExpensesProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            // Trigger a refresh of the providers if needed.
            // Since they watch Isar, they auto-update, but we can invalidate them to force recalculation.
            ref.invalidate(expenseSummaryProvider);
            ref.invalidate(todaysSpendingProvider);
            ref.invalidate(allBudgetStatusesProvider);
            ref.invalidate(recentExpensesProvider);
          },
          child: CustomScrollView(
            slivers: [
              // ─── Header (SpendWise Logo + Welcome) ──────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.lg, AppDimens.md, AppDimens.lg, AppDimens.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // SpendWise Branding Top Bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: AppColors.income,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.bolt_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'SpendWise',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.more_vert_rounded),
                            onPressed: () {},
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Welcome Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome back,',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Alex Harrison',
                                style: theme.textTheme.headlineLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
                                backgroundImage: const NetworkImage(
                                  'https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=256',
                                ),
                                child: const Icon(Icons.person_rounded, color: AppColors.income),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: AppColors.income,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.1),
              ),

              // ─── Balance Card ────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.lg,
                    vertical: AppDimens.sm,
                  ),
                  child: expenseSummaryAsync.when(
                    data: (summary) => _buildBalanceCard(context, summary, ref),
                    loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
                    error: (e, _) => Center(child: Text('Error: $e')),
                  ).animate().fadeIn(duration: 600.ms, delay: 100.ms).slideY(begin: 0.15),
                ),
              ),

              // ─── Today's Spending ──────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg, vertical: AppDimens.sm),
                  child: todaysSpendingAsync.when(
                    data: (spent) => GlassCard(
                      padding: const EdgeInsets.all(AppDimens.md),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.expense.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.calendar_today_rounded, color: AppColors.expense, size: 20),
                              ),
                              const SizedBox(width: AppDimens.md),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Today's Spending",
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                                    ),
                                  ),
                                  Text(
                                    CurrencyFormatter.format(spent),
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ).animate().fadeIn(duration: 600.ms, delay: 150.ms),
                ),
              ),

              // ─── Budgets Section ──────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg, vertical: AppDimens.sm),
                  child: _BudgetsSection(),
                ),
              ),

              // ─── Quick Actions ───────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimens.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Actions',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppDimens.md),
                      Row(
                        children: [
                          _QuickActionButton(
                            icon: Icons.add_rounded,
                            label: 'Add',
                            gradient: AppColors.primaryGradient,
                            onTap: () => context.push(AppRoutes.addExpense),
                          ),
                          const SizedBox(width: AppDimens.md),
                          _QuickActionButton(
                            icon: Icons.pie_chart_rounded,
                            label: 'Budget',
                            gradient: AppColors.expenseGradient,
                            onTap: () => context.push(AppRoutes.addBudget),
                          ),
                          const SizedBox(width: AppDimens.md),
                          _QuickActionButton(
                            icon: Icons.swap_horiz_rounded,
                            label: 'Transfer',
                            gradient: AppColors.incomeGradient,
                            onTap: () {},
                          ),
                          const SizedBox(width: AppDimens.md),
                          _QuickActionButton(
                            icon: Icons.history_rounded,
                            label: 'History',
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFB347), Color(0xFFFF6B9D)],
                            ),
                            onTap: () => context.go(AppRoutes.transactions),
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
              ),

              // ─── Recent Transactions Header ─────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Transactions',
                        style: theme.textTheme.titleMedium,
                      ),
                      TextButton(
                        onPressed: () => context.go(AppRoutes.transactions),
                        child: Text(
                          'See All',
                          style: TextStyle(color: theme.colorScheme.primary),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 500.ms, delay: 300.ms),
              ),

              // ─── Recent Transactions List ───────────────────────────
              recentExpensesAsync.when(
                data: (expenses) {
                  if (expenses.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(AppDimens.xl),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 64,
                                color: theme.colorScheme.onSurface.withOpacity(0.2),
                              ),
                              const SizedBox(height: AppDimens.md),
                              Text(
                                'No transactions yet',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                                ),
                              ),
                              const SizedBox(height: AppDimens.xs),
                              Text(
                                'Tap + to add your first expense',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(duration: 600.ms, delay: 400.ms),
                    );
                  }
                  
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final expense = expenses[index];
                          return _TransactionTile(expense: expense)
                              .animate()
                              .fadeIn(delay: (300 + (index * 50)).ms)
                              .slideX();
                        },
                        childCount: expenses.length,
                      ),
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(
                  child: Center(child: Padding(padding: EdgeInsets.all(AppDimens.lg), child: CircularProgressIndicator())),
                ),
                error: (e, _) => SliverToBoxAdapter(
                  child: Center(child: Text('Error: $e')),
                ),
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: AppDimens.xl)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context, ExpenseSummary summary, WidgetRef ref) {
    final theme = Theme.of(context);
    final budgetsAsync = ref.watch(allBudgetStatusesProvider);
    
    // Set fallback budget if none exists
    double budgetLimit = 50000.0;
    double spentAmount = summary.totalExpense;
    double remainingAmount = budgetLimit - spentAmount;
    double progress = budgetLimit > 0 ? (spentAmount / budgetLimit) : 0.0;
    String budgetName = 'Monthly Budget';
    
    final statuses = budgetsAsync.value ?? [];
    if (statuses.isNotEmpty) {
      final status = statuses.first;
      budgetLimit = status.budget.limitAmount;
      spentAmount = status.spentAmount;
      remainingAmount = status.remainingAmount;
      progress = status.progress;
      budgetName = status.budget.name;
    }

    final percent = (progress * 100).clamp(0, 100).toInt();
    final remainingText = remainingAmount >= 0
        ? "You're on track to save ${CurrencyFormatter.format(remainingAmount)} this month"
        : "Over budget by ${CurrencyFormatter.format(remainingAmount.abs())}";

    Widget _buildStatCard(
      String label,
      double amount,
      IconData icon,
      Color color,
      Color iconBg,
    ) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: theme.cardTheme.shape is RoundedRectangleBorder
              ? Border.fromBorderSide((theme.cardTheme.shape as RoundedRectangleBorder).side)
              : Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 14),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              CurrencyFormatter.format(amount),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'INCOME',
                summary.totalIncome,
                Icons.north_east_rounded,
                AppColors.income,
                AppColors.income.withOpacity(0.12),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'EXPENSES',
                summary.totalExpense,
                Icons.south_east_rounded,
                AppColors.expense,
                AppColors.expense.withOpacity(0.12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primarySeed.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    budgetName.toUpperCase(),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '8 days left',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                CurrencyFormatter.format(budgetLimit),
                style: theme.textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Spent: ${CurrencyFormatter.format(spentAmount)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '$percent%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: Colors.white.withOpacity(0.25),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      remainingText,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Private Widgets ─────────────────────────────────────────────────────

class _BudgetsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final budgetsAsync = ref.watch(allBudgetStatusesProvider);

    return budgetsAsync.when(
      data: (statuses) {
        if (statuses.isEmpty) {
          return GlassCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('No active budgets', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text('Set a budget to track spending', style: theme.textTheme.bodySmall),
                  ],
                ),
                FilledButton.tonal(
                  onPressed: () => context.push(AppRoutes.addBudget),
                  child: const Text('Setup'),
                ),
              ],
            ),
          );
        }

        // Just show the first/top budget as a featured progress bar for the dashboard
        final status = statuses.first;
        final color = status.isOverBudget ? AppColors.expense : (status.isNearThreshold ? Colors.orange : AppColors.income);

        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    status.budget.name,
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    '${CurrencyFormatter.formatCompact(status.spentAmount)} / ${CurrencyFormatter.formatCompact(status.budget.limitAmount)}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                child: LinearProgressIndicator(
                  value: status.progress.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              const SizedBox(height: AppDimens.sm),
              Text(
                status.isOverBudget 
                    ? 'Over budget by ${CurrencyFormatter.format(status.remainingAmount.abs())}' 
                    : '${CurrencyFormatter.format(status.remainingAmount)} remaining',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
      error: (e, _) => GlassCard(child: Text('Error loading budgets: $e')),
    );
  }
}

// Math class is not imported by default in flutter/material, so we need to use `.abs()`
extension DoubleAbs on double {
  double abs() => this < 0 ? -this : this;
}
class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                boxShadow: [
                  BoxShadow(
                    color: gradient.colors.first.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: AppDimens.sm),
            Text(
              label,
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final ExpenseModel expense;

  const _TransactionTile({required this.expense});

  Color _getColorForCategory(String name, Color defaultColor) {
    switch (name.toLowerCase()) {
      case 'food':
      case 'food & dining':
      case 'food & drinks':
        return const Color(0xFFF59E0B); // Amber/Orange
      case 'transport':
      case 'transportation':
        return const Color(0xFF3B82F6); // Blue
      case 'shopping':
        return const Color(0xFFEC4899); // Pink
      case 'entertainment':
        return const Color(0xFF8B5CF6); // Purple
      case 'health':
      case 'health & medical':
        return const Color(0xFF06B6D4); // Cyan
      case 'bills':
      case 'bills & utilities':
        return const Color(0xFFEF4444); // Red
      case 'rent':
      case 'rent & housing':
      case 'housing':
        return const Color(0xFF14B8A6); // Teal
      case 'salary':
        return const Color(0xFF10B981); // Emerald Green
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
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    expense.category,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isIncome ? '+' : '-'}${CurrencyFormatter.format(expense.amount)}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: isIncome ? AppColors.income : AppColors.expense,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormatter.relative(expense.date),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
