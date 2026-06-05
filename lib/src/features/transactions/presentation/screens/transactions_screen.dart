import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/icon_mapper.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../expenses/data/models/expense_model.dart';
import '../../../expenses/providers/expense_providers.dart';
import '../../../categories/providers/category_providers.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    ref.read(expenseSearchQueryProvider.notifier).state = _searchController.text;
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return const _FilterBottomSheet();
      },
    );
  }

  String _formatSectionHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final compareDate = DateTime(date.year, date.month, date.day);

    if (compareDate == today) {
      return 'TODAY';
    } else if (compareDate == yesterday) {
      return 'YESTERDAY';
    } else {
      return DateFormat('MMMM d, yyyy').format(date).toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupedExpensesAsync = ref.watch(groupedExpensesProvider);
    final activeTypeFilter = ref.watch(expenseTypeFilterProvider);
    final activeCategoryFilter = ref.watch(expenseCategoryFilterProvider);
    final activeDateRangeFilter = ref.watch(expenseDateRangeProvider);

    final hasActiveFilters = activeTypeFilter != null ||
        activeCategoryFilter != null ||
        activeDateRangeFilter != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        centerTitle: false,
        actions: [
          if (hasActiveFilters)
            IconButton(
              icon: const Icon(Icons.filter_alt_off_rounded, color: AppColors.expense),
              tooltip: 'Clear Filters',
              onPressed: () {
                ref.read(expenseTypeFilterProvider.notifier).state = null;
                ref.read(expenseCategoryFilterProvider.notifier).state = null;
                ref.read(expenseDateRangeProvider.notifier).state = null;
              },
            ),
          IconButton(
            icon: const Icon(Icons.upload_file_rounded),
            tooltip: 'Import Statement',
            onPressed: () => context.push(AppRoutes.statementImport),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ─── Search and Advanced Filter Bar ───────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg, vertical: AppDimens.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.inputDecorationTheme.fillColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withOpacity(0.2),
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        decoration: InputDecoration(
                          hintText: 'Search transactions...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 20),
                                  onPressed: () {
                                    _searchController.clear();
                                    _searchFocusNode.unfocus();
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimens.md),
                  // Filter button
                  Material(
                    color: hasActiveFilters
                        ? AppColors.income.withOpacity(0.15)
                        : theme.inputDecorationTheme.fillColor,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: _showFilterSheet,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: hasActiveFilters
                                ? AppColors.income
                                : theme.colorScheme.outlineVariant.withOpacity(0.2),
                          ),
                        ),
                        child: Icon(
                          Icons.tune_rounded,
                          color: hasActiveFilters ? AppColors.income : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ─── Quick Filter Chips (Income, Expense, Transfer) ───────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg, vertical: AppDimens.xs),
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    isSelected: activeTypeFilter == null,
                    onSelected: () => ref.read(expenseTypeFilterProvider.notifier).state = null,
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Income',
                    isSelected: activeTypeFilter == TransactionType.income,
                    onSelected: () => ref.read(expenseTypeFilterProvider.notifier).state = TransactionType.income,
                    selectedColor: AppColors.income,
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Expenses',
                    isSelected: activeTypeFilter == TransactionType.expense,
                    onSelected: () => ref.read(expenseTypeFilterProvider.notifier).state = TransactionType.expense,
                    selectedColor: AppColors.expense,
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Transfers',
                    isSelected: activeTypeFilter == TransactionType.transfer,
                    onSelected: () => ref.read(expenseTypeFilterProvider.notifier).state = TransactionType.transfer,
                    selectedColor: AppColors.transfer,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ─── Grouped Expenses List ───────────────────────────
            Expanded(
              child: groupedExpensesAsync.when(
                data: (groupedMap) {
                  if (groupedMap.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 72,
                            color: theme.colorScheme.onSurface.withOpacity(0.15),
                          ),
                          const SizedBox(height: AppDimens.md),
                          Text(
                            hasActiveFilters || _searchController.text.isNotEmpty
                                ? 'No matching transactions'
                                : 'No transactions yet',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                          const SizedBox(height: AppDimens.xs),
                          Text(
                            hasActiveFilters || _searchController.text.isNotEmpty
                                ? 'Try adjusting your search or filters'
                                : 'Your transactions will appear here',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    );
                  }

                  final sortedDates = groupedMap.keys.toList()
                    ..sort((a, b) => b.compareTo(a)); // Newest dates first

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
                    itemCount: sortedDates.length,
                    itemBuilder: (context, dateIndex) {
                      final date = sortedDates[dateIndex];
                      final list = groupedMap[date]!;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Section Date Header
                          Padding(
                            padding: const EdgeInsets.only(top: AppDimens.md, bottom: AppDimens.sm),
                            child: Text(
                              _formatSectionHeader(date),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.4),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          // List of transactions for this date
                          ...list.map((expense) => _DismissibleTransactionTile(
                                expense: expense,
                                key: ValueKey(expense.uuid),
                              )),
                        ],
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error loading transactions: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;
  final Color? selectedColor;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selectedColor ?? theme.colorScheme.primary;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : theme.colorScheme.onSurface.withOpacity(0.8),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        fontSize: 13,
      ),
      selectedColor: color,
      backgroundColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? color : theme.colorScheme.outlineVariant.withOpacity(0.1),
        ),
      ),
      showCheckmark: false,
    );
  }
}

class _DismissibleTransactionTile extends ConsumerWidget {
  final ExpenseModel expense;

  const _DismissibleTransactionTile({
    super.key,
    required this.expense,
  });

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
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isIncome = expense.type == TransactionType.income;
    final defaultColor = isIncome ? AppColors.income : AppColors.expense;
    final color = _getColorForCategory(expense.category, defaultColor);
    final icon = IconMapper.getIcon(null, categoryName: expense.category);

    return Dismissible(
      key: ValueKey(expense.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: AppColors.expense,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
      onDismissed: (direction) async {
        final notifier = ref.read(expenseListProvider.notifier);

        // Cache data for undo
        final cachedTitle = expense.title;
        final cachedAmount = expense.amount;
        final cachedDate = expense.date;
        final cachedType = expense.type;
        final cachedCategory = expense.category;
        final cachedNote = expense.note;

        // Delete from database
        await notifier.deleteExpense(expense.id);

        if (context.mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"${cachedTitle}" deleted'),
              action: SnackBarAction(
                label: 'Undo',
                textColor: AppColors.income,
                onPressed: () async {
                  await notifier.addExpense(
                    title: cachedTitle,
                    amount: cachedAmount,
                    date: cachedDate,
                    type: cachedType,
                    category: cachedCategory,
                    note: cachedNote,
                  );
                },
              ),
            ),
          );
        }
      },
      child: Padding(
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
                    if (expense.note != null && expense.note!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        expense.note!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          color: theme.colorScheme.onSurface.withOpacity(0.4),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppDimens.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isIncome ? '+' : '-'}${CurrencyFormatter.format(expense.amount)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: isIncome ? AppColors.income : AppColors.expense,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterBottomSheet extends ConsumerWidget {
  const _FilterBottomSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final activeCategoryFilter = ref.watch(expenseCategoryFilterProvider);
    final activeDateRangeFilter = ref.watch(expenseDateRangeProvider);
    final categoriesAsync = ref.watch(allExpenseCategoriesProvider);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppDimens.lg,
        AppDimens.md,
        AppDimens.lg,
        MediaQuery.of(context).padding.bottom + AppDimens.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filters',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ref.read(expenseCategoryFilterProvider.notifier).state = null;
                    ref.read(expenseDateRangeProvider.notifier).state = null;
                    Navigator.pop(context);
                  },
                  child: const Text('Reset All'),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 12),

            // Date Range Section
            Text(
              'Date Range',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2101),
                        initialDateRange: activeDateRangeFilter,
                      );
                      if (picked != null) {
                        ref.read(expenseDateRangeProvider.notifier).state = picked;
                      }
                    },
                    icon: const Icon(Icons.date_range_rounded, size: 16),
                    label: Text(
                      activeDateRangeFilter == null
                          ? 'Select Date Range'
                          : '${DateFormat.yMMMd().format(activeDateRangeFilter.start)} - ${DateFormat.yMMMd().format(activeDateRangeFilter.end)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                if (activeDateRangeFilter != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.clear_rounded, color: AppColors.expense),
                    onPressed: () => ref.read(expenseDateRangeProvider.notifier).state = null,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),

            // Category Filter Section
            Text(
              'Category',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            categoriesAsync.when(
              data: (categories) {
                // Deduplicate categories by name
                final uniqueCategories = <String, CategoryItem>{};
                for (final cat in categories) {
                  uniqueCategories[cat.name] = cat;
                }
                final list = uniqueCategories.values.toList();

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: list.map((category) {
                    final isSelected = activeCategoryFilter == category.name;
                    final color = AppColors.categoryColors[category.colorIndex % AppColors.categoryColors.length];

                    return ChoiceChip(
                      label: Text(category.name),
                      selected: isSelected,
                      onSelected: (selected) {
                        ref.read(expenseCategoryFilterProvider.notifier).state =
                            selected ? category.name : null;
                      },
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : theme.colorScheme.onSurface.withOpacity(0.8),
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      selectedColor: color,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? color : theme.colorScheme.outlineVariant.withOpacity(0.1),
                        ),
                      ),
                      showCheckmark: false,
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => const Text('Error loading categories'),
            ),
            const SizedBox(height: 24),

            // Apply Button
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Apply Filters',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
