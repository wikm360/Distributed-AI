// distributed/routing/routing_client_impl.dart - Enhanced version
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../core/interfaces/routing_client.dart';
import '../../core/interfaces/distributed_worker.dart';
import '../../utils/logger.dart';
import 'package:flutter/foundation.dart';

/// Enhanced client for routing server communication with node identification
class EnhancedRoutingClientImpl implements RoutingClient {
  String _serverUrl;
  bool _isConnected = false;
  DateTime? _lastSuccessfulConnection;
  String? _nodeId;
  
  // Client configuration
  final Duration _timeout = const Duration(seconds: 10);
  final Duration _shortTimeout = const Duration(seconds: 5);
  
  // Node capabilities and info
  Map<String, dynamic> _nodeCapabilities = {};
  Map<String, dynamic> _nodeInfo = {};
  
  EnhancedRoutingClientImpl(this._serverUrl);
  
  @override
  String get serverUrl => _serverUrl;
  
  @override
  bool get isConnected => _isConnected;
  
  @override
  DateTime? get lastSuccessfulConnection => _lastSuccessfulConnection;
  
  /// Get current node ID
  String? get nodeId => _nodeId;
  
  /// Set node capabilities (model info, performance specs, etc.)
  void setNodeCapabilities(Map<String, dynamic> capabilities) {
    _nodeCapabilities = Map<String, dynamic>.from(capabilities);
  }
  
  /// Set node info (platform, version, etc.)
  void setNodeInfo(Map<String, dynamic> info) {
    _nodeInfo = Map<String, dynamic>.from(info);
  }

  @override
  void setServerUrl(String url) {
    _serverUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    Logger.info("Server URL updated: $_serverUrl", "RoutingClient");
  }

