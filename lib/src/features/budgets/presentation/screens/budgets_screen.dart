import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/providers/preferences_provider.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../data/models/budget_model.dart';
import '../../providers/budget_providers.dart';
import '../widgets/category_budget_bottom_sheet.dart';
import '../../../../core/utils/icon_mapper.dart';
import '../../../categories/providers/category_providers.dart';

class BudgetsScreen extends ConsumerStatefulWidget {
  const BudgetsScreen({super.key});

  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen> {
  BudgetPeriod _selectedPeriod = BudgetPeriod.monthly;

  void _onPeriodChanged(BudgetPeriod period) {
    setState(() {
      _selectedPeriod = period;
    });
  }

  void _showSetLimitDialog({
    required BuildContext context,
    required WidgetRef ref,
    required String? categoryName, // null = Overall Budget
    required BudgetStatus? status, // null = new budget
    required String currencySymbol,
  }) {
    final initialVal = status != null ? status.budget.limitAmount.toStringAsFixed(0) : '';
    final controller = TextEditingController(text: initialVal);
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final titleText = status != null ? 'Edit' : 'Set';
        final displayName = categoryName ?? 'Overall';

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          ),
          title: Text(
            '$titleText $displayName Budget',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Set your limit for the ${_selectedPeriod.name} period.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: const TextStyle(fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  prefixText: '$currencySymbol ',
                  labelText: 'Budget Limit',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final val = double.tryParse(controller.text);
                if (val != null && val >= 0) {
                  if (status != null) {
                    final budget = status.budget;
                    budget.limitAmount = val;
                    budget.updatedAt = DateTime.now();
                    if (val == 0) {
                      await ref.read(budgetListProvider.notifier).deactivateBudget(budget);
                    } else {
                      await ref.read(budgetListProvider.notifier).updateBudget(budget);
                    }
                  } else {
                    if (val > 0) {
                      final now = DateTime.now();
                      DateTime startDate;
                      DateTime endDate;

                      switch (_selectedPeriod) {
                        case BudgetPeriod.monthly:
                          startDate = DateTime(now.year, now.month, 1);
                          endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
                          break;
                        case BudgetPeriod.weekly:
                          final diff = now.weekday - DateTime.monday;
                          startDate = DateTime(now.year, now.month, now.day - diff);
                          endDate = startDate.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
                          break;
                        case BudgetPeriod.daily:
                          startDate = DateTime(now.year, now.month, now.day);
                          endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
                          break;
                        case BudgetPeriod.yearly:
                          startDate = DateTime(now.year, 1, 1);
                          endDate = DateTime(now.year, 12, 31, 23, 59, 59);
                          break;
                      }

                      await ref.read(budgetListProvider.notifier).addBudget(
                        name: categoryName != null ? '$categoryName Budget' : 'Overall ${_selectedPeriod.name.capitalize()} Budget',
                        limitAmount: val,
                        period: _selectedPeriod,
                        category: categoryName,
                        startDate: startDate,
                        endDate: endDate,
                      );
                    }
                  }

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(val == 0 ? 'Budget deactivated' : 'Budget saved successfully'),
                        backgroundColor: AppColors.income,
                      ),
                    );
                    ref.invalidate(allBudgetStatusesProvider);
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActiveBudgetCard({
    required BuildContext context,
    required BudgetStatus status,
    required Color color,
    required IconData icon,
    required String currencySymbol,
    required ThemeData theme,
  }) {
    final budget = status.budget;
    final isCategoryOverall = budget.category == null;
    final budgetProgressColor = status.isOverBudget
        ? AppColors.expense
        : (status.isNearThreshold ? Colors.orange : AppColors.income);

    return GlassCard(
      padding: const EdgeInsets.all(AppDimens.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      budget.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      isCategoryOverall ? 'Overall budget limit' : 'Category budget limit',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${CurrencyFormatter.formatCompact(status.spentAmount)} / ${CurrencyFormatter.formatCompact(budget.limitAmount)}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                  size: 20,
                ),
                onSelected: (value) async {
                  if (value == 'edit') {
                    _showSetLimitDialog(
                      context: context,
                      ref: ref,
                      categoryName: budget.category,
                      status: status,
                      currencySymbol: currencySymbol,
                    );
                  } else if (value == 'deactivate') {
                    await ref.read(budgetListProvider.notifier).deactivateBudget(budget);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Budget deactivated'),
                          backgroundColor: AppColors.income,
                        ),
                      );
                      ref.invalidate(allBudgetStatusesProvider);
                    }
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Edit Limit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'deactivate',
                    child: Row(
                      children: [
                        Icon(Icons.power_settings_new_rounded, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Deactivate', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimens.radiusFull),
            child: LinearProgressIndicator(
              value: status.progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              valueColor: AlwaysStoppedAnimation<Color>(budgetProgressColor),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(status.progress * 100).clamp(0.0, 100.0).toStringAsFixed(0)}% used',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                status.isOverBudget
                    ? 'Over budget by ${CurrencyFormatter.format(status.remainingAmount.abs())}'
                    : '${CurrencyFormatter.format(status.remainingAmount)} remaining',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: budgetProgressColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUnsetBudgetCard({
    required BuildContext context,
    required String? categoryName, // null = Overall Budget
    required Color color,
    required IconData icon,
    required String currencySymbol,
    required ThemeData theme,
  }) {
    final displayName = categoryName ?? 'Overall Budget';

    return GlassCard(
      padding: const EdgeInsets.all(AppDimens.md),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color.withOpacity(0.6), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                Text(
                  'No limit set for this ${_selectedPeriod.name}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.35),
                  ),
                ),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: () => _showSetLimitDialog(
              context: context,
              ref: ref,
              categoryName: categoryName,
              status: null,
              currencySymbol: currencySymbol,
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, size: 16),
                SizedBox(width: 4),
                Text('Limit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currencySymbol = ref.watch(currencySymbolProvider);
    final categoriesAsync = ref.watch(allExpenseCategoriesProvider);
    final budgetsAsync = ref.watch(allBudgetStatusesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Budgets',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Configure Limits',
            onPressed: () => CategoryBudgetBottomSheet.show(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'addBudget',
        onPressed: () => context.push(AppRoutes.addBudget),
        child: const Icon(Icons.add_rounded, size: 28),
      ).animate().scale(
            duration: 400.ms,
            curve: Curves.elasticOut,
          ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(allBudgetStatusesProvider);
            ref.invalidate(budgetListProvider);
            ref.invalidate(categoryListProvider);
          },
          child: categoriesAsync.when(
            data: (categories) {
              return budgetsAsync.when(
                data: (statuses) {
                  // Filter active budgets for the selected period
                  final budgetsForPeriod = statuses.where((status) => status.budget.period == _selectedPeriod).toList();

                  // Calculate overall summary metrics
                  final overallStatus = budgetsForPeriod.cast<BudgetStatus?>().firstWhere(
                        (status) => status?.budget.category == null,
                        orElse: () => null,
                      );

                  final categoryStatuses = budgetsForPeriod.where((status) => status.budget.category != null).toList();

                  double totalLimit = 0.0;
                  double totalSpent = 0.0;

                  if (overallStatus != null) {
                    totalLimit = overallStatus.budget.limitAmount;
                    totalSpent = overallStatus.spentAmount;
                  } else {
                    totalLimit = categoryStatuses.fold(0.0, (sum, s) => sum + s.budget.limitAmount);
                    totalSpent = categoryStatuses.fold(0.0, (sum, s) => sum + s.spentAmount);
                  }

                  final totalRemaining = totalLimit - totalSpent;
                  final overallProgress = totalLimit > 0 ? (totalSpent / totalLimit) : 0.0;
                  final percent = (overallProgress * 100).clamp(0, 100).toInt();

                  final isOverBudget = totalSpent > totalLimit && totalLimit > 0;
                  final isNearLimit = overallProgress >= 0.8 && !isOverBudget && totalLimit > 0;

                  final summaryColor = isOverBudget
                      ? AppColors.expense
                      : (isNearLimit ? Colors.orange : AppColors.income);

                  // Construct the unified list of budgets and unset categories
                  final listChildren = <Widget>[];

                  // 1. Overall Budget Row
                  if (overallStatus != null) {
                    listChildren.add(
                      _buildActiveBudgetCard(
                        context: context,
                        status: overallStatus,
                        color: theme.colorScheme.primary,
                        icon: Icons.all_inclusive_rounded,
                        currencySymbol: currencySymbol,
                        theme: theme,
                      ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.05, duration: 300.ms),
                    );
                  } else {
                    listChildren.add(
                      _buildUnsetBudgetCard(
                        context: context,
                        categoryName: null,
                        color: theme.colorScheme.primary,
                        icon: Icons.all_inclusive_rounded,
                        currencySymbol: currencySymbol,
                        theme: theme,
                      ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.05, duration: 300.ms),
                    );
                  }

                  listChildren.add(const SizedBox(height: 20));

                  // Divider Header
                  listChildren.add(
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 12),
                      child: Text(
                        'Category Budgets',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );

                  // 2. Category list rows one by one
                  for (int i = 0; i < categories.length; i++) {
                    final category = categories[i];
                    final categoryColor = AppColors.categoryColors[i % AppColors.categoryColors.length];
                    final categoryIcon = IconMapper.getIcon(category.iconName, categoryName: category.name);

                    final status = budgetsForPeriod.cast<BudgetStatus?>().firstWhere(
                          (status) => status?.budget.category == category.name,
                          orElse: () => null,
                        );

                    Widget card;
                    if (status != null) {
                      card = _buildActiveBudgetCard(
                        context: context,
                        status: status,
                        color: categoryColor,
                        icon: categoryIcon,
                        currencySymbol: currencySymbol,
                        theme: theme,
                      );
                    } else {
                      card = _buildUnsetBudgetCard(
                        context: context,
                        categoryName: category.name,
                        color: categoryColor,
                        icon: categoryIcon,
                        currencySymbol: currencySymbol,
                        theme: theme,
                      );
                    }

                    listChildren.add(
                      card.animate().fadeIn(delay: (200 + (i * 30)).ms).slideY(begin: 0.05, duration: 300.ms),
                    );

                    if (i < categories.length - 1) {
                      listChildren.add(const SizedBox(height: 12));
                    }
                  }

                  return CustomScrollView(
                    slivers: [
                      // ─── Period Selector ──────────────────────────────────────
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg, vertical: AppDimens.sm),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onSurface.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: BudgetPeriod.values.map((period) {
                                final isSelected = _selectedPeriod == period;
                                return Expanded(
                                  child: InkWell(
                                    onTap: () => _onPeriodChanged(period),
                                    borderRadius: BorderRadius.circular(8),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? theme.colorScheme.primary.withOpacity(0.15)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: Text(
                                          period.name.capitalize(),
                                          style: theme.textTheme.labelMedium?.copyWith(
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                            color: isSelected
                                                ? theme.colorScheme.primary
                                                : theme.colorScheme.onSurface.withOpacity(0.6),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ).animate().fadeIn(duration: 400.ms),
                      ),

                      // ─── Hero Summary Card ────────────────────────────────────
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg, vertical: AppDimens.sm),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: isDark ? AppColors.cardGradientDark : null,
                              color: isDark ? null : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withOpacity(0.06)
                                    : theme.colorScheme.outlineVariant.withOpacity(0.3),
                              ),
                              boxShadow: isDark
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.03),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TOTAL ${_selectedPeriod.name.toUpperCase()} BUDGET',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      CurrencyFormatter.format(totalLimit),
                                      style: theme.textTheme.headlineLarge?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: summaryColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '$percent%',
                                        style: TextStyle(
                                          color: summaryColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Spent: ${CurrencyFormatter.format(totalSpent)}',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      isOverBudget
                                          ? 'Over by ${CurrencyFormatter.format(totalRemaining.abs())}'
                                          : 'Left: ${CurrencyFormatter.format(totalRemaining)}',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: isOverBudget ? AppColors.expense : AppColors.income,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: LinearProgressIndicator(
                                    value: totalLimit > 0 ? overallProgress.clamp(0.0, 1.0) : 0.0,
                                    minHeight: 10,
                                    backgroundColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
                                    valueColor: AlwaysStoppedAnimation<Color>(summaryColor),
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(duration: 500.ms, delay: 100.ms).slideY(begin: 0.1),
                        ),
                      ),

                      // ─── Budgets List ─────────────────────────────────────────
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg, vertical: AppDimens.md),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate(listChildren),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 80)),
                    ],
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (e, _) => Center(
                  child: Text('Error loading budgets: $e'),
                ),
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (e, _) => Center(
              child: Text('Error loading categories: $e'),
            ),
          ),
        ),
      ),
    );
  }
}

extension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }
}
