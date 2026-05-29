import 'package:isar/isar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/isar_service.dart';
import '../models/category_model.dart';

// ═══════════════════════════════════════════════════════════════════════════
// ABSTRACT REPOSITORY
// ═══════════════════════════════════════════════════════════════════════════

/// Contract for custom category data operations.
///
/// Note: Predefined categories live in [ExpenseCategory] enum and don't
/// require repository access. This repository handles **user-created**
/// custom categories only.
abstract class CategoryRepository {
  Future<int> addCategory(CategoryModel category);
  Future<void> updateCategory(CategoryModel category);
  Future<bool> deleteCategory(int id);
  Future<CategoryModel?> getCategoryById(int id);
  Future<CategoryModel?> getCategoryByName(String name);
  Future<List<CategoryModel>> getAllCategories();
  Future<List<CategoryModel>> getCategoriesByType({required bool isIncome});
  Stream<void> watchCategories();
}

// ═══════════════════════════════════════════════════════════════════════════
// ISAR IMPLEMENTATION
// ═══════════════════════════════════════════════════════════════════════════

class IsarCategoryRepository implements CategoryRepository {
  final Isar _isar;

  IsarCategoryRepository(this._isar);

  @override
  Future<int> addCategory(CategoryModel category) async {
    late int id;
    await _isar.writeTxn(() async {
      id = await _isar.categoryModels.put(category);
    });
    return id;
  }

  @override
  Future<void> updateCategory(CategoryModel category) async {
    await _isar.writeTxn(() async {
      await _isar.categoryModels.put(category);
    });
  }

  @override
  Future<bool> deleteCategory(int id) async {
    late bool deleted;
    await _isar.writeTxn(() async {
      deleted = await _isar.categoryModels.delete(id);
    });
    return deleted;
  }

  @override
  Future<CategoryModel?> getCategoryById(int id) async {
    return _isar.categoryModels.get(id);
  }

  @override
  Future<CategoryModel?> getCategoryByName(String name) async {
    return _isar.categoryModels.filter().nameEqualTo(name).findFirst();
  }

  @override
  Future<List<CategoryModel>> getAllCategories() async {
    return _isar.categoryModels.where().sortBySortOrder().findAll();
  }

  @override
  Future<List<CategoryModel>> getCategoriesByType({
    required bool isIncome,
  }) async {
    return _isar.categoryModels
        .filter()
        .isIncomeEqualTo(isIncome)
        .sortBySortOrder()
        .findAll();
  }

  @override
  Stream<void> watchCategories() {
    return _isar.categoryModels.watchLazy();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PROVIDER
// ═══════════════════════════════════════════════════════════════════════════

/// Provides the [CategoryRepository] backed by Isar.
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final isar = ref.watch(isarProvider);
  return IsarCategoryRepository(isar);
});
