// rag/pdf_processor.dart - PDF text extraction service
import 'dart:io';
import 'package:pdfrx/pdfrx.dart';
import '../shared/logger.dart';

class PDFProcessor {
  /// Extract text content from a PDF file
  Future<String?> extractTextFromPDF(File pdfFile) async {
    try {
      Log.i('Starting PDF text extraction: ${pdfFile.path}', 'PDFProcessor');

      final document = await PdfDocument.openFile(pdfFile.path);

      if (document.pages.isEmpty) {
        Log.w('PDF has no pages', 'PDFProcessor');
        document.dispose();
        return null;
      }

      Log.i('PDF has ${document.pages.length} pages', 'PDFProcessor');

      final StringBuffer fullText = StringBuffer();
      int processedPages = 0;

      // Extract text from each page
      for (int i = 0; i < document.pages.length; i++) {
        try {
          final page = document.pages[i];
          final pageText = await page.loadText();
          final textContent = pageText.fullText;

          if (textContent.isNotEmpty) {
            // Add page separator for better chunking
            if (fullText.isNotEmpty) {
              fullText.write('\n\n');
            }
            fullText.write(textContent);
            processedPages++;
          }
        } catch (e) {
          Log.w('Failed to extract text from page ${i + 1}', 'PDFProcessor');
          // Continue with other pages even if one fails
          continue;
        }
      }

      document.dispose();

      final extractedText = fullText.toString().trim();

      if (extractedText.isEmpty) {
        Log.w('No text extracted from PDF (might be image-based)', 'PDFProcessor');
        return null;
      }

      Log.s(
        'Successfully extracted text from $processedPages pages (${extractedText.length} characters)',
        'PDFProcessor',
      );

      return extractedText;
    } catch (e, stack) {
      Log.e('Failed to extract text from PDF', 'PDFProcessor', e);
      Log.e('Stack trace:', 'PDFProcessor', stack);
      return null;
    }
  }

  /// Check if file is a valid PDF
  bool isPDFFile(String filePath) {
    return filePath.toLowerCase().endsWith('.pdf');
  }

  /// Get PDF metadata
  Future<Map<String, dynamic>?> getPDFMetadata(File pdfFile) async {
    try {
      final document = await PdfDocument.openFile(pdfFile.path);

      final metadata = {
        'pageCount': document.pages.length,
        'fileSize': await pdfFile.length(),
        'fileName': pdfFile.uri.pathSegments.last,
      };

      document.dispose();
      return metadata;
    } catch (e) {
      Log.e('Failed to get PDF metadata', 'PDFProcessor', e);
      return null;
    }
  }

  /// Validate PDF file
  Future<bool> validatePDF(File pdfFile) async {
    try {
      if (!await pdfFile.exists()) {
        Log.w('PDF file does not exist', 'PDFProcessor');
        return false;
      }

      final fileSize = await pdfFile.length();
      if (fileSize == 0) {
        Log.w('PDF file is empty', 'PDFProcessor');
        return false;
      }

      // Try to open the document
      final document = await PdfDocument.openFile(pdfFile.path);

      if (document.pages.isEmpty) {
        Log.w('PDF has no pages', 'PDFProcessor');
        document.dispose();
        return false;
      }

      document.dispose();
      return true;
    } catch (e) {
      Log.e('PDF validation failed', 'PDFProcessor', e);
      return false;
    }
  }
}