  /// Register this node with the server
  Future<bool> registerNode() async {
    try {
      // Prepare node information
      final nodeInfo = {
        ..._nodeInfo,
        'platform': kIsWeb ? 'web' : Platform.operatingSystem,
        'client_version': '2.0.0',
        'registration_time': DateTime.now().toIso8601String(),
      };
      
      final capabilities = {
        ..._nodeCapabilities,
        'supports_multimodal': true,
        'supports_function_calls': true,
        'max_concurrent_queries': 3,
      };

      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      
      // Include existing node ID if available
      if (_nodeId != null) {
        headers['x-node-id'] = _nodeId!;
      }

      final response = await http.post(
        Uri.parse('$_serverUrl/register'),
        headers: headers,
        body: jsonEncode({
          'node_capabilities': capabilities,
          'node_info': nodeInfo,
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _nodeId = data['node_id'] as String;
        _isConnected = true;
        _lastSuccessfulConnection = DateTime.now();
        
        Logger.success("Node registered successfully: $_nodeId", "RoutingClient");
        return true;
      }
      
      Logger.error("Node registration failed: ${response.statusCode}", "RoutingClient");
      _isConnected = false;
      return false;
    } catch (e) {
      Logger.error("Node registration error", "RoutingClient", e);
      _isConnected = false;
      return false;
    }
  }

  @override
  Future<int?> submitQuery(String query) async {
    try {
      // Ensure node is registered
      if (_nodeId == null) {
        final registered = await registerNode();
        if (!registered) {
          Logger.error("Cannot submit query: Node registration failed", "RoutingClient");
          return null;
        }
      }

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'x-node-id': _nodeId!,
      };

      final response = await http.post(
        Uri.parse('$_serverUrl/query'),
        headers: headers,
        body: jsonEncode({'query': query}),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _isConnected = true;
        _lastSuccessfulConnection = DateTime.now();
        
        final queryNumber = data['query_number'] as int;
        final estimatedWait = data['estimated_wait_time'] as int?;
        
        Logger.success("Query submitted: $queryNumber (estimated wait: ${estimatedWait ?? 'unknown'}s)", "RoutingClient");
        return queryNumber;
      }
      
      Logger.error("Submit query failed: ${response.statusCode} - ${response.body}", "RoutingClient");
      _isConnected = false;
      return null;
    } catch (e) {
      Logger.error("Submit query error", "RoutingClient", e);
      _isConnected = false;
      return null;
    }
  }

  @override
  Future<List<DistributedQuery>> getNewQueries() async {
    try {
      // Ensure node is registered
      if (_nodeId == null) {
        final registered = await registerNode();
        if (!registered) return [];
      }

      final headers = <String, String>{
        'x-node-id': _nodeId!,
      };

      final response = await http.get(
        Uri.parse('$_serverUrl/request'),
        headers: headers,
      ).timeout(_shortTimeout);

      if (response.statusCode == 200) {
        _isConnected = true;
        _lastSuccessfulConnection = DateTime.now();
        
        final List<dynamic> data = jsonDecode(response.body);
        final queries = data.map((item) {
          try {
            return DistributedQuery.fromJson(item as Map<String, dynamic>);
          } catch (e) {
            Logger.warning("Failed to parse query: $e", "RoutingClient");
            return null;
          }
        }).where((query) => query != null).cast<DistributedQuery>().toList();
        
        if (queries.isNotEmpty) {
          Logger.info("Received ${queries.length} new queries", "RoutingClient");
        }
        
        return queries;
      }
      
      if (response.statusCode != 200) {
        Logger.warning("Get queries failed: ${response.statusCode}", "RoutingClient");
      }
      
      _isConnected = false;
      return [];
    } catch (e) {
      if (e is TimeoutException) {
        Logger.debug("Get queries timeout (normal during low activity)", "RoutingClient");
      } else {
        Logger.error("Get queries error", "RoutingClient", e);
      }
      _isConnected = false;
      return [];
    }
  }

  @override
  Future<bool> sendResponse(DistributedResponse response) async {
    try {
      if (_nodeId == null) {
        Logger.error("Cannot send response: Node not registered", "RoutingClient");
        return false;
      }

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'x-node-id': _nodeId!,
      };

      final httpResponse = await http.post(
        Uri.parse('$_serverUrl/response'),
        headers: headers,
        body: jsonEncode(response.toJson()),
      ).timeout(_timeout);

      if (httpResponse.statusCode == 200) {
        _isConnected = true;
        _lastSuccessfulConnection = DateTime.now();
        
        final data = jsonDecode(httpResponse.body);
        final totalResponses = data['total_responses'] as int?;
        
        Logger.success("Response sent for query ${response.queryNumber} (total responses: ${totalResponses ?? 'unknown'})", "RoutingClient");
        return true;
      }
      
      if (httpResponse.statusCode == 400) {
        final data = jsonDecode(httpResponse.body);
        Logger.warning("Response rejected: ${data['detail']}", "RoutingClient");
      } else {
        Logger.error("Send response failed: ${httpResponse.statusCode} - ${httpResponse.body}", "RoutingClient");
      }
      
      _isConnected = false;
      return false;
    } catch (e) {
      Logger.error("Send response error", "RoutingClient", e);
      _isConnected = false;
      return false;
    }
  }

  @override
  Future<List<String>> getResponses(int queryNumber) async {
    try {
      if (_nodeId == null) {
        Logger.error("Cannot get responses: Node not registered", "RoutingClient");
        return [];
      }

      final headers = <String, String>{
        'x-node-id': _nodeId!,
      };

      final response = await http.get(
        Uri.parse('$_serverUrl/response?query_number=$queryNumber'),
        headers: headers,
      ).timeout(_shortTimeout);

      if (response.statusCode == 200) {
        _isConnected = true;
        _lastSuccessfulConnection = DateTime.now();
        
        final dynamic data = jsonDecode(response.body);
        if (data is List) {
          final responses = data.map((item) => item.toString()).toList();
          Logger.info("Retrieved ${responses.length} responses for query $queryNumber", "RoutingClient");
          return responses;
        }
      } else if (response.statusCode == 403) {
        Logger.warning("Unauthorized access to query $queryNumber responses", "RoutingClient");
      } else if (response.statusCode == 404) {
        Logger.info("Query $queryNumber not found or expired", "RoutingClient");
      }
      
      _isConnected = false;
      return [];
    } catch (e) {
      Logger.error("Get responses error", "RoutingClient", e);
      _isConnected = false;
      return [];
    }
  }

