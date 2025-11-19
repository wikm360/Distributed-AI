// rag/text_chunker.dart - Advanced semantic text chunking for RAG
import 'dart:math';

class TextChunker {
  final int minChunkSize;
  final int maxChunkSize;
  final int overlap;
  final double minQualityScore;
  final int maxTokens; // Maximum tokens per chunk for embedding model

  TextChunker({
    this.minChunkSize = 100, // Minimum characters for a meaningful chunk
    this.maxChunkSize = 800, // Maximum characters per chunk
    this.overlap = 50,
    this.minQualityScore = 0.3, // Minimum quality score (0-1) to include chunk
    this.maxTokens = 400, // Max tokens (well below 512 limit for safety)
  });

  /// Estimate token count (rough approximation: 1 token ≈ 4 chars in English, less for other languages)
  int _estimateTokenCount(String text) {
    // Conservative estimate: assume 3 characters per token for safety
    // This accounts for non-English text which often uses more tokens
    return (text.length / 3).ceil();
  }

  /// Check if chunk is within token limit
  bool _isWithinTokenLimit(String chunk) {
    return _estimateTokenCount(chunk) <= maxTokens;
  }

  /// Clean and normalize text before chunking
  String _cleanText(String text) {
    // Remove excessive whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    
    // Remove excessive newlines (more than 2 consecutive)
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    
    // Remove leading/trailing whitespace
    text = text.trim();
    
    return text;
  }

  /// Check if chunk has meaningful content
  bool _isValidChunk(String chunk) {
    if (chunk.isEmpty) return false;

    // CRITICAL: Check token limit first (must not exceed model's max input)
    if (!_isWithinTokenLimit(chunk)) return false;

    // Check minimum size
    if (chunk.length < minChunkSize) return false;

    // Check if it's mostly whitespace
    final nonWhitespace = chunk.replaceAll(RegExp(r'\s'), '').length;
    if (nonWhitespace < minChunkSize * 0.5) return false;

    // Check if it has at least some sentences (at least one sentence ending)
    if (!RegExp(r'[.!?]').hasMatch(chunk)) {
      // If no sentence endings, check if it's long enough to be meaningful
      if (chunk.length < minChunkSize * 1.5) return false;
    }

    // Check for meaningful words (at least 10 words)
    final wordCount = chunk.split(RegExp(r'\s+')).where((w) => w.length > 1).length;
    if (wordCount < 10) return false;

    return true;
  }

  /// Calculate quality score for a chunk
  double _calculateQualityScore(String chunk) {
    double score = 1.0;
    
    // Penalize chunks that are too short
    if (chunk.length < minChunkSize * 1.5) {
      score *= 0.7;
    }
    
    // Penalize chunks with too many special characters (likely code/noise)
    final specialCharRatio = chunk.replaceAll(RegExp(r'[a-zA-Z0-9\s]'), '').length / chunk.length;
    if (specialCharRatio > 0.3) {
      score *= 0.6;
    }
    
    // Reward chunks with proper sentence structure
    final sentenceCount = RegExp(r'[.!?]\s+').allMatches(chunk).length;
    if (sentenceCount >= 2) {
      score *= 1.1;
    }
    
    // Penalize chunks that are mostly numbers
    final numberRatio = RegExp(r'\d').allMatches(chunk).length / chunk.length;
    if (numberRatio > 0.4) {
      score *= 0.7;
    }
    
    // Reward chunks with diverse vocabulary
    final words = chunk.toLowerCase().split(RegExp(r'\s+')).where((w) => w.length > 2).toSet();
    final uniqueWordRatio = words.length / chunk.split(RegExp(r'\s+')).length;
    if (uniqueWordRatio > 0.5) {
      score *= 1.1;
    }
    
    return min(score, 1.0);
  }

