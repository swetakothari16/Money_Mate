import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  test('Generate test PDFs', () async {
    print('Generating test PDFs...');
    
    await generatePdf('mock_hdfc.pdf', '''
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
''');

    await generatePdf('mock_phonepe.pdf', '''
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
''');

    await generatePdf('mock_gpay.pdf', '''
Date & time          Transaction details                    Amount
05 Mar, 2026         Paid to Google Play                    Rs 2
01:01 AM             UPI Transaction ID: 884881450646
                     Paid by IndusInd Bank 7541

05 Mar, 2026         Received from Google Play              Rs 2
01:01 AM             UPI Transaction ID: 884933900646
                     Paid to IndusInd Bank 7541

20 Apr, 2026         Received from Gurleen Kaur             Rs 438
05:26 PM             UPI Transaction ID: 647633623111
                     Paid to IndusInd Bank 7541

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
''');

    print('Done! Test PDFs generated in workspace.');
  });
}

Future<void> generatePdf(String filename, String content) async {
  final pdfDocument = PdfDocument();
  final page = pdfDocument.pages.add();
  final graphics = page.graphics;
  final font = PdfStandardFont(PdfFontFamily.helvetica, 10);

  graphics.drawString(
    content,
    font,
    bounds: const Rect.fromLTWH(20, 20, 500, 700),
  );

  final List<int> bytes = await pdfDocument.save();
  pdfDocument.dispose();
  
  final file = File(filename);
  await file.writeAsBytes(bytes);
  print('Saved $filename');
}
