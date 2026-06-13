import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../data/models/expense_model.dart';
import '../../providers/expense_providers.dart';
import '../../../categories/providers/category_providers.dart';
import '../../../../core/utils/icon_mapper.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  final DateTime? initialDate;

  const AddExpenseScreen({super.key, this.initialDate});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  
  TransactionType _selectedType = TransactionType.expense;
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  
  late DateTime _selectedDate;
  CategoryItem? _selectedCategory;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _showCategoryPicker() {
    final categoriesAsync = _selectedType == TransactionType.income
        ? ref.read(allIncomeCategoriesProvider)
        : ref.read(allExpenseCategoriesProvider);

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
                          // Mapping string iconName to actual IconData is omitted for brevity,
                          // we'll just use a fallback icon for now, or match some common ones.
                          // A full app would have a map of string -> IconData.
                          final color = AppColors.categoryColors[category.colorIndex % AppColors.categoryColors.length];
                          
                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedCategory = category;
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
                                    child: Icon(
                                      IconMapper.getIcon(category.iconName, categoryName: category.name),
                                      color: color,
                                      size: 20,
                                    ),
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
                      error: (err, _) => Center(child: Text('Error loading categories')),
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

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final amount = double.parse(_amountController.text);
      
      await ref.read(expenseListProvider.notifier).addExpense(
        title: _titleController.text.trim(),
        amount: amount,
        date: _selectedDate,
        type: _selectedType,
        category: _selectedCategory!.name,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved successfully'),
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
        title: const Text('Add Transaction'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimens.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Type Selector ──────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
                child: Row(
                  children: [
                    _TypeTab(
                      label: 'Income',
                      isSelected: _selectedType == TransactionType.income,
                      color: AppColors.income,
                      onTap: () => setState(() {
                        _selectedType = TransactionType.income;
                        _selectedCategory = null;
                      }),
                    ),
                    _TypeTab(
                      label: 'Expense',
                      isSelected: _selectedType == TransactionType.expense,
                      color: AppColors.expense,
                      onTap: () => setState(() {
                        _selectedType = TransactionType.expense;
                        _selectedCategory = null;
                      }),
                    ),
                    _TypeTab(
                      label: 'Transfer',
                      isSelected: _selectedType == TransactionType.transfer,
                      color: AppColors.transfer,
                      onTap: () => setState(() {
                        _selectedType = TransactionType.transfer;
                        _selectedCategory = null;
                      }),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimens.xl),

              // ─── Amount Input ───────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    Text(
                      'Amount',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppDimens.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '₹',
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
                              if (value == null || value.isEmpty) return 'Enter amount';
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

              // ─── Title Field ────────────────────────────────────────
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  prefixIcon: const Icon(Icons.edit_outlined),
                  labelStyle: theme.textTheme.bodyMedium,
                ),
                validator: (value) => value == null || value.trim().isEmpty ? 'Enter a title' : null,
              ),

              const SizedBox(height: AppDimens.md),

              // ─── Category Selector ──────────────────────────────────
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
                tileColor: theme.inputDecorationTheme.fillColor,
                leading: _selectedCategory != null
                    ? Icon(
                        IconMapper.getIcon(_selectedCategory!.iconName, categoryName: _selectedCategory!.name),
                        color: AppColors.categoryColors[_selectedCategory!.colorIndex % AppColors.categoryColors.length],
                      )
                    : const Icon(Icons.category_outlined),
                title: Text(
                  _selectedCategory?.name ?? 'Select Category',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _selectedCategory == null ? theme.colorScheme.onSurface.withOpacity(0.5) : null,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _showCategoryPicker,
              ),

              const SizedBox(height: AppDimens.md),

              // ─── Date Selector ──────────────────────────────────────
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
                tileColor: theme.inputDecorationTheme.fillColor,
                leading: const Icon(Icons.calendar_today_outlined),
                title: Text('Date', style: theme.textTheme.bodyMedium),
                trailing: Text(
                  DateFormat.yMMMd().format(_selectedDate),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                onTap: () => _selectDate(context),
              ),

              const SizedBox(height: AppDimens.md),

              // ─── Note Field ─────────────────────────────────────────
              TextField(
                controller: _noteController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Note (optional)',
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 48),
                    child: Icon(Icons.notes_outlined),
                  ),
                  alignLabelWithHint: true,
                  labelStyle: theme.textTheme.bodyMedium,
                ),
              ),

              const SizedBox(height: AppDimens.xl),

              // ─── Save Button ────────────────────────────────────────
              FilledButton(
                onPressed: _isSaving ? null : _saveExpense,
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
                        'Save Transaction',
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

// ─── Private Widget ──────────────────────────────────────────────────────

class _TypeTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _TypeTab({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(color: color.withOpacity(0.4))
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
