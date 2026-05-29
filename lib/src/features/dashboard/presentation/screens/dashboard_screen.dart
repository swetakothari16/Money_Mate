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
              // ─── Header ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.lg, AppDimens.lg, AppDimens.lg, AppDimens.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Good Morning 👋',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                              const SizedBox(height: AppDimens.xs),
                              Text(
                                'Money Mate',
                                style: theme.textTheme.displaySmall,
                              ),
                            ],
                          ),
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
                            child: Icon(
                              Icons.person_rounded,
                              color: theme.colorScheme.primary,
                            ),
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
                    data: (summary) => _buildBalanceCard(context, summary),
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

  Widget _buildBalanceCard(BuildContext context, ExpenseSummary summary) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppDimens.lg),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Total Balance',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: AppDimens.sm),
          Text(
            CurrencyFormatter.format(summary.balance),
            style: theme.textTheme.displayLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppDimens.lg),
          Row(
            children: [
              Expanded(
                child: _BalanceSummaryItem(
                  label: 'Income',
                  amount: CurrencyFormatter.formatCompact(summary.totalIncome),
                  icon: Icons.arrow_downward_rounded,
                  color: AppColors.income,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withOpacity(0.2),
              ),
              Expanded(
                child: _BalanceSummaryItem(
                  label: 'Expense',
                  amount: CurrencyFormatter.formatCompact(summary.totalExpense),
                  icon: Icons.arrow_upward_rounded,
                  color: AppColors.expense,
                ),
              ),
            ],
          ),
        ],
      ),
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
                    ? 'Over budget by ${CurrencyFormatter.format(Math.abs(status.remainingAmount))}' 
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

class _BalanceSummaryItem extends StatelessWidget {
  final String label;
  final String amount;
  final IconData icon;
  final Color color;

  const _BalanceSummaryItem({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          amount,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIncome = expense.type == TransactionType.income;
    final color = isIncome ? AppColors.income : AppColors.expense;
    
    // We use a fallback icon here. In a full app you'd map the category name to the correct icon.
    final icon = isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.sm),
      child: GlassCard(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
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
                    color: color,
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
