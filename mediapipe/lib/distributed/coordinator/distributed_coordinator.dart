// distributed/coordinator/distributed_coordinator.dart - Enhanced version with fixed streaming
import 'dart:async';
import '../../core/interfaces/base_ai_backend.dart';
import '../../core/interfaces/routing_client.dart';
import '../../core/interfaces/distributed_worker.dart';
import '../worker/background_worker_impl.dart';
import '../routing/routing_client_impl.dart';
import '../../utils/logger.dart';

/// Enhanced distributed coordinator with corrected streaming behavior
class EnhancedDistributedCoordinator {
  final BaseAIBackend _backend;
  final EnhancedRoutingClientImpl _routingClient;
  EnhancedBackgroundWorkerImpl? _worker;
  
  bool _isDistributedMode = false;
  StreamSubscription<WorkerEvent>? _workerEventSubscription;
  Timer? _statusTimer;
  
  // Configuration
  final Duration _maxWaitTime = const Duration(seconds: 30);
  final int _maxResponses = 3;
  final Duration _statusCheckInterval = const Duration(seconds: 60);
  
  // Statistics
  int _totalDistributedQueries = 0;
  int _successfulQueries = 0;
  int _timeoutQueries = 0;
  DateTime? _distributedModeStartTime;
  
  EnhancedDistributedCoordinator({
    required BaseAIBackend backend,
    required RoutingClient routingClient,
  }) : _backend = backend, 
       _routingClient = routingClient as EnhancedRoutingClientImpl;
  
  bool get isDistributedMode => _isDistributedMode;
  bool get isWorkerRunning => _worker?.isRunning ?? false;
  String? get nodeId => _routingClient.nodeId;
  
  Stream<WorkerEvent>? get workerEvents => _worker?.events;
  
  /// Get coordinator statistics
  Map<String, dynamic> get statistics => {
    'distributed_mode': _isDistributedMode,
    'node_id': nodeId,
    'worker_running': isWorkerRunning,
    'total_distributed_queries': _totalDistributedQueries,
    'successful_queries': _successfulQueries,
    'timeout_queries': _timeoutQueries,
    'success_rate': _totalDistributedQueries > 0 ? (_successfulQueries / _totalDistributedQueries) : 0.0,
    'uptime': _distributedModeStartTime != null 
        ? DateTime.now().difference(_distributedModeStartTime!).inSeconds 
        : 0,
    'worker_statistics': _worker?.statistics ?? {},
  };

  /// Enable distributed mode with enhanced error handling
  Future<void> enableDistributedMode() async {
    if (_isDistributedMode) {
      Logger.warning("Already in distributed mode", "DistributedCoordinator");
      return;
    }

    Logger.info("Enabling enhanced distributed mode...", "DistributedCoordinator");
    
    try {
      // Check server connection first
      if (!await _routingClient.healthCheck()) {
        throw Exception('Cannot connect to routing server');
      }
      
      // Register node with server
      final registered = await _routingClient.registerNode();
      if (!registered) {
        throw Exception('Failed to register node with routing server');
      }
      
      // Create and start enhanced worker
      _worker = EnhancedBackgroundWorkerImpl(
        backend: _backend,
        routingClient: _routingClient,
      );
      
      // Listen to worker events
      _workerEventSubscription = _worker!.events.listen(_handleWorkerEvent);
      
      await _worker!.start();
      
      _isDistributedMode = true;
      _distributedModeStartTime = DateTime.now();
      
      // Start periodic status checks
      _startStatusChecking();
      
      Logger.success("Enhanced distributed mode enabled with node ID: ${nodeId}", "DistributedCoordinator");
    } catch (e) {
      Logger.error("Failed to enable distributed mode", "DistributedCoordinator", e);
      await _cleanupAfterFailure();
      rethrow;
    }
  }

