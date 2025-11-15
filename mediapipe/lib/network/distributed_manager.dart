// network/distributed_manager.dart - مدیریت سیستم توزیع‌شده (بدون Worker)
import 'dart:async';
import '../backend/ai_engine.dart';
import '../shared/logger.dart';
import 'routing_client.dart';

class DistributedManager {
  final AIEngine _engine;
  final RoutingClient _client;

  bool _isEnabled = false;

  DistributedManager(this._engine, this._client);

  bool get isEnabled => _isEnabled;

  Future<void> enable() async {
    if (_isEnabled) return;

    try {
      if (!await _client.healthCheck()) {
        throw Exception('Cannot connect to routing server');
      }

      // No longer starting a worker - RAG worker runs separately
      _isEnabled = true;
      Log.s('Distributed mode enabled', 'DistributedManager');
    } catch (e) {
      Log.e('Failed to enable distributed mode', 'DistributedManager', e);
      rethrow;
    }
  }

  Future<void> disable() async {
    if (!_isEnabled) return;

    // No worker to stop - just disable the mode
    _isEnabled = false;
    Log.s('Distributed mode disabled', 'DistributedManager');
  }

  Future<String> processDistributed(String query, Function(String)? onToken) async {
    if (!_isEnabled) throw StateError('Not in distributed mode');

    try {
      // 1. Submit query to routing server
      final queryNumber = await _client.submitQuery(query);
      if (queryNumber == null) throw Exception('Failed to submit query');

      Log.i('Query submitted: $queryNumber', 'DistributedManager');

      // 2. Wait for responses from other nodes (answered by RAG workers)
      final responses = await _waitForResponses(queryNumber);

      Log.i('Received ${responses.length} responses', 'DistributedManager');

      // 3. Generate final answer based on responses
      String finalResponse;
      if (responses.isNotEmpty) {
        finalResponse = await _generateFinalAnswer(query, responses, onToken);
      } else {
        // Fallback to local generation if no responses received
        finalResponse = await _generateDirectly(query, onToken);
      }

      // 4. Cleanup query from server
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

      // Break if we have enough responses (at least 3)
      if (responses.length >= 3) break;

      // Break if we have at least 1 response and waited more than 10 seconds
      if (responses.isNotEmpty &&
          DateTime.now().difference(deadline.subtract(maxWait)).inSeconds > 10) {
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

  print("FINAL RESPONSE : $enhancedPrompt");

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
