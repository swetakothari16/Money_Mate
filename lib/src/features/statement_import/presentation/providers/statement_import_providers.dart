import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as orgPdf;

import '../../../../core/database/isar_service.dart';
import '../../../../core/enums/expense_category.dart';
import '../../../expenses/data/models/expense_model.dart';
import '../../data/services/pdf_parser_service.dart';
import '../../data/services/transaction_extractor_service.dart';
import '../../data/services/category_mapping_service.dart';
import '../../domain/models/parsed_transaction.dart';

// State definition for the statement import
enum StatementImportStatus {
  idle,
  parsing,
  preview,
  importing,
  success,
  error,
  passwordRequired,
}

class StatementImportState {
  final StatementImportStatus status;
  final List<ParsedTransaction> transactions;
  final String? errorMessage;
  final String? fileName;
  final int importedCount;
  final Uint8List? fileBytes;

  const StatementImportState({
    required this.status,
    this.transactions = const [],
    this.errorMessage,
    this.fileName,
    this.importedCount = 0,
    this.fileBytes,
  });

  StatementImportState copyWith({
    StatementImportStatus? status,
    List<ParsedTransaction>? transactions,
    String? errorMessage,
    String? fileName,
    int? importedCount,
    Uint8List? fileBytes,
  }) {
    return StatementImportState(
      status: status ?? this.status,
      transactions: transactions ?? this.transactions,
      errorMessage: errorMessage ?? this.errorMessage,
      fileName: fileName ?? this.fileName,
      importedCount: importedCount ?? this.importedCount,
      fileBytes: fileBytes ?? this.fileBytes,
    );
  }
}

// Service Providers
final pdfParserServiceProvider = Provider<PdfParserService>((ref) {
  return const SyncfusionPdfParserService();
});

final transactionExtractorServiceProvider = Provider<TransactionExtractorService>((ref) {
  return const RegExTransactionExtractorService();
});

final categoryMappingServiceProvider = Provider<CategoryMappingService>((ref) {
  return const RuleBasedCategoryMappingService();
});

// State Notifier Provider
class StatementImportNotifier extends StateNotifier<StatementImportState> {
  final PdfParserService _pdfParser;
  final TransactionExtractorService _extractor;
  final CategoryMappingService _categoryMapper;
  final Ref _ref;

  StatementImportNotifier({
    required PdfParserService pdfParser,
    required TransactionExtractorService extractor,
    required CategoryMappingService categoryMapper,
    required Ref ref,
  })  : _pdfParser = pdfParser,
        _extractor = extractor,
        _categoryMapper = categoryMapper,
        _ref = ref,
        super(const StatementImportState(status: StatementImportStatus.idle));

  void reset() {
    state = const StatementImportState(status: StatementImportStatus.idle);
  }

  // Pick PDF using File Picker and Parse
  Future<void> pickAndParseFile() async {
    state = state.copyWith(status: StatementImportStatus.parsing);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null || result.files.isEmpty) {
        state = state.copyWith(status: StatementImportStatus.idle);
        return;
      }

      final file = result.files.first;
      final fileName = file.name;

      if (file.extension?.toLowerCase() != 'pdf') {
        throw const FormatException('Selected file is not a PDF statement.');
      }

      Uint8List? fileBytes = file.bytes;
      if (fileBytes == null && file.path != null) {
        final localFile = File(file.path!);
        if (await localFile.exists()) {
          fileBytes = await localFile.readAsBytes();
        }
      }

      if (fileBytes == null) {
        throw const FormatException('Could not read file bytes.');
      }

      state = state.copyWith(fileBytes: fileBytes, fileName: fileName);

