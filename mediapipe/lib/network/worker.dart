// network/worker.dart - Worker برای پردازش queries
import 'dart:async';
import '../backend/ai_engine.dart';
import '../shared/models.dart';
import '../shared/logger.dart';
import 'routing_client.dart';

class Worker {
  final AIEngine _engine;
  final RoutingClient _client;
  
  bool _isRunning = false;
  bool _isPaused = false;
  int _processedCount = 0;
  DateTime? _lastActivity;
  Timer? _pollingTimer;
  final Set<int> _processedIds = {};

  // Stream برای لاگ‌های Worker
  final StreamController<WorkerLog> _logController = StreamController<WorkerLog>.broadcast();

  Worker(this._engine, this._client);

  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;
  int get processedCount => _processedCount;
  DateTime? get lastActivity => _lastActivity;
  Stream<WorkerLog> get logStream => _logController.stream;

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
    if (!_engine.isReady) throw StateError('Engine not ready');

    final registered = await _client.registerNode();
    if (!registered) throw Exception('Failed to register with server');

    _isRunning = true;
    _isPaused = false;
    _lastActivity = DateTime.now();
    
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
    
    _emitLog('Worker شروع به کار کرد', WorkerLogLevel.success, {
      'node_id': _client.nodeId,
    });
    Log.s('Worker started', 'Worker');
  }

  Future<void> stop() async {
    if (!_isRunning) return;

    _isRunning = false;
    _isPaused = false;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    
    if (_engine.isGenerating) {
      await _engine.stop();
    }
    
    _emitLog('Worker متوقف شد', WorkerLogLevel.info, {
      'processed_count': _processedCount,
    });
    Log.s('Worker stopped', 'Worker');
  }

  Future<void> pause() async {
    if (!_isRunning || _isPaused) return;
    _isPaused = true;
    _pollingTimer?.cancel();
    if (_engine.isGenerating) await _engine.stop();
    
    _emitLog('Worker موقتاً متوقف شد', WorkerLogLevel.warning);
  }

  Future<void> resume() async {
    if (!_isRunning || !_isPaused) return;
    _isPaused = false;
    _lastActivity = DateTime.now();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
    
    _emitLog('Worker از سر گرفته شد', WorkerLogLevel.success);
  }

  Future<void> _poll() async {
    if (!_isRunning || _isPaused || _engine.isGenerating) return;

    try {
      final queries = await _client.getNewQueries();
      if (queries.isEmpty) return;

      _emitLog('${queries.length} Query جدید دریافت شد', WorkerLogLevel.info, {
        'count': queries.length,
      });

      for (final query in queries) {
        if (!_isRunning || _isPaused) break;
        if (_processedIds.contains(query.queryNumber)) {
          _emitLog('Query #${query.queryNumber} قبلاً پردازش شده', WorkerLogLevel.warning);
          continue;
        }

        _processedIds.add(query.queryNumber);
        await _processQuery(query);
      }
    } catch (e) {
      _emitLog('خطا در Polling: $e', WorkerLogLevel.error);
      Log.e('Polling error', 'Worker', e);
    }
  }

  Future<void> _processQuery(DistributedQuery query) async {
    try {
      final queryPreview = query.query.length > 50 
          ? '${query.query.substring(0, 50)}...' 
          : query.query;
      
      _emitLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', WorkerLogLevel.info);
      _emitLog('🔄 شروع پردازش Query #${query.queryNumber}', WorkerLogLevel.info, {
        'query': queryPreview,
        'query_full': query.query,
      });
      
      Log.i('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', 'Worker');
      Log.i('🔄 Processing query ${query.queryNumber}', 'Worker');
      Log.i('📝 Query text: ${query.query}', 'Worker');
      Log.i('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', 'Worker');
      
      _lastActivity = DateTime.now();
      final startTime = DateTime.now();
      final buffer = StringBuffer();
      int tokenCount = 0;

      // استفاده از generateStream برای دریافت توکن به توکن
      await for (final token in _engine.generateStream(query.query)) {
        if (!_isRunning || _isPaused) {
          _emitLog('⚠️ تولید متوقف شد (Worker متوقف/موقت)', WorkerLogLevel.warning);
          Log.w('⚠️ Generation stopped (worker paused/stopped)', 'Worker');
          break;
        }
        
        buffer.write(token);
        tokenCount++;
        
        // لاگ هر توکن در کنسول
        Log.i('🔤 Token #$tokenCount: "$token"', 'Worker');
        
        // ارسال توکن به Stream (هر 5 توکن یکبار برای کاهش overhead)
        // if (tokenCount % 5 == 0) {
        //   _emitLog('🔤 تولید توکن...', WorkerLogLevel.token, {
        //     'token_count': tokenCount,
        //     'current_token': token,
        //     'query_number': query.queryNumber,
        //   });
        // }
          _emitLog(' $token', WorkerLogLevel.token, {
            'token_count': tokenCount,
            'current_token': token,
            'query_number': query.queryNumber,
          });
      }
      
      final response = buffer.toString().trim();
      final processingTime = DateTime.now().difference(startTime);
      
      Log.i('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', 'Worker');
      Log.s('✅ Generation completed!', 'Worker');
      Log.i('📊 Total tokens: $tokenCount', 'Worker');
      Log.i('⏱️ Duration: ${processingTime.inMilliseconds}ms', 'Worker');
      Log.i('📏 Response length: ${response.length} chars', 'Worker');
      
      if (tokenCount > 0) {
        final tokensPerSecond = (tokenCount / (processingTime.inMilliseconds / 1000.0)).toStringAsFixed(2);
        Log.i('⚡ Speed: $tokensPerSecond tokens/sec', 'Worker');
      }
      Log.i('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', 'Worker');
      
      if (!_isRunning || _isPaused) return;

      final distributedResponse = DistributedResponse(
        queryNumber: query.queryNumber,
        response: response,
        metadata: {
          'node_id': _client.nodeId ?? 'unknown',
          'engine': _engine.name,
          'processing_time_ms': processingTime.inMilliseconds,
          'token_count': tokenCount,
          'response_length': response.length,
          'tokens_per_second': tokenCount > 0 
              ? (tokenCount / (processingTime.inMilliseconds / 1000.0)) 
              : 0,
        },
      );

      _emitLog('📤 در حال ارسال پاسخ به سرور...', WorkerLogLevel.info);
      Log.i('📤 Sending response to server...', 'Worker');
      
      final success = await _client.sendResponse(distributedResponse);
      
      if (success) {
        _processedCount++;
        final responsePreview = response.length > 50 
            ? '${response.substring(0, 50)}...' 
            : response;
        
        _emitLog(
          '✅ پاسخ Query #${query.queryNumber} ارسال شد', 
          WorkerLogLevel.success, 
          {
            'response': responsePreview,
            'response_full': response,
            'processing_time': '${processingTime.inMilliseconds}ms',
            'token_count': tokenCount,
            'total_processed': _processedCount,
          }
        );
        
        Log.s('✅ Response sent successfully for query ${query.queryNumber}', 'Worker');
        Log.i('📈 Total processed queries: $_processedCount', 'Worker');
      } else {
        _emitLog('❌ خطا در ارسال پاسخ Query #${query.queryNumber}', WorkerLogLevel.error);
        Log.e('❌ Failed to send response for query ${query.queryNumber}', 'Worker');
      }
      
      _emitLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', WorkerLogLevel.info);
      Log.i('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n', 'Worker');
      
    } catch (e) {
      _emitLog('❌ خطا در پردازش Query #${query.queryNumber}: $e', WorkerLogLevel.error);
      Log.e('❌ Error processing query ${query.queryNumber}', 'Worker', e);
      Log.i('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n', 'Worker');
    }
  }

  void dispose() {
    stop();
    if (!_logController.isClosed) {
      _logController.close();
    }
  }
}