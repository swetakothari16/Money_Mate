import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/icon_mapper.dart';
import '../../../../core/providers/preferences_provider.dart';
import '../../../categories/providers/category_providers.dart';
import '../../data/models/budget_model.dart';
import '../../providers/budget_providers.dart';
import '../../../../core/enums/expense_category.dart';

class CategoryBudgetBottomSheet extends ConsumerStatefulWidget {
  const CategoryBudgetBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => const CategoryBudgetBottomSheet(),
    );
  }

  @override
  ConsumerState<CategoryBudgetBottomSheet> createState() => _CategoryBudgetBottomSheetState();
}

class _CategoryBudgetBottomSheetState extends ConsumerState<CategoryBudgetBottomSheet> {
  BudgetPeriod _selectedPeriod = BudgetPeriod.monthly;
  final Map<String?, TextEditingController> _controllers = {};
  bool _isSaving = false;
  bool _initialized = false;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initializeControllers(List<BudgetModel> budgets, List<CategoryItem> categories) {
    if (_initialized) return;

    // Clear old controllers
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();

    // 1. Overall Budget
    final overallBudget = budgets.firstWhere(
      (b) => b.category == null && b.period == _selectedPeriod && b.isActive,
      orElse: () => BudgetModel()..limitAmount = 0.0,
    );
    _controllers[null] = TextEditingController(
      text: overallBudget.limitAmount > 0 ? overallBudget.limitAmount.toStringAsFixed(0) : '',
    );

    // 2. Category Budgets
    for (final category in categories) {
      final categoryBudget = budgets.firstWhere(
        (b) => b.category == category.name && b.period == _selectedPeriod && b.isActive,
        orElse: () => BudgetModel()..limitAmount = 0.0,
      );
      _controllers[category.name] = TextEditingController(
        text: categoryBudget.limitAmount > 0 ? categoryBudget.limitAmount.toStringAsFixed(0) : '',
      );
    }

    _initialized = true;
  }

  void _onPeriodChanged(BudgetPeriod period) {
    setState(() {
      _selectedPeriod = period;
      _initialized = false; // Force re-initialization with new period values
    });
  }

