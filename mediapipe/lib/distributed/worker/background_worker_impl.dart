// distributed/worker/background_worker_impl.dart - Enhanced version
import 'dart:async';
import '../../core/interfaces/base_ai_backend.dart';
import '../../core/interfaces/distributed_worker.dart';
import '../../core/interfaces/routing_client.dart';
import '../routing/routing_client_impl.dart';
import '../../utils/logger.dart';

/// Enhanced background worker with improved node management and self-query prevention
class EnhancedBackgroundWorkerImpl implements DistributedWorker {
  final BaseAIBackend _backend;
  final EnhancedRoutingClientImpl _routingClient;
  
  bool _isRunning = false;
  bool _isPaused = false;
  int _processedQueries = 0;
  DateTime? _lastActivity;
  Duration _pollingInterval = const Duration(seconds: 3);
  
  Timer? _pollingTimer;
  Timer? _statusTimer;
  final Set<int> _processedQueryIds = <int>{};
  final StreamController<WorkerEvent> _eventController = StreamController<WorkerEvent>.broadcast();
  
  // Worker configuration
  final int _maxConcurrentQueries = 3;
  final Duration _responseTimeout = const Duration(seconds: 120);
  final Map<int, DateTime> _processingQueries = {};
  
  // Statistics
  int _successfulResponses = 0;
  int _failedResponses = 0;
  int _skippedQueries = 0;
  DateTime? _startTime;
  
  EnhancedBackgroundWorkerImpl({
    required BaseAIBackend backend,
    required RoutingClient routingClient,
  }) : _backend = backend, 
       _routingClient = routingClient as EnhancedRoutingClientImpl {
    
    // Set node capabilities based on backend
    _setupNodeCapabilities();
  }
  
  void _setupNodeCapabilities() {
    final capabilities = <String, dynamic>{
      'backend_name': _backend.backendName,
      'supported_platforms': _backend.supportedPlatforms,
      'max_concurrent_queries': _maxConcurrentQueries,
      'response_timeout': _responseTimeout.inSeconds,
    };
    
    final nodeInfo = <String, dynamic>{
      'worker_version': '2.0.0',
      'features': [
        'self_query_prevention',
        'concurrent_processing',
        'timeout_handling',
        'statistics_tracking'
      ],
    };
    
    _routingClient.setNodeCapabilities(capabilities);
    _routingClient.setNodeInfo(nodeInfo);
  }
  
  @override
  bool get isRunning => _isRunning;
  
  @override
  bool get isPaused => _isPaused;
  
  @override
  int get processedQueries => _processedQueries;
  
  @override
  DateTime? get lastActivity => _lastActivity;
  
  @override
  Stream<WorkerEvent> get events => _eventController.stream;
  
  /// Get worker statistics
  Map<String, dynamic> get statistics => {
    'processed_queries': _processedQueries,
    'successful_responses': _successfulResponses,
    'failed_responses': _failedResponses,
    'skipped_queries': _skippedQueries,
    'success_rate': _processedQueries > 0 ? (_successfulResponses / _processedQueries) : 0.0,
    'uptime': _startTime != null ? DateTime.now().difference(_startTime!).inSeconds : 0,
    'current_processing': _processingQueries.length,
    'node_id': _routingClient.nodeId,
  };

