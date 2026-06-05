import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  test('Find PhonePe PDF', () async {
    final dir = Directory('C:/Users/MY-PC/Downloads');
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.pdf'));

    for (final file in files) {
      try {
        final bytes = await file.readAsBytes();
        final document = PdfDocument(inputBytes: bytes);
        final text = PdfTextExtractor(document).extractText();
        document.dispose();

        if (text.contains('PhonePe') || text.contains('+919926001833') || text.contains('Top Up Centre') || text.contains('Top-Up')) {
          print('FOUND FILE: ${file.path}');
          print('TEXT SNIPPET:');
          print(text.substring(0, text.length > 1500 ? 1500 : text.length));
          break;
        }
      } catch (e) {
        print('Error reading ${file.path}: $e');
      }
    }
  });
}
