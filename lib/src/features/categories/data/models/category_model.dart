import 'package:isar/isar.dart';

part 'category_model.g.dart';

/// User-created custom categories that extend the predefined [ExpenseCategory] enum.
///
/// This collection is for **custom** categories only. Predefined categories
/// live in [ExpenseCategory] and don't need database storage. When an
/// [ExpenseModel] uses a custom category, it sets [ExpenseModel.customCategoryId]
/// to this model's [id] and [ExpenseModel.category] to `'custom'`.
@collection
class CategoryModel {
  Id id = Isar.autoIncrement;

  // ─── Core Fields ────────────────────────────────────────────────────
  /// Display name (e.g. "Side Hustle", "Crypto").
  @Index(unique: true)
  late String name;

  /// Material icon name as string (e.g. 'restaurant', 'flight').
  late String iconName;

  /// Color stored as ARGB int (use `Color(colorValue)` to reconstruct).
  late int colorValue;

  // ─── Metadata ───────────────────────────────────────────────────────
  /// Whether this category was created by the system during first launch.
  bool isDefault = false;

  /// Whether this category is for income (`true`) or expense (`false`).
  bool isIncome = false;

  /// Ordering index for manual sort in the category picker.
  int sortOrder = 0;

  DateTime createdAt = DateTime.now();
}