  @override
  Future<void> start() async {
    if (_isRunning) {
      Logger.warning("Worker already running", "BackgroundWorker");
      return;
    }

    if (!_backend.isInitialized) {
      _emitEvent(WorkerEventType.error, message: 'Backend not initialized');
      throw StateError('Backend must be initialized before starting worker');
    }

    try {
      Logger.info("Starting enhanced background worker...", "BackgroundWorker");
      
      // Ensure node is registered with server
      final registered = await _routingClient.registerNode();
      if (!registered) {
        throw Exception('Failed to register node with routing server');
      }
      
      _isRunning = true;
      _isPaused = false;
      _startTime = DateTime.now();
      _lastActivity = DateTime.now();
      
      _emitEvent(WorkerEventType.started, 
        data: {'node_id': _routingClient.nodeId},
        message: 'Enhanced worker started successfully');
      
      // Start polling and status timers
      _startPolling();
      _startStatusReporting();
      
      Logger.success("Enhanced background worker started with node ID: ${_routingClient.nodeId}", "BackgroundWorker");
    } catch (e) {
      Logger.error("Failed to start worker", "BackgroundWorker", e);
      _isRunning = false;
      _emitEvent(WorkerEventType.error, message: 'Failed to start worker: $e');
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    if (!_isRunning) {
      Logger.warning("Worker already stopped", "BackgroundWorker");
      return;
    }

    Logger.info("Stopping enhanced background worker...", "BackgroundWorker");
    
    _isRunning = false;
    _isPaused = false;
    
    // Cancel timers
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _statusTimer?.cancel();
    _statusTimer = null;
    
    // Stop any ongoing generation
    if (_backend.isGenerating) {
      await _backend.stopGeneration();
    }
    
    // Clear processing queries
    _processingQueries.clear();
    
    _emitEvent(WorkerEventType.stopped, 
      data: statistics,
      message: 'Worker stopped - Processed $_processedQueries queries');
      
    Logger.success("Enhanced background worker stopped", "BackgroundWorker");
  }

  @override
  Future<void> pause() async {
    if (!_isRunning || _isPaused) {
      Logger.warning("Cannot pause - not running or already paused", "BackgroundWorker");
      return;
    }

    Logger.info("Pausing enhanced background worker...", "BackgroundWorker");
    
    _isPaused = true;
    
    // Cancel polling timer but keep status timer
    _pollingTimer?.cancel();
    _pollingTimer = null;
    
    // Stop any ongoing generation
    if (_backend.isGenerating) {
      await _backend.stopGeneration();
    }
    
    _emitEvent(WorkerEventType.paused, message: 'Worker paused');
    Logger.success("Enhanced background worker paused", "BackgroundWorker");
  }

  @override
  Future<void> resume() async {
    if (!_isRunning || !_isPaused) {
      Logger.warning("Cannot resume - not running or not paused", "BackgroundWorker");
      return;
    }

    Logger.info("Resuming enhanced background worker...", "BackgroundWorker");
    
    _isPaused = false;
    _lastActivity = DateTime.now();
    
    // Restart polling
    _startPolling();
    
    _emitEvent(WorkerEventType.resumed, message: 'Worker resumed');
    Logger.success("Enhanced background worker resumed", "BackgroundWorker");
  }

  @override
  Future<bool> checkServerConnection() async {
    return await _routingClient.healthCheck();
  }

  @override
  void setPollingInterval(Duration interval) {
    _pollingInterval = interval;
    Logger.info("Polling interval updated: ${interval.inSeconds}s", "BackgroundWorker");
    
    if (_isRunning && !_isPaused) {
      // Restart polling with new interval
      _pollingTimer?.cancel();
      _startPolling();
    }
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(_pollingInterval, (timer) async {
      if (!_isRunning || _isPaused) {
        timer.cancel();
        return;
      }

      // Don't process new queries if we're at capacity or backend is busy with user queries
      if (_processingQueries.length >= _maxConcurrentQueries || _backend.isGenerating) {
        return;
      }

      await _processQueries();
    });
  }
  
  void _startStatusReporting() {
    _statusTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (!_isRunning) {
        timer.cancel();
        return;
      }
      
      try {
        // Get server status and log our node info
        final serverStatus = await _routingClient.getServerStatus();
        if (serverStatus != null) {
          final activeNodes = serverStatus['active_nodes'] as int;
          final activeQueries = serverStatus['active_queries'] as int;
          
          Logger.info("Server status: $activeNodes nodes, $activeQueries queries | Worker stats: ${statistics['processed_queries']} processed, ${statistics['success_rate'].toStringAsFixed(2)} success rate", "BackgroundWorker");
        }
      } catch (e) {
        Logger.debug("Status reporting failed: $e", "BackgroundWorker");
      }
    });
  }

  Future<void> _processQueries() async {
    try {
      // Clean up expired processing queries
      _cleanupExpiredQueries();
      
      // Get new queries from server
      final queries = await _routingClient.getNewQueries();
      if (queries.isEmpty) return;

      Logger.debug("Received ${queries.length} queries from server", "BackgroundWorker");

      _emitEvent(WorkerEventType.queryReceived, 
        data: {'count': queries.length},
        message: 'Received ${queries.length} queries');

      for (final query in queries) {
        if (!_isRunning || _isPaused) break;
        
        // Skip if we're at capacity
        if (_processingQueries.length >= _maxConcurrentQueries) {
          Logger.debug("At capacity, skipping query ${query.queryNumber}", "BackgroundWorker");
          break;
        }
        
        // Skip already processed queries
        if (_processedQueryIds.contains(query.queryNumber)) {
          Logger.debug("Skipping already processed query ${query.queryNumber}", "BackgroundWorker");
          _skippedQueries++;
          continue;
        }

        // Process query asynchronously
        _processQueryAsync(query);
      }
    } catch (e) {
      Logger.error("Error in query processing loop", "BackgroundWorker", e);
      _emitEvent(WorkerEventType.error, 
        message: 'Error processing queries: $e');
      
      // Check if it's a connection issue
      if (!await _routingClient.healthCheck()) {
        _emitEvent(WorkerEventType.connectionLost, 
          message: 'Lost connection to routing server');
      }
    }
  }

  void _processQueryAsync(DistributedQuery query) {
    // Mark as processing
    _processingQueries[query.queryNumber] = DateTime.now();
    
    // Process in background
    _processQuery(query).then((_) {
      // Remove from processing
      _processingQueries.remove(query.queryNumber);
    }).catchError((error) {
      Logger.error("Async query processing error", "BackgroundWorker", error);
      _processingQueries.remove(query.queryNumber);
    });
  }

  Future<void> _processQuery(DistributedQuery query) async {
    try {
      Logger.info("Processing query ${query.queryNumber}: ${query.query.length > 50 ? query.query.substring(0, 50) + '...' : query.query}", "BackgroundWorker");
      
      _processedQueryIds.add(query.queryNumber);
      _lastActivity = DateTime.now();

      // Generate response using backend
      final response = await _generateResponse(query.query);
      
      if (!_isRunning || _isPaused) {
        Logger.debug("Worker stopped while processing query ${query.queryNumber}", "BackgroundWorker");
        return;
      }
      
      // Send response to server
      final distributedResponse = DistributedResponse(
        queryNumber: query.queryNumber,
        response: response,
        metadata: {
          'node_id': _routingClient.nodeId ?? 'unknown',
          'backend': _backend.backendName,
          'processed_at': DateTime.now().toIso8601String(),
          'processing_time': DateTime.now().difference(_processingQueries[query.queryNumber] ?? DateTime.now()).inMilliseconds,
        },
      );

      final success = await _routingClient.sendResponse(distributedResponse);
      
      if (success) {
        _processedQueries++;
        _successfulResponses++;
        Logger.success("Response sent for query ${query.queryNumber}", "BackgroundWorker");
        _emitEvent(WorkerEventType.responseSent, 
          data: {
            'query_number': query.queryNumber,
            'response_length': response.length,
            'processing_time': DateTime.now().difference(_processingQueries[query.queryNumber] ?? DateTime.now()).inMilliseconds,
          },
          message: 'Response sent for query ${query.queryNumber}');
      } else {
        _failedResponses++;
        Logger.warning("Failed to send response for query ${query.queryNumber}", "BackgroundWorker");
        _emitEvent(WorkerEventType.error, 
          message: 'Failed to send response for query ${query.queryNumber}');
      }
      
      _emitEvent(WorkerEventType.queryProcessed, 
        data: {
          'query_number': query.queryNumber, 
          'success': success,
          'statistics': statistics,
        });

    } catch (e) {
      _failedResponses++;
      Logger.error("Error processing query ${query.queryNumber}", "BackgroundWorker", e);
      _emitEvent(WorkerEventType.error, 
        message: 'Error processing query ${query.queryNumber}: $e');
    }
  }

  Future<String> _generateResponse(String query) async {
    try {
      // Add timeout to prevent hanging
      return await _backend.generateResponse(query).timeout(_responseTimeout);
    } catch (TimeoutException) {
      Logger.warning("Response generation timed out", "BackgroundWorker");
      return "Error: Response generation timed out after ${_responseTimeout.inSeconds} seconds.";
    // ignore: dead_code_catch_following_catch
    } catch (e) {
      Logger.error("Error generating response", "BackgroundWorker", e);
      return "Error generating response: $e";
    }
  }
  
  void _cleanupExpiredQueries() {
    final now = DateTime.now();
    final expiredQueries = <int>[];
    
    _processingQueries.forEach((queryId, startTime) {
      if (now.difference(startTime) > _responseTimeout) {
        expiredQueries.add(queryId);
      }
    });
    
    for (final queryId in expiredQueries) {
      Logger.warning("Cleaning up expired query $queryId", "BackgroundWorker");
      _processingQueries.remove(queryId);
      _failedResponses++;
    }
  }

  void _emitEvent(WorkerEventType type, {Map<String, dynamic>? data, String? message}) {
    final event = WorkerEvent(
      type: type,
      data: data ?? {},
      message: message,
    );
    
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
    
    // Log important events
    switch (type) {
      case WorkerEventType.error:
        Logger.error(message ?? 'Unknown error', "BackgroundWorker");
        break;
      case WorkerEventType.connectionLost:
        Logger.warning(message ?? 'Connection lost', "BackgroundWorker");
        break;
      case WorkerEventType.started:
      case WorkerEventType.stopped:
        Logger.success(message ?? type.toString(), "BackgroundWorker");
        break;
      default:
        Logger.debug(message ?? type.toString(), "BackgroundWorker");
    }
  }

  /// Get current processing status
  Map<String, dynamic> getProcessingStatus() {
    return {
      'is_running': _isRunning,
      'is_paused': _isPaused,
      'processing_queries': _processingQueries.keys.toList(),
      'capacity_used': _processingQueries.length,
      'max_capacity': _maxConcurrentQueries,
      'statistics': statistics,
    };
  }

  /// Force cleanup of all processing queries
  void forceCleanupProcessing() {
    Logger.warning("Force cleaning up ${_processingQueries.length} processing queries", "BackgroundWorker");
    _processingQueries.clear();
  }

  Future<void> dispose() async {
    await stop();
    
    if (!_eventController.isClosed) {
      await _eventController.close();
    }
    
    await _routingClient.dispose();
    Logger.info("Enhanced background worker disposed", "BackgroundWorker");
  }
}