  Future<void> _saveBudgets(List<BudgetModel> existingBudgets, List<CategoryItem> categories) async {
    setState(() {
      _isSaving = true;
    });

    try {
      final notifier = ref.read(budgetListProvider.notifier);
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

      // 1. Save Overall Budget
      final overallController = _controllers[null];
      final overallVal = overallController != null ? double.tryParse(overallController.text) ?? 0.0 : 0.0;
      final existingOverall = existingBudgets.cast<BudgetModel?>().firstWhere(
        (b) => b?.category == null && b?.period == _selectedPeriod,
        orElse: () => null,
      );

      if (overallVal > 0) {
        if (existingOverall == null) {
          await notifier.addBudget(
            name: 'Overall ${_selectedPeriod.name.capitalize()} Budget',
            limitAmount: overallVal,
            period: _selectedPeriod,
            category: null,
            startDate: startDate,
            endDate: endDate,
          );
        } else if (existingOverall.limitAmount != overallVal || !existingOverall.isActive) {
          existingOverall.limitAmount = overallVal;
          existingOverall.startDate = startDate;
          existingOverall.endDate = endDate;
          existingOverall.isActive = true;
          await notifier.updateBudget(existingOverall);
        }
      } else {
        if (existingOverall != null && existingOverall.isActive) {
          await notifier.deactivateBudget(existingOverall);
        }
      }

      // 2. Save Category Budgets
      for (final category in categories) {
        final controller = _controllers[category.name];
        final val = controller != null ? double.tryParse(controller.text) ?? 0.0 : 0.0;
        final existing = existingBudgets.cast<BudgetModel?>().firstWhere(
          (b) => b?.category == category.name && b?.period == _selectedPeriod,
          orElse: () => null,
        );

        if (val > 0) {
          final categoryLabel = category.isCustom ? category.name : ExpenseCategory.getLabel(category.name);
          if (existing == null) {
            await notifier.addBudget(
              name: '$categoryLabel Budget',
              limitAmount: val,
              period: _selectedPeriod,
              category: category.name,
              startDate: startDate,
              endDate: endDate,
            );
          } else if (existing.limitAmount != val || !existing.isActive || existing.name != '$categoryLabel Budget') {
            existing.name = '$categoryLabel Budget';
            existing.limitAmount = val;
            existing.startDate = startDate;
            existing.endDate = endDate;
            existing.isActive = true;
            await notifier.updateBudget(existing);
          }
        } else {
          if (existing != null && existing.isActive) {
            await notifier.deactivateBudget(existing);
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Budgets updated successfully'),
            backgroundColor: AppColors.income,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving budgets: $e'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final currencySymbol = ref.watch(currencySymbolProvider);
    final categoriesAsync = ref.watch(allExpenseCategoriesProvider);
    final budgetsAsync = ref.watch(budgetListProvider);

    return categoriesAsync.when(
      data: (categories) {
        return budgetsAsync.when(
          data: (budgets) {
            _initializeControllers(budgets, categories);

            return AnimatedPadding(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutQuad,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                decoration: BoxDecoration(
                  gradient: isDark ? AppColors.cardGradientDark : null,
                  color: isDark ? null : Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.08) : theme.colorScheme.outlineVariant.withOpacity(0.3),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Drag Handle
                      Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 12),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurface.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      // Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Category Budgets',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => Navigator.pop(context),
                              style: IconButton.styleFrom(
                                backgroundColor: theme.colorScheme.onSurface.withOpacity(0.05),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Period Selector Tabs
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
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
                                    padding: const EdgeInsets.symmetric(vertical: 8),
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
                                          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.6),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // List View of Budgets
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Overall Budget Tile
                              _buildBudgetRow(
                                title: 'Overall Budget',
                                icon: Icons.all_inclusive_rounded,
                                color: theme.colorScheme.primary,
                                controller: _controllers[null]!,
                                currencySymbol: currencySymbol,
                                theme: theme,
                                isOverall: true,
                              ),
                              const Divider(height: 24),
                              
                              // Categories list
                              ...categories.map((category) {
                                final color = AppColors.categoryColors[category.colorIndex % AppColors.categoryColors.length];
                                final icon = IconMapper.getIcon(category.iconName, categoryName: category.name);
                                final controller = _controllers[category.name];
                                
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _buildBudgetRow(
                                    title: category.isCustom ? category.name : ExpenseCategory.getLabel(category.name),
                                    icon: icon,
                                    color: color,
                                    controller: controller ?? TextEditingController(),
                                    currencySymbol: currencySymbol,
                                    theme: theme,
                                  ),
                                );
                              }),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),

                      // Save Button
                      Padding(
                        padding: const EdgeInsets.all(AppDimens.lg),
                        child: FilledButton(
                          onPressed: _isSaving ? null : () => _saveBudgets(budgets, categories),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Save Budgets',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          loading: () => const _LoadingWidget(),
          error: (err, _) => _ErrorWidget(message: 'Error loading budgets: $err'),
        );
      },
      loading: () => const _LoadingWidget(),
      error: (err, _) => _ErrorWidget(message: 'Error loading categories: $err'),
    );
  }

  Widget _buildBudgetRow({
    required String title,
    required IconData icon,
    required Color color,
    required TextEditingController controller,
    required String currencySymbol,
    required ThemeData theme,
    bool isOverall = false,
  }) {
    return Row(
      children: [
        // Category Icon Circle
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),

        // Category Title
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: isOverall ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),

        // Input Field
        Container(
          width: 120,
          height: 40,
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withOpacity(0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: theme.colorScheme.onSurface.withOpacity(0.08),
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 8),
              Text(
                currencySymbol,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'No Limit',
                    hintStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.only(right: 8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoadingWidget extends StatelessWidget {
  const _LoadingWidget();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 250,
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _ErrorWidget extends StatelessWidget {
  final String message;
  const _ErrorWidget({required this.message});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 250,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.lg),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
    );
  }
}

extension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