  @override
  Future<bool> cleanupQuery(int queryNumber) async {
    try {
      if (_nodeId == null) {
        Logger.error("Cannot cleanup query: Node not registered", "RoutingClient");
        return false;
      }

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'x-node-id': _nodeId!,
      };

      final response = await http.post(
        Uri.parse('$_serverUrl/end'),
        headers: headers,
        body: jsonEncode({'query_number': queryNumber}),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        _isConnected = true;
        _lastSuccessfulConnection = DateTime.now();
        
        Logger.success("Query $queryNumber cleaned up successfully", "RoutingClient");
        return true;
      } else if (response.statusCode == 403) {
        Logger.warning("Unauthorized attempt to cleanup query $queryNumber", "RoutingClient");
      } else if (response.statusCode == 404) {
        Logger.info("Query $queryNumber already cleaned up or not found", "RoutingClient");
        return true; // Consider as success since query is not there
      }
      
      _isConnected = false;
      return false;
    } catch (e) {
      Logger.error("Cleanup error", "RoutingClient", e);
      _isConnected = false;
      return false;
    }
  }

  @override
  Future<bool> healthCheck() async {
    try {
      final headers = <String, String>{};
      if (_nodeId != null) {
        headers['x-node-id'] = _nodeId!;
      }

      final response = await http.get(
        Uri.parse('$_serverUrl/health'),
        headers: headers,
      ).timeout(_shortTimeout);

      final isHealthy = response.statusCode == 200;
      _isConnected = isHealthy;
      
      if (isHealthy) {
        _lastSuccessfulConnection = DateTime.now();
        
        // Try to register node if not registered
        if (_nodeId == null) {
          await registerNode();
        }
      }
      
      return isHealthy;
    } catch (e) {
      Logger.debug("Health check failed: $e", "RoutingClient");
      _isConnected = false;
      return false;
    }
  }

  /// Get detailed server status including node information
  Future<Map<String, dynamic>?> getServerStatus() async {
    try {
      final headers = <String, String>{};
      if (_nodeId != null) {
        headers['x-node-id'] = _nodeId!;
      }

      final response = await http.get(
        Uri.parse('$_serverUrl/status'),
        headers: headers,
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        _isConnected = true;
        _lastSuccessfulConnection = DateTime.now();
        
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        Logger.info("Server status retrieved: ${data['active_nodes']} nodes, ${data['active_queries']} queries", "RoutingClient");
        return data;
      }
      
      _isConnected = false;
      return null;
    } catch (e) {
      Logger.error("Get server status error", "RoutingClient", e);
      _isConnected = false;
      return null;
    }
  }

  /// Force re-registration of node
  Future<bool> forceReregister() async {
    _nodeId = null;
    return await registerNode();
  }

  @override
  Future<void> dispose() async {
    try {
      // Attempt to unregister node gracefully
      if (_nodeId != null && _isConnected) {
        Logger.info("Disposing routing client for node $_nodeId", "RoutingClient");
      }
    } catch (e) {
      Logger.warning("Error during disposal", "RoutingClient");
    } finally {
      _isConnected = false;
      _lastSuccessfulConnection = null;
      _nodeId = null;
    }
  }

  /// Get node statistics from server
  Future<Map<String, dynamic>?> getNodeStats() async {
    try {
      final serverStatus = await getServerStatus();
      if (serverStatus == null || _nodeId == null) return null;
      
      final nodesInfo = serverStatus['nodes_info'] as List?;
      if (nodesInfo == null) return null;
      
      for (final nodeInfo in nodesInfo) {
        if (nodeInfo['node_id'] == _nodeId) {
          return nodeInfo as Map<String, dynamic>;
        }
      }
      
      return null;
    } catch (e) {
      Logger.error("Get node stats error", "RoutingClient", e);
      return null;
    }
  }
}