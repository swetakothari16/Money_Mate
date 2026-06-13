/// Predefined expense/income categories.
///
/// Each category carries metadata (icon name, default color index) that
/// the presentation layer can use to render category chips and badges.
/// The [colorIndex] maps to [AppColors.categoryColors] for consistent
/// theming across the app.
enum ExpenseCategory {
  // ─── Expense Categories ─────────────────────────────────────────────
  food('Food & Dining', 'restaurant', 0),
  transport('Transport', 'directions_car', 3),
  shopping('Shopping', 'shopping_bag', 1),
  entertainment('Entertainment', 'movie', 7),
  health('Health & Medical', 'local_hospital', 5),
  education('Education', 'school', 9),
  bills('Bills & Utilities', 'receipt_long', 4),
  rent('Rent & Housing', 'home', 0),
  groceries('Groceries', 'local_grocery_store', 2),
  travel('Travel', 'flight', 9),
  subscriptions('Subscriptions', 'subscriptions', 6),
  insurance('Insurance', 'shield', 3),
  personalCare('Personal Care', 'spa', 10),
  gifts('Gifts & Donations', 'card_giftcard', 1),
  pets('Pets', 'pets', 4),

  // ─── Income Categories ──────────────────────────────────────────────
  salary('Salary', 'account_balance_wallet', 2),
  freelance('Freelance', 'work', 6),
  investment('Investments', 'trending_up', 8),
  business('Business', 'business_center', 0),
  rental('Rental Income', 'apartment', 3),
  refund('Refund', 'replay', 9),

  // ─── General ────────────────────────────────────────────────────────
  transfer('Transfer', 'swap_horiz', 3),
  other('Other', 'more_horiz', 11);

  const ExpenseCategory(this.label, this.iconName, this.colorIndex);

  /// Human-readable display label.
  final String label;

  /// Material icon name (matches [Icons] field names).
  final String iconName;

  /// Index into [AppColors.categoryColors].
  final int colorIndex;

  /// Returns only categories typically used for expenses.
  static List<ExpenseCategory> get expenseCategories => [
        food,
        transport,
        shopping,
        entertainment,
        health,
        education,
        bills,
        rent,
        groceries,
        travel,
        subscriptions,
        insurance,
        personalCare,
        gifts,
        pets,
        other,
      ];

  /// Returns only categories typically used for income.
  static List<ExpenseCategory> get incomeCategories => [
        salary,
        freelance,
        investment,
        business,
        rental,
        refund,
        other,
      ];

  /// Returns the human-readable display label for a given category name.
  static String getLabel(String name) {
    for (final category in values) {
      if (category.name == name) {
        return category.label;
      }
    }
    return name;
  }
}