  /// Disable distributed mode with proper cleanup
  Future<void> disableDistributedMode() async {
    if (!_isDistributedMode) {
      Logger.warning("Already in local mode", "DistributedCoordinator");
      return;
    }

    Logger.info("Disabling enhanced distributed mode...", "DistributedCoordinator");
    
    try {
      // Stop status checking
      _statusTimer?.cancel();
      _statusTimer = null;
      
      // Stop worker
      if (_worker != null) {
        await _worker!.stop();
        await _worker!.dispose();
        _worker = null;
      }
      
      // Cancel event subscription
      await _workerEventSubscription?.cancel();
      _workerEventSubscription = null;
      
      _isDistributedMode = false;
      _distributedModeStartTime = null;
      
      Logger.success("Enhanced distributed mode disabled", "DistributedCoordinator");
    } catch (e) {
      Logger.error("Error disabling distributed mode", "DistributedCoordinator", e);
    }
  }

  /// Process distributed query with delayed streaming (only after aggregation)
  Future<String> processDistributedQuery(
    String query, {
    Function(String)? onStreamToken,
  }) async {
    if (!_isDistributedMode) {
      throw StateError('Not in distributed mode');
    }

    _totalDistributedQueries++;
    final startTime = DateTime.now();
    
    Logger.info("Processing distributed query (${query.length} chars)...", "DistributedCoordinator");
    
    try {
      // 1. Submit query to server
      final queryNumber = await _routingClient.submitQuery(query);
      if (queryNumber == null) {
        throw Exception('Failed to submit query to server');
      }

      Logger.success("Query submitted with number: $queryNumber", "DistributedCoordinator");

      // 2. Wait for responses from other nodes (NO local generation yet)
      final workerResponses = await _waitForWorkerResponses(queryNumber);
      
      Logger.info("Received ${workerResponses.length} responses from other nodes", "DistributedCoordinator");

      // 3. Generate final response based on worker responses
      String finalResponse;
      if (workerResponses.isNotEmpty) {
        // Use enhanced response that synthesizes all inputs
        finalResponse = await _generateEnhancedFinalResponse(
          query,
          workerResponses,
          onStreamToken,
        );
      } else {
        // Fallback: direct generation if no responses
        finalResponse = await _generateResponseWithStreaming(query, onStreamToken);
      }
      
      // 4. Cleanup query from server
      try {
        await _routingClient.cleanupQuery(queryNumber);
      } catch (e) {
        Logger.warning("Failed to cleanup query $queryNumber: $e", "DistributedCoordinator");
      }
      
      _successfulQueries++;
      final processingTime = DateTime.now().difference(startTime);
      Logger.success("Distributed query completed in ${processingTime.inSeconds}s", "DistributedCoordinator");
      
      return finalResponse;

    } catch (e) {
      Logger.error("Error processing distributed query", "DistributedCoordinator", e);
      
      if (e.toString().contains('timeout') || e.toString().contains('Timeout')) {
        _timeoutQueries++;
      }
      
      // Fallback: stream direct response
      if (onStreamToken != null) {
        onStreamToken("در حال استفاده از پاسخ محلی به دلیل خطای توزیع‌شده...\n\n");
        await _generateResponseWithStreaming(query, onStreamToken);
      }

      rethrow;
    }
  }

  /// Generate response with real token-by-token streaming
  Future<String> _generateResponseWithStreaming(
    String query,
    Function(String)? onStreamToken,
  ) async {
    final StringBuffer buffer = StringBuffer();
    try {
      await for (final token in _backend.generateResponseStream(query)) {
        buffer.write(token);
        if (onStreamToken != null) {
          onStreamToken(token);
        }
      }
    } catch (e) {
      final error = "Error: $e";
      buffer.write(error);
      if (onStreamToken != null) {
        onStreamToken(error);
      }
    }
    return buffer.toString().trim();
  }

  /// Generate enhanced final response by synthesizing worker responses
  Future<String> _generateEnhancedFinalResponse(
    String userQuery,
    List<String> workerResponses,
    Function(String)? onStreamToken,
  ) async {
    try {
      // Create context from all responses
      final context = _createEnhancementContext(workerResponses);
      final enhancedPrompt = '''
Based on these diverse perspectives from multiple AI systems:
$context

Please provide a comprehensive, accurate, and well-reasoned response to the following question:
"$userQuery"

Your answer should synthesize the best insights, resolve contradictions if any, and maintain clarity and depth.
''';

      Logger.info("Generating enhanced final response with streaming", "DistributedCoordinator");
      
      final StringBuffer buffer = StringBuffer();
      await for (final token in _backend.generateResponseStream(enhancedPrompt)) {
        buffer.write(token);
        if (onStreamToken != null) {
          onStreamToken(token);
        }
      }

      final result = buffer.toString().trim();
      return result.isEmpty ? "No valid response generated." : result;

    } catch (e) {
      Logger.error("Error generating enhanced final response", "DistributedCoordinator", e);
      // Fallback to direct streaming
      return await _generateResponseWithStreaming(userQuery, onStreamToken);
    }
  }
  
