import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/parsed_transaction.dart';

abstract class TransactionExtractorService {
  List<ParsedTransaction> extractTransactions(String text);
}

class RegExTransactionExtractorService implements TransactionExtractorService {
  const RegExTransactionExtractorService();

  @override
  List<ParsedTransaction> extractTransactions(String text) {
    final List<ParsedTransaction> transactions = [];
    
    // Split into non-empty cleaned lines
    final List<String> rawLines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // Date Patterns
    // 1. DD/MM/YYYY, DD-MM-YYYY, DD.MM.YYYY
    final RegExp datePattern1 = RegExp(r'\b(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})\b');
    
    // 2. DD MMM YYYY, DD-MMM-YY (e.g. 05 Jun 2026, 5-Jun-26)
    final RegExp datePattern2 = RegExp(
      r'\b(\d{1,2})[\s\-./]+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-zA-Z]*[\s\-./]+(\d{2,4})\b',
      caseSensitive: false,
    );
    
    // 3. YYYY-MM-DD
    final RegExp datePattern3 = RegExp(r'\b(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})\b');

    // 4. MMM DD, YYYY or MMM DD YYYY (e.g. May 06, 2026 or May 6 2026)
    final RegExp datePattern4 = RegExp(
      r'\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-zA-Z]*[\s\-./,]+(\d{1,2})[\s\-./,]+(\d{2,4})\b',
      caseSensitive: false,
    );

    // Amount Pattern - matches formatted numbers surrounded by boundaries/spaces
    final RegExp amountPattern = RegExp(r'(?<=^|\s)(?:[+-])?(?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d{2})?(?=$|\s)');

    // Credit/Income indicators
    final List<String> creditKeywords = [
      'salary',
      'refund',
      'credit',
      'cr',
      'deposit',
      'interest',
      'cashback',
      'dividend',
      'credited',
      'refunded',
      'received',
    ];

    int i = 0;
    while (i < rawLines.length) {
      final line = rawLines[i];

      // 1. Detect Date
      DateTime? txDate;
      String? matchedDateStr;

      // Try Pattern 1 (DD/MM/YYYY)
      var match = datePattern1.firstMatch(line);
      if (match != null) {
        matchedDateStr = match.group(0);
        txDate = _parseDate1(match);
      }

      // Try Pattern 2 (DD MMM YYYY)
      if (txDate == null) {
        match = datePattern2.firstMatch(line);
        if (match != null) {
          matchedDateStr = match.group(0);
          txDate = _parseDate2(match);
        }
      }

      // Try Pattern 3 (YYYY-MM-DD)
      if (txDate == null) {
        match = datePattern3.firstMatch(line);
        if (match != null) {
          matchedDateStr = match.group(0);
          txDate = _parseDate3(match);
        }
      }

      // Try Pattern 4 (MMM DD, YYYY)
      if (txDate == null) {
        match = datePattern4.firstMatch(line);
        if (match != null) {
          matchedDateStr = match.group(0);
          txDate = _parseDate4(match);
        }
      }

      // If no date found, check next line
      if (txDate == null || matchedDateStr == null) {
        i++;
        continue;
      }

      // We found a date. Determine if it is a Horizontal Row or a Vertical Grid cell.
      // If the line is long and contains a valid amount, treat it as a single Horizontal Row.
      final bool isHorizontal = line.length > 25 && amountPattern.hasMatch(line);

      if (isHorizontal) {
        _parseHorizontalLine(line, matchedDateStr, txDate, amountPattern, creditKeywords, transactions);
        i++;
      } else {
        // Parse as a vertical cell sequence.
        // Accumulate candidate lines following the date, stopping at the next date or end of text.
        final List<String> candidates = [];
        int j = i + 1;
        while (j < rawLines.length) {
          final candidate = rawLines[j];
          final hasNextDate = datePattern1.hasMatch(candidate) ||
                              datePattern2.hasMatch(candidate) ||
                              datePattern3.hasMatch(candidate) ||
                              datePattern4.hasMatch(candidate);
          if (hasNextDate) {
            break;
          }
          candidates.add(candidate);
          j++;
        }

        // Advance loop index to the next date line
        i = j;

        if (candidates.isNotEmpty) {
          _parseVerticalGroup(candidates, txDate, amountPattern, creditKeywords, transactions);
        }
      }
    }

    return transactions;
  }

