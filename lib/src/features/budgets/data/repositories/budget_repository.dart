import 'package:isar/isar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/isar_service.dart';
import '../models/budget_model.dart';

// ═══════════════════════════════════════════════════════════════════════════
// ABSTRACT REPOSITORY
// ═══════════════════════════════════════════════════════════════════════════

/// Contract for all budget data operations.
abstract class BudgetRepository {
  // ─── CRUD ───────────────────────────────────────────────────────────
  Future<int> addBudget(BudgetModel budget);
  Future<void> updateBudget(BudgetModel budget);
  Future<bool> deleteBudget(int id);
  Future<BudgetModel?> getBudgetById(int id);

  // ─── Queries ────────────────────────────────────────────────────────
  Future<List<BudgetModel>> getAllBudgets();
  Future<List<BudgetModel>> getActiveBudgets();
  Future<BudgetModel?> getBudgetByCategory(String category);
  Future<List<BudgetModel>> getBudgetsByPeriod(BudgetPeriod period);

  // ─── Reactive Streams ──────────────────────────────────────────────
  Stream<void> watchBudgets();
}

// ═══════════════════════════════════════════════════════════════════════════
// ISAR IMPLEMENTATION
// ═══════════════════════════════════════════════════════════════════════════

/// Production Isar-backed implementation of [BudgetRepository].
class IsarBudgetRepository implements BudgetRepository {
  final Isar _isar;

  IsarBudgetRepository(this._isar);

  // ─── CRUD ───────────────────────────────────────────────────────────

  @override
  Future<int> addBudget(BudgetModel budget) async {
    late int id;
    await _isar.writeTxn(() async {
      id = await _isar.budgetModels.put(budget);
    });
    return id;
  }

  @override
  Future<void> updateBudget(BudgetModel budget) async {
    budget.updatedAt = DateTime.now();
    await _isar.writeTxn(() async {
      await _isar.budgetModels.put(budget);
    });
  }

  @override
  Future<bool> deleteBudget(int id) async {
    late bool deleted;
    await _isar.writeTxn(() async {
      deleted = await _isar.budgetModels.delete(id);
    });
    return deleted;
  }

  @override
  Future<BudgetModel?> getBudgetById(int id) async {
    return _isar.budgetModels.get(id);
  }

  // ─── Queries ────────────────────────────────────────────────────────

  @override
  Future<List<BudgetModel>> getAllBudgets() async {
    return _isar.budgetModels.where().findAll();
  }

  @override
  Future<List<BudgetModel>> getActiveBudgets() async {
    return _isar.budgetModels
        .filter()
        .isActiveEqualTo(true)
        .findAll();
  }

  @override
  Future<BudgetModel?> getBudgetByCategory(String category) async {
    return _isar.budgetModels
        .filter()
        .categoryEqualTo(category)
        .isActiveEqualTo(true)
        .findFirst();
  }

  @override
  Future<List<BudgetModel>> getBudgetsByPeriod(BudgetPeriod period) async {
    return _isar.budgetModels
        .filter()
        .periodEqualTo(period)
        .isActiveEqualTo(true)
        .findAll();
  }

  // ─── Reactive Streams ──────────────────────────────────────────────

  @override
  Stream<void> watchBudgets() {
    return _isar.budgetModels.watchLazy();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PROVIDER
// ═══════════════════════════════════════════════════════════════════════════

/// Provides the [BudgetRepository] backed by Isar.
final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  final isar = ref.watch(isarProvider);
  return IsarBudgetRepository(isar);
});
