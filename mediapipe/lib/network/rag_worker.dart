// network/rag_worker.dart - Worker for RAG query processing
import 'dart:async';
import '../rag/rag_manager.dart';
import '../shared/models.dart';
import '../shared/logger.dart';
import 'routing_client.dart';

class RAGWorker {
  final RAGManager _ragManager;
  final RoutingClient _client;

  bool _isRunning = false;
  bool _isPaused = false;
  int _processedCount = 0;
  DateTime? _lastActivity;
  Timer? _pollingTimer;
  final Set<int> _processedIds = {};

  // Stream for Worker logs
  final StreamController<WorkerLog> _logController = StreamController<WorkerLog>.broadcast();

  RAGWorker(this._ragManager, this._client);

  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;
  int get processedCount => _processedCount;
  DateTime? get lastActivity => _lastActivity;
  Stream<WorkerLog> get logStream => _logController.stream;
  bool get isReady => _ragManager.isReady;

  void _emitLog(String message, WorkerLogLevel level, [Map<String, dynamic>? data]) {
    if (!_logController.isClosed) {
      _logController.add(WorkerLog(
        message: message,
        level: level,
        data: data,
      ));
    }
  }

  Future<void> start() async {
    if (_isRunning) return;
    if (!_ragManager.isReady) {
      _emitLog('RAG system not ready', WorkerLogLevel.warning);
      Log.w('Cannot start RAGWorker: RAG system not ready', 'RAGWorker');
      return;
    }

    final registered = await _client.registerNode();
    if (!registered) {
      _emitLog('Failed to register with server', WorkerLogLevel.error);
      throw Exception('Failed to register with server');
    }

    _isRunning = true;
    _isPaused = false;
    _lastActivity = DateTime.now();

    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());

