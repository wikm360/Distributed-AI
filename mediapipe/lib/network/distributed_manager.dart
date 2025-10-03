// network/distributed_manager.dart - مدیریت سیستم توزیع‌شده
import 'dart:async';
import '../backend/ai_engine.dart';
import '../shared/logger.dart';
import '../shared/models.dart';
import 'routing_client.dart';
import 'worker.dart';

class DistributedManager {
  final AIEngine _engine;
  final RoutingClient _client;
  Worker? _worker;
  
  bool _isEnabled = false;

  DistributedManager(this._engine, this._client);

  bool get isEnabled => _isEnabled;
  bool get isWorkerRunning => _worker?.isRunning ?? false;
  
  // Stream لاگ‌های Worker
  Stream<WorkerLog>? get workerLogStream => _worker?.logStream;

  Future<void> enable() async {
    if (_isEnabled) return;

    try {
      if (!await _client.healthCheck()) {
        throw Exception('Cannot connect to routing server');
      }

      _worker = Worker(_engine, _client);
      await _worker!.start();
      
      _isEnabled = true;
      Log.s('Distributed mode enabled', 'DistributedManager');
    } catch (e) {
      Log.e('Failed to enable distributed mode', 'DistributedManager', e);
      rethrow;
    }
  }

  Future<void> disable() async {
    if (!_isEnabled) return;

    if (_worker != null) {
      await _worker!.stop();
      _worker = null;
    }
    
    _isEnabled = false;
    Log.s('Distributed mode disabled', 'DistributedManager');
  }

  Future<String> processDistributed(String query, Function(String)? onToken) async {
    if (!_isEnabled) throw StateError('Not in distributed mode');

    try {
      // 1. Submit query
      final queryNumber = await _client.submitQuery(query);
      if (queryNumber == null) throw Exception('Failed to submit query');

      Log.i('Query submitted: $queryNumber', 'DistributedManager');

      // 2. Wait for responses
      final responses = await _waitForResponses(queryNumber);
      
      Log.i('Received ${responses.length} responses', 'DistributedManager');

      // 3. Generate final answer
      String finalResponse;
      if (responses.isNotEmpty) {
        finalResponse = await _generateFinalAnswer(query, responses, onToken);
      } else {
        finalResponse = await _generateDirectly(query, onToken);
      }

      // 4. Cleanup
      await _client.cleanupQuery(queryNumber);
      
      return finalResponse;
    } catch (e) {
      Log.e('Distributed processing failed', 'DistributedManager', e);
      rethrow;
    }
  }

  Future<List<String>> _waitForResponses(int queryNumber) async {
    const maxWait = Duration(seconds: 30);
    const checkInterval = Duration(seconds: 2);
    final deadline = DateTime.now().add(maxWait);
    List<String> responses = [];

    while (DateTime.now().isBefore(deadline)) {
      responses = await _client.getResponses(queryNumber);
      
      if (responses.length >= 3) break;
      if (responses.isNotEmpty && DateTime.now().difference(deadline.subtract(maxWait)).inSeconds > 10) {
        break;
      }
      
      await Future.delayed(checkInterval);
    }

    return responses;
  }

  Future<String> _generateFinalAnswer(
    String query, 
    List<String> responses, 
    Function(String)? onToken
  ) async {
    final context = responses.length == 1 
        ? responses.first
        : responses.asMap().entries.map((e) => 'Perspective ${e.key + 1}: ${e.value}').join('\n\n');
    
    final enhancedPrompt = '''
Based on these perspectives from multiple AI systems:
$context

Please provide a comprehensive response to: "$query"
''';

    final buffer = StringBuffer();
    await for (final token in _engine.generateStream(enhancedPrompt)) {
      buffer.write(token);
      onToken?.call(token);
    }

    return buffer.toString().trim();
  }

  Future<String> _generateDirectly(String query, Function(String)? onToken) async {
    final buffer = StringBuffer();
    await for (final token in _engine.generateStream(query)) {
      buffer.write(token);
      onToken?.call(token);
    }
    return buffer.toString().trim();
  }

  void dispose() {
    disable();
    _client.dispose();
  }
}