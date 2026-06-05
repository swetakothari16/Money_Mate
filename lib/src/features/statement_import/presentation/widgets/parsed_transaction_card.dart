import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/icon_mapper.dart';
import '../../../../core/utils/formatters.dart';
import '../../../categories/providers/category_providers.dart';
import '../../domain/models/parsed_transaction.dart';
import '../providers/statement_import_providers.dart';

class ParsedTransactionCard extends ConsumerWidget {
  final ParsedTransaction transaction;

  const ParsedTransactionCard({
    super.key,
    required this.transaction,
  });

  void _showCategorySelectorSheet(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.read(allExpenseCategoriesProvider);
    final notifier = ref.read(statementImportProvider.notifier);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            final theme = Theme.of(context);
            return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Pull indicator
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppDimens.md),
                      child: Text(
                        'Change Category',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: categoriesAsync.when(
                        data: (categories) => GridView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.all(AppDimens.md),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: AppDimens.md,
                            crossAxisSpacing: AppDimens.md,
                            childAspectRatio: 0.85,
                          ),
                          itemCount: categories.length,
                          itemBuilder: (context, index) {
                            final category = categories[index];
                            final isSelected = transaction.category == category.name;
                            final color = AppColors.categoryColors[
                                category.colorIndex % AppColors.categoryColors.length];

                            return InkWell(
                              onTap: () {
                                notifier.updateCategory(transaction.id, category.name);
                                Navigator.pop(context);
                              },
                              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? color.withOpacity(0.15)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                                  border: isSelected
                                      ? Border.all(color: color, width: 2)
                                      : Border.all(
                                          color: theme.colorScheme.outlineVariant.withOpacity(0.2),
                                          width: 1,
                                        ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: color.withOpacity(0.12),
                                      child: Icon(
                                        IconMapper.getIcon(
                                          category.iconName,
                                          categoryName: category.name,
                                        ),
                                        color: color,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      category.name,
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (err, _) => Center(child: Text('Error loading categories: $err')),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifier = ref.read(statementImportProvider.notifier);

    // Get current category metadata to show details
    final categoriesAsync = ref.watch(allExpenseCategoriesProvider);
    final categoryItem = categoriesAsync.maybeWhen(
      data: (list) => list.firstWhere(
        (c) => c.name == transaction.category,
        orElse: () => CategoryItem(
          name: transaction.category,
          iconName: 'more_horiz',
          colorIndex: 7,
        ),
      ),
      orElse: () => CategoryItem(
        name: transaction.category,
        iconName: 'more_horiz',
        colorIndex: 7,
      ),
    );

    final color = AppColors.categoryColors[categoryItem.colorIndex % AppColors.categoryColors.length];
    final categoryIcon = IconMapper.getIcon(categoryItem.iconName, categoryName: categoryItem.name);

    return Dismissible(
      key: ValueKey(transaction.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: AppColors.expense,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.white,
          size: 24,
        ),
      ),
      onDismissed: (_) {
        notifier.removeTransaction(transaction.id);
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: AppDimens.sm),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          side: BorderSide(
            color: transaction.isSelected
                ? theme.colorScheme.primary.withOpacity(0.3)
                : theme.colorScheme.outlineVariant.withOpacity(0.2),
            width: transaction.isSelected ? 1.5 : 1,
          ),
        ),
        color: transaction.isSelected
            ? theme.colorScheme.primaryContainer.withOpacity(0.05)
            : theme.colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.md),
          child: Row(
            children: [
              // 1. Selection Checkbox
              Checkbox(
                value: transaction.isSelected,
                activeColor: theme.colorScheme.primary,
                onChanged: (_) => notifier.toggleSelection(transaction.id),
              ),
              const SizedBox(width: AppDimens.xs),
              
              // 2. Transaction Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.merchant,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: transaction.isSelected
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          DateFormat('MMM d, yyyy').format(transaction.date),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.4),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Category Badge
                        InkWell(
                          onTap: () => _showCategorySelectorSheet(context, ref),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: color.withOpacity(0.2), width: 0.5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(categoryIcon, size: 12, color: color),
                                const SizedBox(width: 4),
                                Text(
                                  categoryItem.name[0].toUpperCase() + categoryItem.name.substring(1),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(Icons.arrow_drop_down_rounded, size: 14, color: color),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 3. Amount and Actions
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '-${CurrencyFormatter.format(transaction.amount)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: transaction.isSelected
                          ? AppColors.expense
                          : AppColors.expense.withOpacity(0.5),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: theme.colorScheme.error.withOpacity(0.6),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => notifier.removeTransaction(transaction.id),
                    tooltip: 'Exclude transaction',
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
