import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums/expense_category.dart';
import '../categories/data/models/category_model.dart';
import '../categories/data/repositories/category_repository.dart';

// ═══════════════════════════════════════════════════════════════════════════
// CUSTOM CATEGORY LIST PROVIDER
// ═══════════════════════════════════════════════════════════════════════════

/// Manages user-created custom categories.
class CategoryListNotifier extends AsyncNotifier<List<CategoryModel>> {
  late final CategoryRepository _repository;
  StreamSubscription<void>? _watchSubscription;

  @override
  Future<List<CategoryModel>> build() async {
    _repository = ref.watch(categoryRepositoryProvider);

    _watchSubscription?.cancel();
    _watchSubscription = _repository.watchCategories().listen((_) {
      _refetch();
    });
    ref.onDispose(() => _watchSubscription?.cancel());

    return _repository.getAllCategories();
  }

  Future<void> _refetch() async {
    state = AsyncData(await _repository.getAllCategories());
  }

  /// Adds a new custom category.
  Future<int> addCategory({
    required String name,
    required String iconName,
    required int colorValue,
    bool isIncome = false,
  }) async {
    final category = CategoryModel()
      ..name = name
      ..iconName = iconName
      ..colorValue = colorValue
      ..isIncome = isIncome
      ..createdAt = DateTime.now();

    return _repository.addCategory(category);
  }

  Future<void> updateCategory(CategoryModel category) async {
    await _repository.updateCategory(category);
  }

  Future<bool> deleteCategory(int id) async {
    return _repository.deleteCategory(id);
  }
}

/// Custom categories list provider.
final categoryListProvider =
    AsyncNotifierProvider<CategoryListNotifier, List<CategoryModel>>(
  CategoryListNotifier.new,
);

// ═══════════════════════════════════════════════════════════════════════════
// COMBINED CATEGORY PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

/// Combines predefined [ExpenseCategory] entries with user-created
/// custom categories into a unified list for the category picker.
///
/// Each item is represented as a [CategoryItem] which abstracts over
/// both enum-based and database-based categories.
class CategoryItem {
  final String name;
  final String iconName;
  final int colorIndex;
  final int? customCategoryId;
  final bool isCustom;

  const CategoryItem({
    required this.name,
    required this.iconName,
    required this.colorIndex,
    this.customCategoryId,
    this.isCustom = false,
  });

  /// Creates from a predefined enum value.
  factory CategoryItem.fromEnum(ExpenseCategory category) => CategoryItem(
        name: category.name,
        iconName: category.iconName,
        colorIndex: category.colorIndex,
      );

  /// Creates from a database model.
  factory CategoryItem.fromModel(CategoryModel model) => CategoryItem(
        name: model.name,
        iconName: model.iconName,
        colorIndex: 0, // Custom categories store full color, not index
        customCategoryId: model.id,
        isCustom: true,
      );
}

/// Provides all expense categories (predefined + custom) for the picker.
final allExpenseCategoriesProvider = Provider<AsyncValue<List<CategoryItem>>>((ref) {
  final customCategoriesAsync = ref.watch(categoryListProvider);

  return customCategoriesAsync.whenData((customCategories) {
    final items = <CategoryItem>[];

    // Add predefined expense categories
    for (final category in ExpenseCategory.expenseCategories) {
      items.add(CategoryItem.fromEnum(category));
    }

    // Add custom expense categories
    for (final custom in customCategories.where((c) => !c.isIncome)) {
      items.add(CategoryItem.fromModel(custom));
    }

    return items;
  });
});

/// Provides all income categories (predefined + custom) for the picker.
final allIncomeCategoriesProvider = Provider<AsyncValue<List<CategoryItem>>>((ref) {
  final customCategoriesAsync = ref.watch(categoryListProvider);

  return customCategoriesAsync.whenData((customCategories) {
    final items = <CategoryItem>[];

    // Add predefined income categories
    for (final category in ExpenseCategory.incomeCategories) {
      items.add(CategoryItem.fromEnum(category));
    }

    // Add custom income categories
    for (final custom in customCategories.where((c) => c.isIncome)) {
      items.add(CategoryItem.fromModel(custom));
    }

    return items;
  });
});