  /// Remove duplicate or very similar chunks
  List<String> _removeDuplicates(List<String> chunks) {
    if (chunks.length <= 1) return chunks;
    
    final uniqueChunks = <String>[];
    final seenHashes = <int>{};
    
    for (final chunk in chunks) {
      // Create a simple hash based on normalized content
      final normalized = chunk
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      
      // Use first 100 chars for similarity check
      final hash = normalized.substring(0, min(100, normalized.length)).hashCode;
      
      // Check similarity with existing chunks
      bool isDuplicate = false;
      for (final seenHash in seenHashes) {
        // Simple similarity: if hash is same or very close, likely duplicate
        if ((hash - seenHash).abs() < 10) {
          // Check actual content similarity
          final existingChunk = uniqueChunks.firstWhere(
            (c) => (c.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').substring(0, min(100, c.length)).hashCode - seenHash).abs() < 10,
            orElse: () => '',
          );
          
          if (existingChunk.isNotEmpty) {
            final similarity = _calculateSimilarity(normalized, existingChunk.toLowerCase().replaceAll(RegExp(r'\s+'), ' '));
            if (similarity > 0.85) {
              isDuplicate = true;
              break;
            }
          }
        }
      }
      
      if (!isDuplicate) {
        uniqueChunks.add(chunk);
        seenHashes.add(hash);
      }
    }
    
    return uniqueChunks;
  }

  /// Calculate similarity between two strings (simple Jaccard-like)
  double _calculateSimilarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0.0;
    
    final wordsA = a.split(RegExp(r'\s+')).where((w) => w.length > 2).toSet();
    final wordsB = b.split(RegExp(r'\s+')).where((w) => w.length > 2).toSet();
    
    if (wordsA.isEmpty || wordsB.isEmpty) return 0.0;
    
    final intersection = wordsA.intersection(wordsB).length;
    final union = wordsA.union(wordsB).length;
    
    return union > 0 ? intersection / union : 0.0;
  }

  /// Split text into semantic units (sentences, paragraphs)
  List<String> _splitIntoSemanticUnits(String text) {
    final units = <String>[];
    
    // First, split by paragraphs (double newlines)
    final paragraphs = text.split(RegExp(r'\n\s*\n'));
    
    for (final para in paragraphs) {
      final trimmed = para.trim();
      if (trimmed.isEmpty) continue;
      
      // If paragraph is reasonable size, keep it as one unit
      if (trimmed.length <= maxChunkSize) {
        units.add(trimmed);
      } else {
        // Split paragraph into sentences
        final sentences = _splitIntoSentences(trimmed);
        units.addAll(sentences);
      }
    }
    
    return units.where((u) => u.isNotEmpty).toList();
  }

  /// Split text into sentences
  List<String> _splitIntoSentences(String text) {
    final sentences = <String>[];
    final sentenceEnders = RegExp(r'[.!?]\s+');
    
    int start = 0;
    for (final match in sentenceEnders.allMatches(text)) {
      final sentence = text.substring(start, match.end).trim();
      if (sentence.isNotEmpty) {
        sentences.add(sentence);
      }
      start = match.end;
    }
    
    // Add remaining text
    if (start < text.length) {
      final remaining = text.substring(start).trim();
      if (remaining.isNotEmpty) {
        sentences.add(remaining);
      }
    }
    
    return sentences;
  }

