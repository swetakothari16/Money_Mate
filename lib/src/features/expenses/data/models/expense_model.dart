import 'package:isar/isar.dart';

part 'expense_model.g.dart';

// ─── Transaction Type ─────────────────────────────────────────────────────
/// Defines the direction of a financial transaction.
enum TransactionType {
  income,
  expense,
  transfer,
}

// ─── Payment Method ───────────────────────────────────────────────────────
/// How the transaction was paid. Useful for filtering and reporting.
enum PaymentMethod {
  cash,
  creditCard,
  debitCard,
  bankTransfer,
  upi,
  wallet,
  other,
}

// ─── Isar Collection ──────────────────────────────────────────────────────

/// Core financial transaction entity stored in Isar.
///
/// Design decisions:
/// - [category] is stored as a String (enum name) rather than a linked
///   collection so that the predefined [ExpenseCategory] enum remains
///   the single source of truth. Custom user categories can be added later
///   via the [CategoryModel] collection and linked by [customCategoryId].
/// - Composite indexes on [date] + [type] enable efficient monthly/weekly
///   aggregation queries that power the analytics screens.
/// - [uuid] is indexed uniquely to support future cloud sync & dedup.
@collection
class ExpenseModel {
  Id id = Isar.autoIncrement;

  // ─── Core Fields ────────────────────────────────────────────────────
  /// Short description of the transaction (e.g. "Coffee at Starbucks").
  late String title;

  /// Absolute monetary value. Always positive; [type] determines sign.
  late double amount;

  /// When the transaction occurred (user-selected, not creation time).
  @Index()
  late DateTime date;

  /// Income, Expense, or Transfer.
  @enumerated
  late TransactionType type;

  /// Category from the predefined [ExpenseCategory] enum.
  /// Stored as the enum's `.name` string for forward compatibility.
  @Index()
  late String category;

  // ─── Optional Details ───────────────────────────────────────────────
  /// Free-form note or memo.
  String? note;

  /// How this transaction was paid.
  @enumerated
  PaymentMethod paymentMethod = PaymentMethod.cash;

  /// Optional link to a user-created custom category.
  int? customCategoryId;

  /// Optional tags for filtering (e.g. ["vacation", "food"]).
  List<String> tags = [];

  /// Whether this is a recurring transaction.
  bool isRecurring = false;

  /// Optional path to an attached receipt image.
  String? receiptPath;

  // ─── Metadata ───────────────────────────────────────────────────────
  /// Universally unique identifier for sync/export/dedup.
  @Index(unique: true)
  late String uuid;

  /// When this record was first created.
  DateTime createdAt = DateTime.now();

  /// When this record was last modified.
  DateTime updatedAt = DateTime.now();

  // ─── Composite Indexes ──────────────────────────────────────────────
  // Enables fast queries like "all expenses this month" or
  // "income by category in date range".

  /// Composite index: filter by type then sort/filter by date.
  @Index(composite: [CompositeIndex('date')])
  short get typeDate => type.index;

  /// Composite index: filter by category then sort/filter by date.
  @Index(composite: [CompositeIndex('date')])
  String get categoryDate => category;

  /// Convert model to a map for Firestore upload.
  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'type': type.name,
      'category': category,
      'note': note,
      'paymentMethod': paymentMethod.name,
      'customCategoryId': customCategoryId,
      'tags': tags,
      'isRecurring': isRecurring,
      'receiptPath': receiptPath,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create model from a Firestore map.
  static ExpenseModel fromMap(Map<String, dynamic> map) {
    final model = ExpenseModel()
      ..uuid = map['uuid'] as String
      ..title = map['title'] as String
      ..amount = (map['amount'] as num).toDouble()
      ..date = DateTime.parse(map['date'] as String)
      ..type = TransactionType.values.firstWhere(
        (e) => e.name == map['type'] as String,
        orElse: () => TransactionType.expense,
      )
      ..category = map['category'] as String
      ..note = map['note'] as String?
      ..paymentMethod = PaymentMethod.values.firstWhere(
        (e) => e.name == map['paymentMethod'] as String,
        orElse: () => PaymentMethod.cash,
      )
      ..customCategoryId = map['customCategoryId'] as int?
      ..tags = List<String>.from(map['tags'] ?? [])
      ..isRecurring = map['isRecurring'] as bool? ?? false
      ..receiptPath = map['receiptPath'] as String?
      ..createdAt = DateTime.parse(map['createdAt'] as String? ?? DateTime.now().toIso8601String())
      ..updatedAt = DateTime.parse(map['updatedAt'] as String? ?? DateTime.now().toIso8601String());
    return model;
  }
}
