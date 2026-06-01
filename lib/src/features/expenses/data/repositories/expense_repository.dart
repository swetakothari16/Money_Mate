import 'package:isar/isar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/isar_service.dart';
import '../models/expense_model.dart';

// ═══════════════════════════════════════════════════════════════════════════
// ABSTRACT REPOSITORY
// ═══════════════════════════════════════════════════════════════════════════

/// Contract for all expense data operations.
///
/// This abstraction enables:
/// - Easy swapping between Isar (local) and a REST/GraphQL backend
/// - Clean unit testing with mock implementations
/// - Separation of data access from business logic
abstract class ExpenseRepository {
  // ─── CRUD ───────────────────────────────────────────────────────────
  Future<int> addExpense(ExpenseModel expense);
  Future<void> updateExpense(ExpenseModel expense);
  Future<bool> deleteExpense(int id);
  Future<void> deleteMultiple(List<int> ids);
  Future<ExpenseModel?> getExpenseById(int id);
  Future<ExpenseModel?> getExpenseByUuid(String uuid);

  // ─── Queries ────────────────────────────────────────────────────────
  Future<List<ExpenseModel>> getAllExpenses({int? limit, int? offset});
  Future<List<ExpenseModel>> getExpensesByType(TransactionType type);
  Future<List<ExpenseModel>> getExpensesByCategory(String category);
  Future<List<ExpenseModel>> getExpensesByDateRange(
    DateTime start,
    DateTime end, {
    TransactionType? type,
  });
  Future<List<ExpenseModel>> searchExpenses(String query);

  // ─── Aggregations ──────────────────────────────────────────────────
  Future<double> getTotalByType(TransactionType type, {DateTime? since});
  Future<double> getTotalByCategory(String category, DateTime start, DateTime end);
  Future<Map<String, double>> getCategoryBreakdown(
    DateTime start,
    DateTime end, {
    TransactionType type = TransactionType.expense,
  });
  Future<int> getTransactionCount({TransactionType? type});

  // ─── Reactive Streams ──────────────────────────────────────────────
  Stream<void> watchExpenses();
}

// ═══════════════════════════════════════════════════════════════════════════
// ISAR IMPLEMENTATION
// ═══════════════════════════════════════════════════════════════════════════

/// Production Isar-backed implementation of [ExpenseRepository].
class IsarExpenseRepository implements ExpenseRepository {
  final Isar _isar;

  IsarExpenseRepository(this._isar);

  // ─── CRUD ───────────────────────────────────────────────────────────

  @override
  Future<int> addExpense(ExpenseModel expense) async {
    late int id;
    await _isar.writeTxn(() async {
      id = await _isar.expenseModels.put(expense);
    });
    return id;
  }

  @override
  Future<void> updateExpense(ExpenseModel expense) async {
    expense.updatedAt = DateTime.now();
    await _isar.writeTxn(() async {
      await _isar.expenseModels.put(expense);
    });
  }

  @override
  Future<bool> deleteExpense(int id) async {
    late bool deleted;
    await _isar.writeTxn(() async {
      deleted = await _isar.expenseModels.delete(id);
    });
    return deleted;
  }

  @override
  Future<void> deleteMultiple(List<int> ids) async {
    await _isar.writeTxn(() async {
      await _isar.expenseModels.deleteAll(ids);
    });
  }

  @override
  Future<ExpenseModel?> getExpenseById(int id) async {
    return _isar.expenseModels.get(id);
  }

  @override
  Future<ExpenseModel?> getExpenseByUuid(String uuid) async {
    return _isar.expenseModels.filter().uuidEqualTo(uuid).findFirst();
  }

  // ─── Queries ────────────────────────────────────────────────────────

  @override
  Future<List<ExpenseModel>> getAllExpenses({int? limit, int? offset}) async {
    var query = _isar.expenseModels.where().sortByDateDesc();

    // Apply pagination if provided
    if (offset != null && limit != null) {
      return query.offset(offset).limit(limit).findAll();
    } else if (limit != null) {
      return query.limit(limit).findAll();
    }
    return query.findAll();
  }

  @override
  Future<List<ExpenseModel>> getExpensesByType(TransactionType type) async {
    return _isar.expenseModels
        .filter()
        .typeEqualTo(type)
        .sortByDateDesc()
        .findAll();
  }

  @override
  Future<List<ExpenseModel>> getExpensesByCategory(String category) async {
    return _isar.expenseModels
        .filter()
        .categoryEqualTo(category)
        .sortByDateDesc()
        .findAll();
  }

  @override
  Future<List<ExpenseModel>> getExpensesByDateRange(
    DateTime start,
    DateTime end, {
    TransactionType? type,
  }) async {
    var query = _isar.expenseModels.filter().dateBetween(start, end);

    if (type != null) {
      query = query.typeEqualTo(type);
    }

    return query.sortByDateDesc().findAll();
  }

  @override
  Future<List<ExpenseModel>> searchExpenses(String query) async {
    final lowerQuery = query.toLowerCase();
    return _isar.expenseModels
        .filter()
        .titleContains(lowerQuery, caseSensitive: false)
        .or()
        .noteContains(lowerQuery, caseSensitive: false)
        .or()
        .categoryContains(lowerQuery, caseSensitive: false)
        .sortByDateDesc()
        .findAll();
  }

  // ─── Aggregations ──────────────────────────────────────────────────

  @override
  Future<double> getTotalByType(TransactionType type, {DateTime? since}) async {
    QueryBuilder<ExpenseModel, ExpenseModel, QAfterFilterCondition> query;

    if (since != null) {
      query = _isar.expenseModels
          .filter()
          .typeEqualTo(type)
          .dateGreaterThan(since);
    } else {
      query = _isar.expenseModels.filter().typeEqualTo(type);
    }

    final results = await query.findAll();
    return results.fold<double>(0.0, (sum, e) => sum + e.amount);
  }

  @override
  Future<double> getTotalByCategory(
    String category,
    DateTime start,
    DateTime end,
  ) async {
    final results = await _isar.expenseModels
        .filter()
        .categoryEqualTo(category)
        .dateBetween(start, end)
        .findAll();
    return results.fold<double>(0.0, (sum, e) => sum + e.amount);
  }

  @override
  Future<Map<String, double>> getCategoryBreakdown(
    DateTime start,
    DateTime end, {
    TransactionType type = TransactionType.expense,
  }) async {
    final results = await _isar.expenseModels
        .filter()
        .typeEqualTo(type)
        .dateBetween(start, end)
        .findAll();

    final breakdown = <String, double>{};
    for (final expense in results) {
      breakdown[expense.category] =
          (breakdown[expense.category] ?? 0) + expense.amount;
    }
    return breakdown;
  }

  @override
  Future<int> getTransactionCount({TransactionType? type}) async {
    if (type != null) {
      return _isar.expenseModels.filter().typeEqualTo(type).count();
    }
    return _isar.expenseModels.count();
  }

  // ─── Reactive Streams ──────────────────────────────────────────────

  @override
  Stream<void> watchExpenses() {
    return _isar.expenseModels.watchLazy();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PROVIDER
// ═══════════════════════════════════════════════════════════════════════════

/// Provides the [ExpenseRepository] backed by Isar.
///
/// Usage:
/// ```dart
/// final repo = ref.watch(expenseRepositoryProvider);
/// await repo.addExpense(expense);
/// ```
final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  final isar = ref.watch(isarProvider);
  return IsarExpenseRepository(isar);
});