  /// Merge semantic units into chunks of appropriate size
  List<String> _mergeIntoChunks(List<String> units) {
    if (units.isEmpty) return [];

    final chunks = <String>[];
    StringBuffer currentChunk = StringBuffer();

    for (final unit in units) {
      final unitLength = unit.length;
      final currentLength = currentChunk.length;

      // Check if adding this unit would exceed limits
      final potentialChunk = currentLength > 0
          ? '${currentChunk.toString()} $unit'
          : unit;

      final wouldExceedSize = currentLength + unitLength + 1 > maxChunkSize;
      final wouldExceedTokens = !_isWithinTokenLimit(potentialChunk);

      // If adding this unit would exceed max size or token limit, finalize current chunk
      if (currentLength > 0 && (wouldExceedSize || wouldExceedTokens)) {
        final chunk = currentChunk.toString().trim();
        if (_isValidChunk(chunk)) {
          chunks.add(chunk);
        }
        currentChunk.clear();
      }

      // Add unit to current chunk
      if (currentChunk.length > 0) {
        currentChunk.write(' ');
      }
      currentChunk.write(unit);

      // If current chunk is large enough, consider finalizing it
      final chunkText = currentChunk.toString();
      final reachedSizeThreshold = chunkText.length >= maxChunkSize * 0.8;
      final reachedTokenThreshold = _estimateTokenCount(chunkText) >= maxTokens * 0.8;

      if (reachedSizeThreshold || reachedTokenThreshold) {
        // Try to break at sentence boundary if possible
        final lastSentenceEnd = chunkText.lastIndexOf(RegExp(r'[.!?]\s+'));

        if (lastSentenceEnd > chunkText.length * 0.5) {
          // Good place to break
          final chunk = chunkText.substring(0, lastSentenceEnd + 1).trim();
          if (_isValidChunk(chunk)) {
            chunks.add(chunk);
          }

          // Keep the rest
          final remaining = chunkText.substring(lastSentenceEnd + 1).trim();
          currentChunk.clear();
          if (remaining.isNotEmpty) {
            currentChunk.write(remaining);
          }
        }
      }
    }

    // Add final chunk
    if (currentChunk.length > 0) {
      final chunk = currentChunk.toString().trim();
      if (_isValidChunk(chunk)) {
        chunks.add(chunk);
      }
    }

    return chunks;
  }

  /// Advanced semantic chunking with quality filtering
  List<String> semanticChunk(String text) {
    if (text.isEmpty) return [];
    
    // Clean text first
    text = _cleanText(text);
    if (text.isEmpty) return [];
    
    // Split into semantic units
    final units = _splitIntoSemanticUnits(text);
    if (units.isEmpty) return [];
    
    // Merge into chunks
    var chunks = _mergeIntoChunks(units);
    
    // Filter by quality score
    chunks = chunks.where((chunk) {
      final score = _calculateQualityScore(chunk);
      return score >= minQualityScore;
    }).toList();
    
    // Remove duplicates
    chunks = _removeDuplicates(chunks);
    
    // Final validation
    chunks = chunks.where(_isValidChunk).toList();
    
    return chunks;
  }

  /// Legacy method: Chunk text into smaller pieces with overlap
  @Deprecated('Use semanticChunk instead for better results')
  List<String> chunkText(String text) {
    if (text.isEmpty) return [];
    
    text = _cleanText(text);
    final chunks = <String>[];
    int start = 0;

    while (start < text.length) {
      int end = min(start + maxChunkSize, text.length);

      // Try to break at sentence boundary
      if (end < text.length) {
        final lastPeriod = text.lastIndexOf(RegExp(r'[.!?]\s+'), end);
        if (lastPeriod > start && lastPeriod - start > maxChunkSize ~/ 2) {
          end = lastPeriod + 1;
        }
      }

      final chunk = text.substring(start, end).trim();
      if (_isValidChunk(chunk)) {
        chunks.add(chunk);
      }
      
      start = end - overlap;

      // Avoid infinite loop
      if (start >= text.length) break;
      if (start <= 0) start = end; // Safety check
    }

    return chunks;
  }

  /// Chunk text by paragraphs
  List<String> chunkByParagraphs(String text) {
    if (text.isEmpty) return [];
    
    text = _cleanText(text);
    final paragraphs = text
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty && _isValidChunk(p))
        .toList();
    
    return paragraphs;
  }

  /// Smart chunking: use semantic chunking for best results
  List<String> smartChunk(String text) {
    // Use semantic chunking as the default smart method
    return semanticChunk(text);
  }

  /// Get word count
  static int wordCount(String text) {
    return text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }
}
