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

  Worker(this._engine, this._client);

  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;
  int get processedCount => _processedCount;
  DateTime? get lastActivity => _lastActivity;

  Future<void> start() async {
    if (_isRunning) return;
    if (!_engine.isReady) throw StateError('Engine not ready');

    final registered = await _client.registerNode();
    if (!registered) throw Exception('Failed to register with server');

    _isRunning = true;
    _isPaused = false;
    _lastActivity = DateTime.now();
    
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
    
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
    
    Log.s('Worker stopped', 'Worker');
  }

  Future<void> pause() async {
    if (!_isRunning || _isPaused) return;
    _isPaused = true;
    _pollingTimer?.cancel();
    if (_engine.isGenerating) await _engine.stop();
  }

  Future<void> resume() async {
    if (!_isRunning || !_isPaused) return;
    _isPaused = false;
    _lastActivity = DateTime.now();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  Future<void> _poll() async {
    if (!_isRunning || _isPaused || _engine.isGenerating) return;

    try {
      final queries = await _client.getNewQueries();
      if (queries.isEmpty) return;

      for (final query in queries) {
        if (!_isRunning || _isPaused) break;
        if (_processedIds.contains(query.queryNumber)) continue;

        _processedIds.add(query.queryNumber);
        await _processQuery(query);
      }
    } catch (e) {
      Log.e('Polling error', 'Worker', e);
    }
  }

  Future<void> _processQuery(DistributedQuery query) async {
    try {
      Log.i('Processing query ${query.queryNumber}', 'Worker');
      _lastActivity = DateTime.now();

      final response = await _engine.generate(query.query);
      
      if (!_isRunning || _isPaused) return;

      final distributedResponse = DistributedResponse(
        queryNumber: query.queryNumber,
        response: response,
        metadata: {
          'node_id': _client.nodeId ?? 'unknown',
          'engine': _engine.name,
        },
      );

      final success = await _client.sendResponse(distributedResponse);
      
      if (success) {
        _processedCount++;
        Log.s('Response sent for query ${query.queryNumber}', 'Worker');
      }
    } catch (e) {
      Log.e('Error processing query ${query.queryNumber}', 'Worker', e);
    }
  }

  void dispose() {
    stop();
  }
}