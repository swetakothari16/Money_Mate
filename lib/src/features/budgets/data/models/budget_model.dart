import 'package:isar/isar.dart';

part 'budget_model.g.dart';

// ─── Budget Period ────────────────────────────────────────────────────────
/// The time window a budget covers.
enum BudgetPeriod {
  daily,
  weekly,
  monthly,
  yearly,
}

// ─── Isar Collection ──────────────────────────────────────────────────────

/// A spending limit set by the user for a specific category and period.
///
/// Design decisions:
/// - [category] is stored as a String (enum name from [ExpenseCategory])
///   so it matches the same format used in [ExpenseModel.category].
/// - A `null` [category] means "overall budget" (not category-specific).
/// - [spentAmount] is **not** stored here — it's computed at query time
///   from the expenses collection. This avoids stale data and simplifies
///   transaction delete/update flows.
/// - The [isActive] flag allows soft-disabling budgets without deletion.
@collection
class BudgetModel {
  Id id = Isar.autoIncrement;

  // ─── Core Fields ────────────────────────────────────────────────────
  /// Display name for this budget (e.g. "Monthly Groceries").
  late String name;

  /// Maximum amount allowed for the period.
  late double limitAmount;

  /// The time window this budget covers.
  @enumerated
  late BudgetPeriod period;

  /// Category this budget tracks. `null` means "total spending".
  /// Stored as [ExpenseCategory.name] string.
  String? category;

  // ─── Period Boundaries ──────────────────────────────────────────────
  /// Start date of the current budget period.
  late DateTime startDate;

  /// End date of the current budget period.
  late DateTime endDate;

  // ─── State ──────────────────────────────────────────────────────────
  /// Whether this budget is currently active.
  bool isActive = true;

  /// Whether to send a notification when approaching the limit.
  bool notifyOnThreshold = true;

  /// Alert threshold as a percentage (0.0 – 1.0). Default: 80%.
  double alertThreshold = 0.8;

  // ─── Metadata ───────────────────────────────────────────────────────
  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();

  // ─── Indexes ────────────────────────────────────────────────────────
  /// Index on period for quick lookups of all monthly/weekly budgets.
  @Index()
  short get periodIndex => period.index;

  /// Index on active state for filtering.
  @Index()
  bool get activeIndex => isActive;
}