  /// Create structured enhancement context from worker responses
  String _createEnhancementContext(List<String> responses) {
    if (responses.length == 1) {
      return responses.first;
    }
    
    final context = StringBuffer();
    for (int i = 0; i < responses.length; i++) {
      context.writeln('Perspective ${i + 1}: ${responses[i]}');
      if (i < responses.length - 1) {
        context.writeln();
      }
    }
    
    return context.toString();
  }

  /// Wait for worker responses with improved timeout handling
  Future<List<String>> _waitForWorkerResponses(int queryNumber) async {
    const checkInterval = Duration(seconds: 2);
    final deadline = DateTime.now().add(_maxWaitTime);
    List<String> responses = [];
    
    Logger.info("Waiting for responses to query $queryNumber (max ${_maxWaitTime.inSeconds}s)...", "DistributedCoordinator");

    while (DateTime.now().isBefore(deadline)) {
      try {
        responses = await _routingClient.getResponses(queryNumber);
        
        // Check if we have enough responses
        if (responses.length >= _maxResponses) {
          Logger.success("Received sufficient responses (${responses.length}/$_maxResponses)", "DistributedCoordinator");
          break;
        }
        
        // Check if we have at least one response and we're past minimum wait time
        if (responses.isNotEmpty && DateTime.now().difference(deadline.subtract(_maxWaitTime)).inSeconds > 10) {
          Logger.info("Proceeding with ${responses.length} partial responses", "DistributedCoordinator");
          break;
        }
        
      } catch (e) {
        Logger.warning("Error fetching responses for query $queryNumber: $e", "DistributedCoordinator");
      }

      await Future.delayed(checkInterval);
    }

    if (responses.isEmpty) {
      Logger.warning("Timeout waiting for worker responses to query $queryNumber", "DistributedCoordinator");
    } else {
      Logger.success("Collected ${responses.length} responses for query $queryNumber", "DistributedCoordinator");
    }

    return responses;
  }

  /// Handle worker events with enhanced logging and statistics
  void _handleWorkerEvent(WorkerEvent event) {
    switch (event.type) {
      case WorkerEventType.started:
        Logger.success("Worker started: ${event.message}", "DistributedCoordinator");
        break;
      case WorkerEventType.stopped:
        Logger.info("Worker stopped: ${event.message}", "DistributedCoordinator");
        break;
      case WorkerEventType.queryReceived:
        final count = event.data['count'] ?? 0;
        Logger.debug("Worker received $count queries", "DistributedCoordinator");
        break;
      case WorkerEventType.responseSent:
        final queryNumber = event.data['query_number'];
        final processingTime = event.data['processing_time'];
        Logger.success("Worker sent response for query $queryNumber (${processingTime}ms)", "DistributedCoordinator");
        break;
      case WorkerEventType.error:
        Logger.error("Worker error: ${event.message}", "DistributedCoordinator");
        break;
      case WorkerEventType.connectionLost:
        Logger.warning("Worker lost connection to server", "DistributedCoordinator");
        _handleConnectionLoss();
        break;
      case WorkerEventType.connectionRestored:
        Logger.success("Worker restored connection to server", "DistributedCoordinator");
        break;
      default:
        Logger.debug("Worker event: ${event.type} - ${event.message}", "DistributedCoordinator");
    }
  }
  
