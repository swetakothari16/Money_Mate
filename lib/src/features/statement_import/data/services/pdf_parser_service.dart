import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

abstract class PdfParserService {
  Future<String> extractText(Uint8List bytes, {String? password});
}

class SyncfusionPdfParserService implements PdfParserService {
  const SyncfusionPdfParserService();

  @override
  Future<String> extractText(Uint8List bytes, {String? password}) async {
    try {
      final PdfDocument document = PdfDocument(inputBytes: bytes, password: password);
      
      // Extract text from the PDF pages.
      final String text = PdfTextExtractor(document).extractText();
      document.dispose();
      
      if (text.trim().isEmpty) {
        throw const FormatException(
          'No text content could be extracted from this PDF. It might be an image-only scan or password protected.',
        );
      }
      
      return text;
    } catch (e) {
      debugPrint('PdfParserService error: $e');
      if (e is FormatException) {
        rethrow;
      }
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('password') || errStr.contains('encrypted') || errStr.contains('decrypt')) {
        throw const FormatException('PASSWORD_REQUIRED');
      }
      throw FormatException('Failed to process the PDF document: $e');
    }
  }
}