      await _parsePdfBytes(fileBytes, fileName);
    } catch (e) {
      if (e.toString().contains('PASSWORD_REQUIRED')) {
        state = state.copyWith(
          status: StatementImportStatus.passwordRequired,
          errorMessage: 'This statement is password protected. Please enter the password to open it.',
        );
      } else {
        state = state.copyWith(
          status: StatementImportStatus.error,
          errorMessage: e.toString(),
        );
      }
    }
  }

  // Parse with password input
  Future<void> parseWithPassword(String password) async {
    final bytes = state.fileBytes;
    final name = state.fileName;
    if (bytes == null || name == null) {
      state = state.copyWith(
        status: StatementImportStatus.error,
        errorMessage: 'No file bytes found in state to decrypt.',
      );
      return;
    }

    state = state.copyWith(status: StatementImportStatus.parsing);

    try {
      await _parsePdfBytes(bytes, name, password: password);
    } catch (e) {
      if (e.toString().contains('PASSWORD_REQUIRED')) {
        state = state.copyWith(
          status: StatementImportStatus.passwordRequired,
          errorMessage: 'Incorrect password. Please try again.',
        );
      } else {
        state = state.copyWith(
          status: StatementImportStatus.error,
          errorMessage: e.toString(),
        );
      }
    }
  }

  // Parse direct bytes (used by both file picker, password retry, and mock generator)
  Future<void> _parsePdfBytes(Uint8List bytes, String name, {String? password}) async {
    state = state.copyWith(status: StatementImportStatus.parsing, fileName: name);

    try {
      final rawText = await _pdfParser.extractText(bytes, password: password);
      final rawTransactions = _extractor.extractTransactions(rawText);

      if (rawTransactions.isEmpty) {
        throw const FormatException(
          'No expense/debit transactions detected in the statement. Verify it is a valid bank statement containing debit items.',
        );
      }

      // Map categories
      final mappedTransactions = rawTransactions.map((tx) {
        final category = _categoryMapper.mapMerchantToCategory(tx.merchant);
        return tx.copyWith(category: category);
      }).toList();

      state = state.copyWith(
        status: StatementImportStatus.preview,
        transactions: mappedTransactions,
      );
    } catch (e) {
      if (e.toString().contains('PASSWORD_REQUIRED')) {
        rethrow;
      }
      state = state.copyWith(
        status: StatementImportStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  // Generate a mock statement PDF to test without needing real files
  Future<void> generateAndParseMockStatement({String template = 'hdfc'}) async {
    final fileName = 'mock_${template}_statement.pdf';
    state = state.copyWith(status: StatementImportStatus.parsing, fileName: fileName);
    
    try {
      final bytes = await _generateMockPdfBytes(template);
      await _parsePdfBytes(bytes, fileName);
    } catch (e) {
      state = state.copyWith(
        status: StatementImportStatus.error,
        errorMessage: 'Failed to generate mock statement: $e',
      );
    }
  }

  Future<Uint8List> _generateMockPdfBytes(String template) async {
    final pdfDocument = orgPdf.PdfDocument();
    final page = pdfDocument.pages.add();
    final graphics = page.graphics;
    final font = orgPdf.PdfStandardFont(orgPdf.PdfFontFamily.helvetica, 10);

    String text = '';
    if (template == 'phonepe') {
      text = '''
PhonePe Transaction Statement
Period: May 2026

Jun 22, 2026
07 00 Am
Zomato
Rs 4.00
Rs 11,

Jun 16, 2026
06 53 Pm
Uber Rides
Rs 2.00
Rs 20

May 29, 2026
06 55 Pm
Swiggy Delivery
Rs 3.00
Rs 20
''';
    } else if (template == 'googlepay') {
      text = '''
Date & time          Transaction details                    Amount
05 Mar, 2026         Paid to Google Play                    Rs 2
01:01 AM             UPI Transaction ID: 884881450646
                     Paid by IndusInd Bank 7541

05 Mar, 2026         Received from Google Play              Rs 2
01:01 AM             UPI Transaction ID: 884933900646
                     Paid by IndusInd Bank 7541

20 Apr, 2026         Received from Gurleen Kaur             Rs 438
05:26 PM             UPI Transaction ID: 647633623111
                     Paid by IndusInd Bank 7541

29 Apr, 2026         Paid to GURLEEN KOUR                   Rs 300
12:05 PM             UPI Transaction ID: 611992236644
                     Paid by IndusInd Bank 7541

29 Apr, 2026         Paid to Gulshan Sahu                   Rs 50
12:08 PM             UPI Transaction ID: 611922632398
                     Paid by IndusInd Bank 7541

18 May, 2026         Paid to Ms MS LAXMAN HOTEL             Rs 80
08:10 AM             UPI Transaction ID: 650429759317
                     Paid by IDBI Bank 6486

18 May, 2026         Paid to ConfirmTkt                     Rs 289
09:52 AM             UPI Transaction ID: 650429271046
                     Paid by IDBI Bank 6486
''';
    } else {
      // Default HDFC
      text = '''
HDFC BANK ACCOUNT STATEMENT
Period: 01/05/2026 To 05/06/2026
Account Number: 1234567890

Date        Description                     Amount (Rs)  Type  Balance
05/06/2026  UPI/Zomato Media Pvt/12345      349.00       DR    25432.10
04/06/2026  UBER INDIA RIDES/CAB            150.00       DR    25781.10
04/06/2026  Interest Credited               45.50        CR    25931.10
03/06/2026  AMAZON SELLER PAY/34298         1299.00      DR    25885.60
02/06/2026  Salary Deposit ACME Corp        45000.00     CR    27184.60
01/06/2026  NETFLIX SUBSCRIPTION            199.00       DR    27383.60
31/05/2026  SWIGGY FOOD DELIVERY            250.00       DR    27582.60
30/05/2026  Refund from merchant            120.00       CR    27832.60
29/05/2026  SHELL FUEL STATION              800.00       DR    27712.60
28/05/2026  Airtel Postpaid Bill            499.00       DR    28512.60
27/05/2026  Spotify Premium Plan            179.00       DR    29011.60
26/05/2026  Apollo Pharmacy Medicines       650.00       DR    29190.60
25/05/2026  Udemy Course Purchase           389.00       DR    29840.60
''';
    }

    graphics.drawString(
      text,
      font,
      bounds: const Rect.fromLTWH(20, 20, 500, 700),
    );

    final List<int> bytes = await pdfDocument.save();
    pdfDocument.dispose();
    return Uint8List.fromList(bytes);
  }

  // Toggle selection state of parsed transaction
  void toggleSelection(String id) {
    if (state.status != StatementImportStatus.preview) return;

    state = state.copyWith(
      transactions: state.transactions.map((tx) {
        if (tx.id == id) {
          return tx.copyWith(isSelected: !tx.isSelected);
        }
        return tx;
      }).toList(),
    );
  }

  // Update category of a parsed transaction
  void updateCategory(String id, String categoryName) {
    if (state.status != StatementImportStatus.preview) return;

    state = state.copyWith(
      transactions: state.transactions.map((tx) {
        if (tx.id == id) {
          return tx.copyWith(category: categoryName);
        }
        return tx;
      }).toList(),
    );
  }

  // Remove a parsed transaction from the list
  void removeTransaction(String id) {
    if (state.status != StatementImportStatus.preview) return;

    state = state.copyWith(
      transactions: state.transactions.where((tx) => tx.id != id).toList(),
    );
  }

  // Import selected transactions into the database
  Future<void> importTransactions() async {
    final selectedTxs = state.transactions.where((tx) => tx.isSelected).toList();
    if (selectedTxs.isEmpty) return;

    state = state.copyWith(status: StatementImportStatus.importing);

    try {
      final isar = _ref.read(isarProvider);
      
      await isar.writeTxn(() async {
        for (final tx in selectedTxs) {
          final expense = ExpenseModel()
            ..title = tx.merchant
            ..amount = tx.amount
            ..date = tx.date
            ..type = TransactionType.expense
            ..category = tx.category
            ..note = 'Imported from ${state.fileName ?? "bank statement"}'
            ..paymentMethod = PaymentMethod.bankTransfer
            ..uuid = const Uuid().v4()
            ..createdAt = DateTime.now()
            ..updatedAt = DateTime.now();

          await isar.expenseModels.put(expense);
        }
      });

      state = state.copyWith(
        status: StatementImportStatus.success,
        importedCount: selectedTxs.length,
      );
    } catch (e) {
      state = state.copyWith(
        status: StatementImportStatus.error,
        errorMessage: 'Failed to import transactions: $e',
      );
    }
  }
}

// The main statement import provider
final statementImportProvider =
    StateNotifierProvider<StatementImportNotifier, StatementImportState>((ref) {
  final pdfParser = ref.watch(pdfParserServiceProvider);
  final extractor = ref.watch(transactionExtractorServiceProvider);
  final categoryMapper = ref.watch(categoryMappingServiceProvider);
  
  return StatementImportNotifier(
    pdfParser: pdfParser,
    extractor: extractor,
    categoryMapper: categoryMapper,
    ref: ref,
  );
});
