import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../data/models/budget_model.dart';
import '../../providers/budget_providers.dart';
import '../../../categories/providers/category_providers.dart';

class AddBudgetScreen extends ConsumerStatefulWidget {
  const AddBudgetScreen({super.key});

  @override
  ConsumerState<AddBudgetScreen> createState() => _AddBudgetScreenState();
}

class _AddBudgetScreenState extends ConsumerState<AddBudgetScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _amountController = TextEditingController();

  BudgetPeriod _selectedPeriod = BudgetPeriod.monthly;
  CategoryItem? _selectedCategory; // null = Overall Budget
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _showCategoryPicker() {
    final categoriesAsync = ref.read(allExpenseCategoriesProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppDimens.md),
                    child: Text(
                      'Select Category',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  // Option for "Overall Budget"
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                      child: Icon(Icons.all_inclusive, color: Theme.of(context).colorScheme.primary),
                    ),
                    title: const Text('Overall Budget (All Categories)'),
                    onTap: () {
                      setState(() {
                        _selectedCategory = null;
                        if (_nameController.text.isEmpty) {
                          _nameController.text = 'Overall ${_selectedPeriod.name.capitalize()} Budget';
                        }
                      });
                      Navigator.pop(context);
                    },
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
                        ),
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          final isSelected = _selectedCategory?.name == category.name;
                          final color = AppColors.categoryColors[category.colorIndex % AppColors.categoryColors.length];

                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedCategory = category;
                                if (_nameController.text.isEmpty || _nameController.text.startsWith('Overall')) {
                                  _nameController.text = '${category.name} Budget';
                                }
                              });
                              Navigator.pop(context);
                            },
                            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
                                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                                border: isSelected ? Border.all(color: color, width: 2) : null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: color.withOpacity(0.15),
                                    child: Icon(Icons.category, color: color, size: 20),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    category.name,
                                    style: Theme.of(context).textTheme.labelSmall,
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
                      error: (err, _) => const Center(child: Text('Error loading categories')),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveBudget() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final amount = double.parse(_amountController.text);
      
      // Determine start/end dates based on period
      final now = DateTime.now();
      DateTime start;
      DateTime end;
      
      switch (_selectedPeriod) {
        case BudgetPeriod.monthly:
          start = DateTime(now.year, now.month, 1);
          end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
          break;
        case BudgetPeriod.weekly:
          final diff = now.weekday - DateTime.monday;
          start = DateTime(now.year, now.month, now.day - diff);
          end = start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
          break;
        case BudgetPeriod.daily:
          start = DateTime(now.year, now.month, now.day);
          end = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case BudgetPeriod.yearly:
          start = DateTime(now.year, 1, 1);
          end = DateTime(now.year, 12, 31, 23, 59, 59);
          break;
      }

      await ref.read(budgetListProvider.notifier).addBudget(
        name: _nameController.text.trim(),
        limitAmount: amount,
        period: _selectedPeriod,
        category: _selectedCategory?.name,
        startDate: start,
        endDate: end,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Budget created successfully'),
            backgroundColor: AppColors.income,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
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

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Create Budget'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimens.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Amount Input ───────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    Text(
                      'Budget Limit',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppDimens.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '\$',
                          style: theme.textTheme.displayMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.4),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IntrinsicWidth(
                          child: TextFormField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: theme.textTheme.displayLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                            decoration: const InputDecoration(
                              hintText: '0.00',
                              border: InputBorder.none,
                              filled: false,
                              contentPadding: EdgeInsets.zero,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Enter limit';
                              if (double.tryParse(value) == null) return 'Invalid amount';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimens.xl),

              // ─── Period Selector ──────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
                child: Row(
                  children: BudgetPeriod.values.map((period) {
                    final isSelected = _selectedPeriod == period;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedPeriod = period),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? theme.colorScheme.primary.withOpacity(0.15) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: isSelected
                                ? Border.all(color: theme.colorScheme.primary.withOpacity(0.4))
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              period.name.capitalize(),
                              style: TextStyle(
                                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.5),
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: AppDimens.xl),

              // ─── Category Selector ──────────────────────────────────
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
                tileColor: theme.inputDecorationTheme.fillColor,
                leading: Icon(_selectedCategory == null ? Icons.all_inclusive : Icons.category_outlined),
                title: Text(
                  _selectedCategory?.name ?? 'Overall Budget',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: _selectedCategory == null ? FontWeight.w600 : null,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _showCategoryPicker,
              ),

              const SizedBox(height: AppDimens.md),

              // ─── Name Field ────────────────────────────────────────
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Budget Name',
                  prefixIcon: const Icon(Icons.edit_outlined),
                  labelStyle: theme.textTheme.bodyMedium,
                ),
                validator: (value) => value == null || value.trim().isEmpty ? 'Enter a name' : null,
              ),

              const SizedBox(height: AppDimens.xl),

              // ─── Save Button ────────────────────────────────────────
              FilledButton(
                onPressed: _isSaving ? null : _saveBudget,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Create Budget',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
