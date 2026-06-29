import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as orgPdf;
import 'lib/src/features/statement_import/data/services/pdf_parser_service.dart';
import 'lib/src/features/statement_import/data/services/transaction_extractor_service.dart';

void main() {
  test('Test real Google Pay PDF', () async {
    final file = File('gpay_statement_20260301_20260531.pdf');
    expect(await file.exists(), isTrue, reason: 'Google Pay statement PDF not found at root.');

    final bytes = await file.readAsBytes();
    
    final parser = const SyncfusionPdfParserService();
    final extractor = const RegExTransactionExtractorService();

    print('Extracting text from PDF...');
    var rawText = await parser.extractText(bytes);
    
    // Preprocess: If almost every word is on a new line, we need to reconstruct the lines.
    // Check if the average words per line is very low.
    final lines = rawText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final wordCount = rawText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final avgWordsPerLine = wordCount / lines.length;
    
    print('Average words per line: $avgWordsPerLine');
    if (avgWordsPerLine < 1.8) {
      print('Detected word-per-line layout. Reconstructing text...');
      
      // 1. Join all text with spaces to make it a single line
      var cleanedText = rawText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).join(' ');
      
      // 2. Re-merge rupee symbols: e.g. "₹ 2" -> "₹2"
      cleanedText = cleanedText.replaceAllMapped(RegExp(r'₹\s+(\d+)'), (m) => '₹${m.group(1)}');
      
      // 3. Remove bank details that confuse the amount parser: e.g. "Paid by IndusInd Bank 7541"
      cleanedText = cleanedText.replaceAll(RegExp(r'Paid\s+(by|to)\s+[a-zA-Z\s]+Bank\s+\d{4}', caseSensitive: false), '');
      
      // 4. Format Date commas: Google Pay sometimes has "Mar , 2026"
      cleanedText = cleanedText.replaceAllMapped(RegExp(r'\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-zA-Z]*\s*,\s*(\d{2,4})\b', caseSensitive: false), 
          (m) => '${m.group(1)}, ${m.group(2)}');
          
      // 4. Put a newline before every date to split them into clean horizontal rows!
      // Date pattern: e.g. "05 Mar, 2026" or "5 Mar, 2026"
      cleanedText = cleanedText.replaceAllMapped(
          RegExp(r'(\b\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-zA-Z]*,\s+\d{2,4})', caseSensitive: false), 
          (m) => '\n${m.group(1)}');
          
      rawText = cleanedText;
    }
    
    print('--- PREPROCESSED TEXT ---');
    print(rawText);
    print('-------------------------');

    print('Extracting transactions...');
    try {
      final transactions = extractor.extractTransactions(rawText);
      print('Found ${transactions.length} transactions:');
      for (final tx in transactions) {
        print(' - Date: ${tx.date}, Merchant: "${tx.merchant}", Amount: ${tx.amount}, Category: ${tx.category}');
      }
    } catch (e) {
      print('Extraction failed with error: $e');
    }
  });
}
