// Test TextChunker token limits
import 'lib/rag/text_chunker.dart';

void main() {
  final chunker = TextChunker();

  // Create a very long text to test
  final testText = 'This is a test sentence. ' * 100; // ~2500 characters

  print('Testing TextChunker with long text...');
  print('Input length: ${testText.length} characters');
  print('Estimated tokens: ${(testText.length / 3).ceil()} tokens');
  print('Max allowed tokens: 400');
  print('---');

  final chunks = chunker.smartChunk(testText);

  print('Created ${chunks.length} chunks:');
  print('');

  for (int i = 0; i < chunks.length; i++) {
    final chunk = chunks[i];
    final estimatedTokens = (chunk.length / 3).ceil();
    print('Chunk ${i + 1}:');
    print('  - Characters: ${chunk.length}');
    print('  - Estimated tokens: $estimatedTokens');
    print('  - Within limit (≤400): ${estimatedTokens <= 400 ? "✓ YES" : "✗ NO"}');
    print('');
  }
}