    _emitLog('RAG Worker started', WorkerLogLevel.success, {
      'node_id': _client.nodeId,
    });
    Log.s('RAG Worker started', 'RAGWorker');
  }

  Future<void> stop() async {
    if (!_isRunning) return;

    _isRunning = false;
    _isPaused = false;
    _pollingTimer?.cancel();
    _pollingTimer = null;

    _emitLog('RAG Worker stopped', WorkerLogLevel.info, {
      'processed_count': _processedCount,
    });
    Log.s('RAG Worker stopped', 'RAGWorker');
  }

  Future<void> pause() async {
    if (!_isRunning || _isPaused) return;
    _isPaused = true;
    _pollingTimer?.cancel();

    _emitLog('RAG Worker paused', WorkerLogLevel.warning);
  }

  Future<void> resume() async {
    if (!_isRunning || !_isPaused) return;
    _isPaused = false;
    _lastActivity = DateTime.now();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());

    _emitLog('RAG Worker resumed', WorkerLogLevel.success);
  }

  Future<void> _poll() async {
    if (!_isRunning || _isPaused) return;

    try {
      final queries = await _client.getNewQueries();
      if (queries.isEmpty) return;

      _emitLog('${queries.length} new RAG queries received', WorkerLogLevel.info, {
        'count': queries.length,
      });

      for (final query in queries) {
        if (!_isRunning || _isPaused) break;
        if (_processedIds.contains(query.queryNumber)) {
          _emitLog('Query #${query.queryNumber} already processed', WorkerLogLevel.warning);
          continue;
        }

        _processedIds.add(query.queryNumber);
        await _processQuery(query);
      }
    } catch (e) {
      _emitLog('Polling error: $e', WorkerLogLevel.error);
      Log.e('Polling error', 'RAGWorker', e);
    }
  }

  Future<void> _processQuery(DistributedQuery query) async {
    try {
      final queryPreview = query.query.length > 50
          ? '${query.query.substring(0, 50)}...'
          : query.query;

      _emitLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', WorkerLogLevel.info);
      _emitLog('🔍 Processing RAG Query #${query.queryNumber}', WorkerLogLevel.info, {
        'query': queryPreview,
        'query_full': query.query,
      });

      Log.i('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', 'RAGWorker');
      Log.i('🔍 Processing RAG query ${query.queryNumber}', 'RAGWorker');
      Log.i('📝 Query text: ${query.query}', 'RAGWorker');
      Log.i('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', 'RAGWorker');

      _lastActivity = DateTime.now();
      final startTime = DateTime.now();

      // Search for similar chunks using vector search
      _emitLog('🔎 Searching vector database...', WorkerLogLevel.info);
      Log.i('🔎 Searching vector database...', 'RAGWorker');

      final similarChunks = await _ragManager.searchSimilar(query.query, maxResults: 2);

      if (similarChunks.isEmpty) {
        _emitLog('⚠️ No relevant documents found - skipping response', WorkerLogLevel.warning);
        Log.w('No relevant documents found for query - not sending response to server', 'RAGWorker');
        Log.i('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', 'RAGWorker');
        return;
      }

      _emitLog('✅ Found ${similarChunks.length} relevant chunks', WorkerLogLevel.success);
      Log.s('Found ${similarChunks.length} relevant chunks', 'RAGWorker');

      // Build response from chunks
      final responseBuffer = StringBuffer();
      responseBuffer.writeln('Found ${similarChunks.length} relevant documents:\n');

      for (int i = 0; i < similarChunks.length; i++) {
        final chunk = similarChunks[i];
        // responseBuffer.writeln('--- Document ${i + 1} (Source: ${chunk.source}) ---');
        responseBuffer.writeln(chunk.content);
        responseBuffer.writeln();

        Log.i('  Chunk ${i + 1}: source=${chunk.source}, length=${chunk.content?.length ?? 0} chars', 'RAGWorker');
      }

      final response = responseBuffer.toString().trim();
      final processingTime = DateTime.now().difference(startTime);

      Log.i('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', 'RAGWorker');
      Log.s('✅ RAG search completed!', 'RAGWorker');
      Log.i('📊 Found chunks: ${similarChunks.length}', 'RAGWorker');
      Log.i('⏱️ Duration: ${processingTime.inMilliseconds}ms', 'RAGWorker');
      Log.i('📏 Response length: ${response.length} chars', 'RAGWorker');
      Log.i('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', 'RAGWorker');

      if (!_isRunning || _isPaused) return;

      final distributedResponse = DistributedResponse(
        queryNumber: query.queryNumber,
        response: response,
        metadata: {
          'node_id': _client.nodeId ?? 'unknown',
          'rag_worker': true,
          'found_chunks': similarChunks.length,
          'processing_time_ms': processingTime.inMilliseconds,
          'response_length': response.length,
          'sources': similarChunks.map((c) => c.source).toSet().toList(),
        },
      );

      await _sendResponse(query.queryNumber, distributedResponse, startTime);

    } catch (e) {
      _emitLog('❌ Error processing Query #${query.queryNumber}: $e', WorkerLogLevel.error);
      Log.e('❌ Error processing query ${query.queryNumber}', 'RAGWorker', e);
      Log.i('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n', 'RAGWorker');
    }
  }

  Future<void> _sendResponse(
    int queryNumber,
    DistributedResponse response,
    DateTime startTime,
  ) async {
    _emitLog('📤 Sending response to server...', WorkerLogLevel.info);
    Log.i('📤 Sending response to server...', 'RAGWorker');

    final success = await _client.sendResponse(response);

    if (success) {
      _processedCount++;
      final responsePreview = response.response.length > 50
          ? '${response.response.substring(0, 50)}...'
          : response.response;

      final processingTime = DateTime.now().difference(startTime);

      _emitLog(
        '✅ Response for Query #$queryNumber sent',
        WorkerLogLevel.success,
        {
          'response': responsePreview,
          'response_full': response.response,
          'processing_time': '${processingTime.inMilliseconds}ms',
          'total_processed': _processedCount,
        },
      );

      Log.s('✅ Response sent successfully for query $queryNumber', 'RAGWorker');
      Log.i('📈 Total processed queries: $_processedCount', 'RAGWorker');
    } else {
      _emitLog('❌ Failed to send response for Query #$queryNumber', WorkerLogLevel.error);
      Log.e('❌ Failed to send response for query $queryNumber', 'RAGWorker');
    }

    _emitLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', WorkerLogLevel.info);
    Log.i('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n', 'RAGWorker');
  }

  void dispose() {
    stop();
    if (!_logController.isClosed) {
      _logController.close();
    }
  }
}