  DateTime? _parseDate1(Match match) {
    final dayOrMonth = int.tryParse(match.group(1) ?? '') ?? 1;
    final monthOrDay = int.tryParse(match.group(2) ?? '') ?? 1;
    var year = int.tryParse(match.group(3) ?? '') ?? DateTime.now().year;
    if (year < 100) year += 2000;

    int day = dayOrMonth;
    int month = monthOrDay;
    if (monthOrDay > 12 && dayOrMonth <= 12) {
      day = monthOrDay;
      month = dayOrMonth;
    }

    try {
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  DateTime? _parseDate2(Match match) {
    final day = int.tryParse(match.group(1) ?? '') ?? 1;
    final monthStr = match.group(2)?.toLowerCase() ?? '';
    var year = int.tryParse(match.group(3) ?? '') ?? DateTime.now().year;
    if (year < 100) year += 2000;

    final month = _mapMonthName(monthStr);
    try {
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  DateTime? _parseDate3(Match match) {
    final year = int.tryParse(match.group(1) ?? '') ?? DateTime.now().year;
    final month = int.tryParse(match.group(2) ?? '') ?? 1;
    final day = int.tryParse(match.group(3) ?? '') ?? 1;

    try {
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  DateTime? _parseDate4(Match match) {
    final monthStr = match.group(1)?.toLowerCase() ?? '';
    final day = int.tryParse(match.group(2) ?? '') ?? 1;
    var year = int.tryParse(match.group(3) ?? '') ?? DateTime.now().year;
    if (year < 100) year += 2000;

    final month = _mapMonthName(monthStr);
    try {
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  void _parseHorizontalLine(
    String line,
    String matchedDateStr,
    DateTime txDate,
    RegExp amountPattern,
    List<String> creditKeywords,
    List<ParsedTransaction> transactions,
  ) {
    final lowerLine = line.toLowerCase();
    
    // Check for credits/refunds
    bool isCredit = false;
    for (final keyword in creditKeywords) {
      if (RegExp('\\b$keyword\\b').hasMatch(lowerLine) ||
          lowerLine.contains('+$keyword') ||
          lowerLine.endsWith(' cr') ||
          lowerLine.contains(' credit ')) {
        isCredit = true;
        break;
      }
    }

    if (isCredit) return;

    String remainingText = line.replaceFirst(matchedDateStr, '');
    final List<String> numbers = amountPattern
        .allMatches(remainingText)
        .map((m) => m.group(0)!)
        .where((s) {
          final val = double.tryParse(s.replaceAll(',', ''));
          if (val == null || val <= 1.0) return false;
          // Ignore UTR numbers (large integers without decimal formats)
          if (val > 1000000 && !s.contains('.')) return false;
          return true;
        })
        .toList();

    if (numbers.isEmpty) return;
    final String amountStr = numbers.first;
    final double? amount = double.tryParse(amountStr.replaceAll(',', ''));
    if (amount == null) return;

    for (final numStr in numbers) {
      remainingText = remainingText.replaceFirst(numStr, '');
    }

    final String merchant = _cleanMerchantName(remainingText);
    if (merchant.isEmpty) return;

    // Filter out metadata headers
    final lowerMerchant = merchant.toLowerCase();
    if (lowerMerchant.contains('statement period') ||
        lowerMerchant == 'period' ||
        lowerMerchant.contains('transaction statement') ||
        lowerMerchant.contains('statement of')) {
      return;
    }

    transactions.add(ParsedTransaction(
      id: const Uuid().v4(),
      date: txDate,
      merchant: merchant,
      amount: amount,
      category: 'other',
    ));
  }

  void _parseVerticalGroup(
    List<String> candidates,
    DateTime txDate,
    RegExp amountPattern,
    List<String> creditKeywords,
    List<ParsedTransaction> transactions,
  ) {
    // 1. Check if group contains credit keywords
    bool isCredit = false;
    for (final line in candidates) {
      final lowerLine = line.toLowerCase();
      for (final keyword in creditKeywords) {
        if (RegExp('\\b$keyword\\b').hasMatch(lowerLine) ||
            lowerLine == 'credit' ||
            lowerLine == 'cr') {
          isCredit = true;
          break;
        }
      }
      if (isCredit) break;
    }

    if (isCredit) return;

    // 2. Find amount numbers
    final List<String> numbers = [];
    for (final line in candidates) {
      final matches = amountPattern.allMatches(line).map((m) => m.group(0)!).toList();
      for (final numStr in matches) {
        final val = double.tryParse(numStr.replaceAll(',', ''));
        if (val != null && val > 1.0) {
          // Ignore UTR numbers (large integers without decimals)
          if (val > 1000000 && !numStr.contains('.')) continue;
          numbers.add(numStr);
        }
      }
    }

    if (numbers.isEmpty) return;
    final double? amount = double.tryParse(numbers.first.replaceAll(',', ''));
    if (amount == null) return;

    // 3. Find Description/Merchant line
    // It's the first candidate line that is not a type word, not a number, and not a time value.
    final RegExp timePattern = RegExp(r'\b\d{1,2}:\d{2}(?::\d{2})?(?:\s*[aApP][mM])?\b');
    String? rawMerchant;
    for (final line in candidates) {
      final lowerLine = line.toLowerCase();
      final isType = lowerLine == 'debit' ||
                     lowerLine == 'credit' ||
                     lowerLine == 'dr' ||
                     lowerLine == 'cr' ||
                     lowerLine == 'type';
      final isAmount = numbers.contains(line) || line.contains('INR') || line.contains('Rs');
      final isTime = timePattern.hasMatch(line);

      if (!isType && !isAmount && !isTime &&
          !lowerLine.contains('transaction id') &&
          !lowerLine.contains('utr no') &&
          !lowerLine.contains('debited from') &&
          !lowerLine.contains('credited to')) {
        rawMerchant = line;
        break;
      }
    }

    if (rawMerchant == null || rawMerchant.trim().isEmpty) return;

    final String merchant = _cleanMerchantName(rawMerchant);
    if (merchant.isEmpty) return;

    // Filter out metadata
    final lowerMerchant = merchant.toLowerCase();
    if (lowerMerchant.contains('statement period') ||
        lowerMerchant == 'period' ||
        lowerMerchant.contains('transaction statement') ||
        lowerMerchant.contains('statement of')) {
      return;
    }

    transactions.add(ParsedTransaction(
      id: const Uuid().v4(),
      date: txDate,
      merchant: merchant,
      amount: amount,
      category: 'other',
    ));
  }

  int _mapMonthName(String monthName) {
    if (monthName.startsWith('jan')) return 1;
    if (monthName.startsWith('feb')) return 2;
    if (monthName.startsWith('mar')) return 3;
    if (monthName.startsWith('apr')) return 4;
    if (monthName.startsWith('may')) return 5;
    if (monthName.startsWith('jun')) return 6;
    if (monthName.startsWith('jul')) return 7;
    if (monthName.startsWith('aug')) return 8;
    if (monthName.startsWith('sep')) return 9;
    if (monthName.startsWith('oct')) return 10;
    if (monthName.startsWith('nov')) return 11;
    if (monthName.startsWith('dec')) return 12;
    return 1;
  }

  String _cleanMerchantName(String text) {
    var cleaned = text;

    // Remove "Paid to", "Received from" routing prefixes for clean merchant name output
    cleaned = cleaned.replaceFirst(RegExp(r'^(Paid to|Received from|Debited from|Credited to)\s+', caseSensitive: false), '');

    // Remove hyphenated payment routing tags (e.g. -PAY- or PAY-)
    cleaned = cleaned.replaceAll(RegExp(r'\bPAY[\-\_]|[\-\_]PAY\b', caseSensitive: false), ' ');

    // Remove reference prefix patterns
    cleaned = cleaned.replaceAll(RegExp(r'\b(UPI|Ref|IMPS|NEFT|FT|TXN|ID|RTGS|DR|CR|TRANSFER|NET|DEBIT|CREDIT|WITHDRAWAL|PAYMENT)\b', caseSensitive: false), '');
    // Remove transaction ID numeric blocks (e.g. 3-digit or longer refs/short codes)
    cleaned = cleaned.replaceAll(RegExp(r'\b\d{3,16}\b'), '');
    // Remove common special characters
    cleaned = cleaned.replaceAll(RegExp(r'[/*:\-\\_#]+'), ' ');
    // Remove extra whitespaces
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Limit length and capitalize
    if (cleaned.length > 50) {
      cleaned = cleaned.substring(0, 50).trim();
    }

    // Capitalize first letter of each word
    if (cleaned.isNotEmpty) {
      cleaned = cleaned.split(' ').map((word) {
        if (word.isEmpty) return '';
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      }).join(' ');
    }

    return cleaned;
  }
}
