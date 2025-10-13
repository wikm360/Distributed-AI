// rag/text_chunker.dart - Text chunking utilities for RAG
import 'dart:math';

class TextChunker {
  final int chunkSize;
  final int overlap;

  TextChunker({
    this.chunkSize = 500, // characters
    this.overlap = 50,
  });

  /// Chunk text into smaller pieces with overlap
  List<String> chunkText(String text) {
    if (text.isEmpty) return [];

    final chunks = <String>[];
    int start = 0;

    while (start < text.length) {
      int end = min(start + chunkSize, text.length);

      // Try to break at sentence boundary
      if (end < text.length) {
        final lastPeriod = text.lastIndexOf(RegExp(r'[.!?]\s'), end);
        if (lastPeriod > start && lastPeriod - start > chunkSize ~/ 2) {
          end = lastPeriod + 1;
        }
      }

      chunks.add(text.substring(start, end).trim());
      start = end - overlap;

      // Avoid infinite loop
      if (start >= text.length) break;
    }

    return chunks;
  }

  /// Chunk text by paragraphs
  List<String> chunkByParagraphs(String text) {
    return text
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
  }

  /// Smart chunking: use paragraphs if reasonable, otherwise character-based
  List<String> smartChunk(String text) {
    final paragraphs = chunkByParagraphs(text);

    // If paragraphs are reasonable size, use them
    final reasonableParagraphs = <String>[];
    for (final para in paragraphs) {
      if (para.length <= chunkSize * 2) {
        reasonableParagraphs.add(para);
      } else {
        // Para too long, split it
        reasonableParagraphs.addAll(chunkText(para));
      }
    }

    return reasonableParagraphs;
  }

  /// Get word count
  static int wordCount(String text) {
    return text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }
}
