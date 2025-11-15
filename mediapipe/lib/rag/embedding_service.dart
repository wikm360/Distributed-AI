// rag/embedding_service.dart - Service for managing embedding model
import 'dart:async';
import 'dart:io';
import 'package:flutter_gemma/flutter_gemma.dart' as gemma;
import 'package:flutter_gemma/pigeon.g.dart';
import 'package:path_provider/path_provider.dart';
import '../shared/models.dart' as models;
import '../shared/logger.dart';

class EmbeddingService {
  models.EmbeddingModel? _currentModel;
  gemma.EmbeddingModel? _modelInstance;
  bool _isLoading = false;
  bool _isReady = false;

  // Stream controllers for status updates
  final StreamController<EmbeddingStatusUpdate> _statusController =
      StreamController<EmbeddingStatusUpdate>.broadcast();

  models.EmbeddingModel? get currentModel => _currentModel;
  bool get isReady => _isReady;
  bool get isLoading => _isLoading;
  Stream<EmbeddingStatusUpdate> get statusStream => _statusController.stream;

  /// Check if embedding model files exist
  Future<models.EmbeddingModel?> getInstalledModel() async {
    final dir = await getApplicationDocumentsDirectory();
    // Use separate embeddings directory to avoid conflict with flutter_gemma cleanup
    final embeddingDir = Directory('${dir.path}/embeddings');

    for (final model in models.EmbeddingModel.values) {
      final modelPath = '${embeddingDir.path}/${model.filename}';
      final tokenizerPath = '${embeddingDir.path}/${model.tokenizerFilename}';

      if (File(modelPath).existsSync() && File(tokenizerPath).existsSync()) {
        Log.i('Found installed embedding model: ${model.displayName}', 'EmbeddingService');
        return model;
      }
    }

    return null;
  }

  /// Load embedding model
  Future<bool> loadModel(models.EmbeddingModel model) async {
    if (_isLoading) {
      Log.w('Model already loading', 'EmbeddingService');
      return false;
    }

    _isLoading = true;
    _emitStatus(EmbeddingStatus.loading, 'Loading ${model.displayName}...');

    try {
      final dir = await getApplicationDocumentsDirectory();
      // Use separate embeddings directory to avoid conflict with flutter_gemma cleanup
      final embeddingDir = Directory('${dir.path}/embeddings');
      final modelPath = '${embeddingDir.path}/${model.filename}';
      final tokenizerPath = '${embeddingDir.path}/${model.tokenizerFilename}';

      // Check if files exist
      if (!File(modelPath).existsSync() || !File(tokenizerPath).existsSync()) {
        throw Exception('Model files not found. Please download first.');
      }

      Log.i('Creating embedding model from $modelPath', 'EmbeddingService');

      // Create embedding model instance
      _modelInstance = await gemma.FlutterGemmaPlugin.instance.createEmbeddingModel(
        modelPath: modelPath,
        tokenizerPath: tokenizerPath,
        preferredBackend: PreferredBackend.gpu,
      );

      // Verify dimension
      final dimension = await _modelInstance!.getDimension();
      Log.s('Embedding model loaded successfully. Dimension: $dimension', 'EmbeddingService');

      _currentModel = model;
      _isReady = true;
      _isLoading = false;

      _emitStatus(EmbeddingStatus.ready, 'Model ready (dim: $dimension)');
      return true;

    } catch (e) {
      Log.e('Failed to load embedding model', 'EmbeddingService', e);
      _isLoading = false;
      _isReady = false;
      _emitStatus(EmbeddingStatus.error, 'Load failed: $e');
      return false;
    }
  }

  /// Generate embedding for single text
Future<List<double>?> generateEmbedding(String text) async {
  if (!_isReady || _modelInstance == null) {
    Log.w('Model not ready', 'EmbeddingService');
    return null;
  }
  try {
    // WORKAROUND: flutter_gemma returns CastList<Object?, double> that fails on iteration
    // We need to extract the raw data without triggering the cast
    final rawEmbedding = await _modelInstance!.generateEmbedding(text);

    // Try to get the length without triggering iteration
    int length = 0;
    try {
      // Use reflection-like access through dynamic
      length = (rawEmbedding as dynamic).length as int;
    } catch (e) {
      Log.e('Failed to get embedding length', 'EmbeddingService', e);
      return null;
    }

    Log.i('Generated embedding with $length dimensions', 'EmbeddingService');

    // Build result by accessing indices directly and converting
    final embedding = <double>[];
    for (int i = 0; i < length; i++) {
      try {
        // Access by index and convert - this might trigger the cast error
        final value = (rawEmbedding as dynamic)[i];
        embedding.add((value as num).toDouble());
      } catch (e) {
        Log.e('Failed to convert embedding value at index $i', 'EmbeddingService', e);
        return null;
      }
    }

    return embedding;
  } catch (e, stack) {
    Log.e('Failed to generate embedding', 'EmbeddingService', e);
    Log.e('Stack: $stack', 'EmbeddingService');
    return null;
  }
}

  /// Generate embeddings for multiple texts
Future<List<List<double>>?> generateEmbeddings(List<String> texts) async {
  if (!_isReady || _modelInstance == null) {
    Log.w('Model not ready', 'EmbeddingService');
    return null;
  }
  try {
    // WORKAROUND: flutter_gemma's generateEmbeddings returns a CastList that fails on access
    // Instead, call generateEmbedding individually for each text
    // This is slower but avoids the CastList issue

    Log.i('Generating ${texts.length} embeddings individually...', 'EmbeddingService');

    final result = <List<double>>[];
    for (int i = 0; i < texts.length; i++) {
      final embedding = await generateEmbedding(texts[i]);
      if (embedding == null) {
        Log.e('Failed to generate embedding for text $i', 'EmbeddingService');
        return null;
      }
      result.add(embedding);
    }

    Log.i('Successfully generated ${result.length} embeddings', 'EmbeddingService');
    return result;

  } catch (e, stack) {
    Log.e('Failed to generate embeddings', 'EmbeddingService', e);
    Log.e('Stack trace: $stack', 'EmbeddingService');
    return null;
  }
}

  /// Calculate cosine similarity between two embeddings
  double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) {
      throw ArgumentError('Embeddings must have same dimension');
    }

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA == 0.0 || normB == 0.0) return 0.0;

    return dotProduct / (normA * normB);
  }

  /// Close and unload the model
  Future<void> dispose() async {
    if (_modelInstance != null) {
      try {
        await _modelInstance!.close();
        Log.i('Embedding model closed', 'EmbeddingService');
      } catch (e) {
        Log.e('Error closing embedding model', 'EmbeddingService', e);
      }
    }

    _currentModel = null;
    _modelInstance = null;
    _isReady = false;
    _isLoading = false;

    _emitStatus(EmbeddingStatus.idle, 'Model unloaded');

    if (!_statusController.isClosed) {
      await _statusController.close();
    }
  }

  void _emitStatus(EmbeddingStatus status, String message) {
    if (!_statusController.isClosed) {
      _statusController.add(EmbeddingStatusUpdate(status, message));
    }
  }
}

/// Embedding status enum
enum EmbeddingStatus {
  idle,
  loading,
  ready,
  error,
}

/// Embedding status update
class EmbeddingStatusUpdate {
  final EmbeddingStatus status;
  final String message;
  final DateTime timestamp;

  EmbeddingStatusUpdate(this.status, this.message)
      : timestamp = DateTime.now();
}
