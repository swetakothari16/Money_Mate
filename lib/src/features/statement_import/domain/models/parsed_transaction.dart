class ParsedTransaction {
  final String id;
  final DateTime date;
  final String merchant;
  final double amount;
  final String category; // Maps to ExpenseCategory name
  final bool isSelected;

  const ParsedTransaction({
    required this.id,
    required this.date,
    required this.merchant,
    required this.amount,
    required this.category,
    this.isSelected = true,
  });

  ParsedTransaction copyWith({
    String? id,
    DateTime? date,
    String? merchant,
    double? amount,
    String? category,
    bool? isSelected,
  }) {
    return ParsedTransaction(
      id: id ?? this.id,
      date: date ?? this.date,
      merchant: merchant ?? this.merchant,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParsedTransaction &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          date == other.date &&
          merchant == other.merchant &&
          amount == other.amount &&
          category == other.category &&
          isSelected == other.isSelected;

  @override
  int get hashCode =>
      id.hashCode ^
      date.hashCode ^
      merchant.hashCode ^
      amount.hashCode ^
      category.hashCode ^
      isSelected.hashCode;

  @override
  String toString() {
    return 'ParsedTransaction(id: $id, date: $date, merchant: $merchant, amount: $amount, category: $category, isSelected: $isSelected)';
  }
}
