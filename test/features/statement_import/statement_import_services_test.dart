import 'package:flutter_test/flutter_test.dart';
import 'package:expense_partner/src/core/enums/expense_category.dart';
import 'package:expense_partner/src/features/statement_import/data/services/transaction_extractor_service.dart';
import 'package:expense_partner/src/features/statement_import/data/services/category_mapping_service.dart';

void main() {
  group('TransactionExtractorService Tests', () {
    const extractor = RegExTransactionExtractorService();

    test('Should parse standard statement rows correctly', () {
      const text = '''
05/06/2026 UPI/Zomato Media Pvt/123456 349.00 DR 25432.10
04-06-2026 UBER INDIA RIDES/CAB 150.00 DR 25781.10
03 Jun 2026 AMAZON SELLER PAY/34298 1299.50 DR 25885.60
''';

      final txs = extractor.extractTransactions(text);

      expect(txs.length, equals(3));
      
      // Row 1
      expect(txs[0].merchant, equals('Zomato Media Pvt'));
      expect(txs[0].amount, equals(349.00));
      expect(txs[0].date, equals(DateTime(2026, 6, 5)));

      // Row 2
      expect(txs[1].merchant, equals('Uber India Rides Cab'));
      expect(txs[1].amount, equals(150.00));
      expect(txs[1].date, equals(DateTime(2026, 6, 4)));

      // Row 3
      expect(txs[2].merchant, equals('Amazon Seller Pay'));
      expect(txs[2].amount, equals(1299.50));
      expect(txs[2].date, equals(DateTime(2026, 6, 3)));
    });

    test('Should ignore credits, refunds, and salary deposits', () {
      const text = '''
05/06/2026 UPI/Zomato Media Pvt/123456 349.00 DR 25432.10
04/06/2026 Interest Credited 45.50 CR 25931.10
03/06/2026 Salary Deposit ACME Corp 45000.00 CR 27184.60
31/05/2026 SWIGGY FOOD DELIVERY 250.00 DR 27582.60
30/05/2026 Refund from merchant 120.00 CR 27832.60
''';

      final txs = extractor.extractTransactions(text);

      expect(txs.length, equals(2));
      expect(txs[0].merchant, equals('Zomato Media Pvt'));
      expect(txs[1].merchant, equals('Swiggy Food Delivery'));
    });

    test('Should clean garbage prefixes/suffixes and format merchant names', () {
      const text = '''
05/06/2026 UPI/STARBUCKS COFFEE//DR-982347 220.00 DR
04/06/2026 TXN/AIRTEL BILL RECHARGE/NET-9912 499.00 DR
03/06/2026 NEFT-PAY-NETFLIX-SUBSCRIPTION 199.00 DR
''';

      final txs = extractor.extractTransactions(text);

      expect(txs.length, equals(3));
      expect(txs[0].merchant, equals('Starbucks Coffee'));
      expect(txs[1].merchant, equals('Airtel Bill Recharge'));
      expect(txs[2].merchant, equals('Netflix Subscription'));
    });

    test('Should parse integer/non-decimal amounts and ignore reference numbers', () {
      const text = '''
01-06-2026 UPI SWIGGY Debit 450 24,550
03-06-2026 UPI AMAZON Debit 1,299 68,251
05-06-2026 UPI UBER Debit 320 67,931
''';

      final txs = extractor.extractTransactions(text);

      expect(txs.length, equals(3));
      expect(txs[0].merchant, equals('Swiggy'));
      expect(txs[0].amount, equals(450.0));
      expect(txs[0].date, equals(DateTime(2026, 6, 1)));

      expect(txs[1].merchant, equals('Amazon'));
      expect(txs[1].amount, equals(1299.0));
      expect(txs[1].date, equals(DateTime(2026, 6, 3)));

      expect(txs[2].merchant, equals('Uber'));
      expect(txs[2].amount, equals(320.0));
      expect(txs[2].date, equals(DateTime(2026, 6, 5)));
    });

    test('Should parse vertical grid-based transaction sequence correctly', () {
      const text = '''
01-06-2026
UPI SWIGGY
Debit
450
24,550
02-06-2026
SALARY CREDIT
Credit
45,000
69,550
03-06-2026
UPI AMAZON
Debit
1,299
68,251
''';

      final txs = extractor.extractTransactions(text);

      expect(txs.length, equals(2)); // credit row skipped

      expect(txs[0].merchant, equals('Swiggy'));
      expect(txs[0].amount, equals(450.0));
      expect(txs[0].date, equals(DateTime(2026, 6, 1)));

      expect(txs[1].merchant, equals('Amazon'));
      expect(txs[1].amount, equals(1299.0));
      expect(txs[1].date, equals(DateTime(2026, 6, 3)));
    });

    test('Should parse PhonePe statement layout correctly', () {
      const text = '''
May 06, 2026
08:07 PM
Paid to Top Up Centre
Transaction ID : T2605062007342523008525
UTR No : 592441563336
Debited from XX9417
Debit
INR 222.00
May 06, 2026
08:58 PM
Paid to SURAJ KUMAR SHARMA
Transaction ID : T2605062057570693494717
UTR No : 138212592388
Debited from XX9417
Debit
INR 40.00
May 10, 2026
09:47 PM
Received from G Sai soni
Transaction ID : T2605102147169863129599
UTR No : 873115929657
Credited to XX9417
Credit
INR 160.00
''';

      final txs = extractor.extractTransactions(text);

      expect(txs.length, equals(2)); // credit row skipped
      
      expect(txs[0].merchant, equals('Top Up Centre'));
      expect(txs[0].amount, equals(222.0));
      expect(txs[0].date, equals(DateTime(2026, 5, 6)));

      expect(txs[1].merchant, equals('Suraj Kumar Sharma'));
      expect(txs[1].amount, equals(40.0));
      expect(txs[1].date, equals(DateTime(2026, 5, 6)));
    });

    test('Should ignore date range headers', () {
      const text = '''
May 06, 2026 - Jun 05, 2026
Transaction Statement
May 07, 2026
UPI SWIGGY
Debit
450.00
24,550
''';
      final txs = extractor.extractTransactions(text);
      expect(txs.length, equals(1));
      expect(txs[0].merchant, equals('Swiggy'));
      expect(txs[0].amount, equals(450.0));
    });

    test('Should ignore cheque numbers and parse correct amount', () {
      const text = '''
05/06/2026 353485 Zomato Media Pvt 349.00 DR 25432.10
06/06/2026
353486
UBER INDIA RIDES
Debit
150.00
25781.10
''';
      final txs = extractor.extractTransactions(text);
      expect(txs.length, equals(2));
      expect(txs[0].amount, equals(349.00));
      expect(txs[1].amount, equals(150.00));
    });
  });

  group('CategoryMappingService Tests', () {
    const mapper = RuleBasedCategoryMappingService();

    test('Should map common merchants to correct categories', () {
      expect(mapper.mapMerchantToCategory('Swiggy'), equals(ExpenseCategory.food.name));
      expect(mapper.mapMerchantToCategory('Zomato Media'), equals(ExpenseCategory.food.name));
      expect(mapper.mapMerchantToCategory('Uber Rides'), equals(ExpenseCategory.transport.name));
      expect(mapper.mapMerchantToCategory('Shell Petrol Station'), equals(ExpenseCategory.transport.name));
      expect(mapper.mapMerchantToCategory('Amazon Store'), equals(ExpenseCategory.shopping.name));
      expect(mapper.mapMerchantToCategory('Netflix Subscription'), equals(ExpenseCategory.subscriptions.name));
      expect(mapper.mapMerchantToCategory('Airtel Recharge'), equals(ExpenseCategory.bills.name));
      expect(mapper.mapMerchantToCategory('Unknown Merchant LLC'), equals(ExpenseCategory.other.name));
    });
  });
}
