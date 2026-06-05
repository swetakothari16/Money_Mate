import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

abstract class PdfParserService {
  Future<String> extractText(Uint8List bytes);
}

class SyncfusionPdfParserService implements PdfParserService {
  const SyncfusionPdfParserService();

  @override
  Future<String> extractText(Uint8List bytes) async {
    try {
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      
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
      throw FormatException('Failed to process the PDF document: $e');
    }
  }
}