  /// Handle connection loss with retry logic
  void _handleConnectionLoss() {
    Logger.warning("Handling connection loss...", "DistributedCoordinator");
    
    // Try to re-register node
    Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (!_isDistributedMode) {
        timer.cancel();
        return;
      }
      
      try {
        final reconnected = await _routingClient.forceReregister();
        if (reconnected) {
          Logger.success("Successfully reconnected to server", "DistributedCoordinator");
          timer.cancel();
        }
      } catch (e) {
        Logger.debug("Reconnection attempt failed: $e", "DistributedCoordinator");
      }
    });
  }

  /// Start periodic status checking
  void _startStatusChecking() {
    _statusTimer = Timer.periodic(_statusCheckInterval, (timer) async {
      if (!_isDistributedMode) {
        timer.cancel();
        return;
      }
      
      try {
        final serverStatus = await _routingClient.getServerStatus();
        if (serverStatus != null) {
          final activeNodes = serverStatus['active_nodes'] as int;
          final activeQueries = serverStatus['active_queries'] as int;
          final totalQueries = serverStatus['total_queries_processed'] as int;
          
          Logger.info("Server status - Nodes: $activeNodes, Active queries: $activeQueries, Total processed: $totalQueries", "DistributedCoordinator");
          Logger.info("Coordinator stats - Queries: $_totalDistributedQueries, Success rate: ${(statistics['success_rate'] as double).toStringAsFixed(2)}", "DistributedCoordinator");
        }
      } catch (e) {
        Logger.debug("Status check failed: $e", "DistributedCoordinator");
      }
    });
  }

  /// Cleanup after failure
  Future<void> _cleanupAfterFailure() async {
    try {
      _statusTimer?.cancel();
      _statusTimer = null;
      
      if (_worker != null) {
        await _worker!.stop();
        await _worker!.dispose();
        _worker = null;
      }
      
      await _workerEventSubscription?.cancel();
      _workerEventSubscription = null;
      
      _isDistributedMode = false;
      _distributedModeStartTime = null;
    } catch (e) {
      Logger.warning("Error during cleanup after failure", "DistributedCoordinator");
    }
  }

  /// Check server status and node registration
  Future<bool> checkServerStatus() async {
    try {
      final isHealthy = await _routingClient.healthCheck();
      if (!isHealthy) {
        return false;
      }
      
      // Check if node is properly registered
      if (_routingClient.nodeId == null) {
        Logger.warning("Node not registered, attempting registration", "DistributedCoordinator");
        return await _routingClient.registerNode();
      }
      
      return true;
    } catch (e) {
      Logger.error("Server status check failed", "DistributedCoordinator", e);
      return false;
    }
  }

  /// Set server URL and re-register if needed
  void setServerUrl(String url) {
    _routingClient.setServerUrl(url);
    
    // Re-register if in distributed mode
    if (_isDistributedMode) {
      _routingClient.forceReregister().then((success) {
        if (success) {
          Logger.success("Re-registered with new server URL", "DistributedCoordinator");
        } else {
          Logger.error("Failed to re-register with new server URL", "DistributedCoordinator");
        }
      });
    }
  }

  /// Set polling interval for worker
  void setPollingInterval(Duration interval) {
    _worker?.setPollingInterval(interval);
    Logger.info("Polling interval updated: ${interval.inSeconds}s", "DistributedCoordinator");
  }

  /// Get detailed worker statistics
  Map<String, dynamic> getWorkerStats() {
    if (_worker == null) return {};
    
    return {
      ...statistics,
      'worker_processing_status': _worker!.getProcessingStatus(),
    };
  }

  /// Force cleanup of worker processing state
  void forceWorkerCleanup() {
    _worker?.forceCleanupProcessing();
    Logger.warning("Forced worker cleanup executed", "DistributedCoordinator");
  }

  /// Get node statistics from server
  Future<Map<String, dynamic>?> getNodeServerStats() async {
    return await _routingClient.getNodeStats();
  }

  /// Dispose coordinator with enhanced cleanup
  Future<void> dispose() async {
    Logger.info("Disposing enhanced distributed coordinator...", "DistributedCoordinator");
    
    try {
      await disableDistributedMode();
      await _routingClient.dispose();
      
      Logger.success("Enhanced distributed coordinator disposed", "DistributedCoordinator");
    } catch (e) {
      Logger.error("Error disposing coordinator", "DistributedCoordinator", e);
    }
  }
}