import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
 
import '../../../../core/enums/expense_category.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/icon_mapper.dart';
import '../../providers/category_providers.dart';
import '../../../../core/providers/preferences_provider.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expenseCategoriesAsync = ref.watch(allExpenseCategoriesProvider);
    final incomeCategoriesAsync = ref.watch(allIncomeCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: const [
            Tab(text: 'Expenses'),
            Tab(text: 'Income'),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppDimens.maxContentWidth),
          child: TabBarView(
            controller: _tabController,
            children: [
              _CategoryListTab(
                categoriesAsync: expenseCategoriesAsync,
                isIncome: false,
                onAddCategory: () => _showAddCategorySheet(context, false),
              ),
              _CategoryListTab(
                categoriesAsync: incomeCategoriesAsync,
                isIncome: true,
                onAddCategory: () => _showAddCategorySheet(context, true),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCategorySheet(context, _tabController.index == 1),
        label: const Text('Add Category'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  void _showAddCategorySheet(BuildContext context, bool isIncome) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddCategoryBottomSheet(
        isIncome: isIncome,
        onSave: (name, iconName, color) async {
          await ref.read(categoryListProvider.notifier).addCategory(
                name: name,
                iconName: iconName,
                colorValue: color.value,
                isIncome: isIncome,
              );
        },
      ),
    );
  }
}

class _CategoryListTab extends ConsumerWidget {
  final AsyncValue<List<CategoryItem>> categoriesAsync;
  final bool isIncome;
  final VoidCallback onAddCategory;

  const _CategoryListTab({
    required this.categoriesAsync,
    required this.isIncome,
    required this.onAddCategory,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return categoriesAsync.when(
      data: (categories) {
        if (categories.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.category_outlined,
                  size: 64,
                  color: theme.colorScheme.onSurface.withOpacity(0.3),
                ),
                const SizedBox(height: AppDimens.md),
                Text(
                  'No categories found',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppDimens.lg),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            final color = category.isCustom
                ? Color(category.colorIndex) // Note: custom color stored in colorIndex for UI mapping as raw int value
                : AppColors.categoryColors[category.colorIndex % AppColors.categoryColors.length];
            final icon = IconMapper.getIcon(category.iconName, categoryName: category.name);

            return Card(
              margin: const EdgeInsets.only(bottom: AppDimens.sm),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withOpacity(0.12),
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: AppDimens.md, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 22, color: color),
                ),
                title: Text(
                  category.isCustom ? category.name : ExpenseCategory.getLabel(category.name),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  category.isCustom ? 'Custom Category' : 'System Category',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: theme.colorScheme.error,
                  onPressed: () => _confirmDelete(context, ref, category),
                ),
              ),
            );
          },
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('Error loading categories: $error')),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, CategoryItem category) async {
    final theme = Theme.of(context);
    final displayName = category.isCustom ? category.name : ExpenseCategory.getLabel(category.name);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Are you sure you want to delete "$displayName"? Transactions using this category will fallback to default settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: theme.colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (category.isCustom && category.customCategoryId != null) {
        await ref.read(categoryListProvider.notifier).deleteCategory(category.customCategoryId!);
      } else {
        await ref.read(deletedSystemCategoriesProvider.notifier).deleteSystemCategory(category.name);
      }
    }
  }
}

class _AddCategoryBottomSheet extends StatefulWidget {
  final bool isIncome;
  final Function(String name, String iconName, Color color) onSave;

  const _AddCategoryBottomSheet({
    required this.isIncome,
    required this.onSave,
  });

  @override
  State<_AddCategoryBottomSheet> createState() => _AddCategoryBottomSheetState();
}

class _AddCategoryBottomSheetState extends State<_AddCategoryBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  String _selectedIconName = 'restaurant';
  Color _selectedColor = AppColors.categoryColors[0];

  final List<Map<String, dynamic>> _availableIcons = [
    {'name': 'restaurant', 'label': 'Dining'},
    {'name': 'directions_car', 'label': 'Transport'},
    {'name': 'shopping_bag', 'label': 'Shopping'},
    {'name': 'movie', 'label': 'Movies'},
    {'name': 'local_hospital', 'label': 'Health'},
    {'name': 'school', 'label': 'Education'},
    {'name': 'receipt_long', 'label': 'Bills'},
    {'name': 'home', 'label': 'Rent'},
    {'name': 'local_grocery_store', 'label': 'Groceries'},
    {'name': 'flight', 'label': 'Travel'},
    {'name': 'subscriptions', 'label': 'Subs'},
    {'name': 'shield', 'label': 'Shield'},
    {'name': 'spa', 'label': 'Wellness'},
    {'name': 'card_giftcard', 'label': 'Gifts'},
    {'name': 'pets', 'label': 'Pets'},
    {'name': 'account_balance_wallet', 'label': 'Salary'},
    {'name': 'work', 'label': 'Work'},
    {'name': 'trending_up', 'label': 'Invest'},
    {'name': 'business_center', 'label': 'Business'},
    {'name': 'apartment', 'label': 'Apartment'},
  ];

  @override
  void initState() {
    super.initState();
    // Default setting preset for Income vs Expense
    _selectedIconName = widget.isIncome ? 'account_balance_wallet' : 'restaurant';
    _selectedColor = widget.isIncome ? AppColors.categoryColors[2] : AppColors.categoryColors[0];
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: AppDimens.lg,
        right: AppDimens.lg,
        top: AppDimens.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppDimens.lg,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'New ${widget.isIncome ? "Income" : "Expense"} Category',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.md),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Category Name',
                  prefixIcon: const Icon(Icons.label_outline_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a category name';
                  }
                  return null;
                },
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: AppDimens.lg),

              // ─── Icon Selection ─────────────────────────────────────────
              Text(
                'Select Icon',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppDimens.sm),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _availableIcons.length,
                  itemBuilder: (context, index) {
                    final item = _availableIcons[index];
                    final isSelected = item['name'] == _selectedIconName;
                    final iconData = IconMapper.getIcon(item['name'] as String);

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedIconName = item['name'] as String;
                        });
                      },
                      child: Container(
                        width: 60,
                        margin: const EdgeInsets.only(right: AppDimens.sm, bottom: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _selectedColor.withOpacity(0.15)
                              : theme.colorScheme.surface.withOpacity(isDark ? 0.05 : 0.5),
                          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                          border: Border.all(
                            color: isSelected ? _selectedColor : theme.colorScheme.outlineVariant.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(iconData, color: isSelected ? _selectedColor : theme.colorScheme.onSurface.withOpacity(0.6)),
                            const SizedBox(height: 4),
                            Text(
                              item['label'] as String,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 9,
                                color: isSelected ? _selectedColor : theme.colorScheme.onSurface.withOpacity(0.5),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppDimens.lg),

              // ─── Color Selection ────────────────────────────────────────
              Text(
                'Select Color',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppDimens.sm),
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: AppColors.categoryColors.length,
                  itemBuilder: (context, index) {
                    final color = AppColors.categoryColors[index];
                    final isSelected = color == _selectedColor;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedColor = color;
                        });
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        margin: const EdgeInsets.only(right: AppDimens.md),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? (isDark ? Colors.white : Colors.black87) : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: isSelected
                            ? Icon(Icons.check, color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white, size: 20)
                            : null,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppDimens.xl),

              // ─── Save Button ────────────────────────────────────────────
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    widget.onSave(_nameController.text.trim(), _selectedIconName, _selectedColor);
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  ),
                ),
                child: const Text('Save Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
