// network/routing_client.dart - ارتباط با سرور routing
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../shared/models.dart';
import '../shared/logger.dart';
import '../config.dart';

class RoutingClient {
  final String _serverUrl;
  String? _nodeId;
  bool _isConnected = false;
  
  RoutingClient(this._serverUrl);

  String? get nodeId => _nodeId;
  bool get isConnected => _isConnected;

  Future<bool> registerNode() async {
    try {
      final nodeInfo = {
        'platform': kIsWeb ? 'web' : Platform.operatingSystem,
        'client_version': '2.0.0',
        'registration_time': DateTime.now().toIso8601String(),
      };

      final headers = <String, String>{'Content-Type': 'application/json'};
      if (_nodeId != null) headers['x-node-id'] = _nodeId!;

      final response = await http.post(
        Uri.parse('$_serverUrl/register'),
        headers: headers,
        body: jsonEncode({
          'node_capabilities': {'supports_multimodal': true},
          'node_info': nodeInfo,
        }),
      ).timeout(AppConfig.networkTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _nodeId = data['node_id'] as String;
        _isConnected = true;
        Log.s('Node registered: $_nodeId', 'RoutingClient');
        return true;
      }
      
      _isConnected = false;
      return false;
    } catch (e) {
      Log.e('Node registration failed', 'RoutingClient', e);
      _isConnected = false;
      return false;
    }
  }

  Future<int?> submitQuery(String query) async {
    if (_nodeId == null && !await registerNode()) return null;

    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/query'),
        headers: {'Content-Type': 'application/json', 'x-node-id': _nodeId!},
        body: jsonEncode({'query': query}),
      ).timeout(AppConfig.networkTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['query_number'] as int;
      }
      return null;
    } catch (e) {
      Log.e('Submit query failed', 'RoutingClient', e);
      return null;
    }
  }

  Future<List<DistributedQuery>> getNewQueries() async {
    if (_nodeId == null) return [];

    try {
      final response = await http.get(
        Uri.parse('$_serverUrl/request'),
        headers: {'x-node-id': _nodeId!},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => DistributedQuery.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> sendResponse(DistributedResponse response) async {
    if (_nodeId == null) return false;

    try {
      final httpResponse = await http.post(
        Uri.parse('$_serverUrl/response'),
        headers: {'Content-Type': 'application/json', 'x-node-id': _nodeId!},
        body: jsonEncode(response.toJson()),
      ).timeout(AppConfig.networkTimeout);

      return httpResponse.statusCode == 200;
    } catch (e) {
      Log.e('Send response failed', 'RoutingClient', e);
      return false;
    }
  }

  Future<List<String>> getResponses(int queryNumber) async {
    if (_nodeId == null) return [];

    try {
      final response = await http.get(
        Uri.parse('$_serverUrl/response?query_number=$queryNumber'),
        headers: {'x-node-id': _nodeId!},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        if (data is List) {
          return data.map((item) => item.toString()).toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> cleanupQuery(int queryNumber) async {
    if (_nodeId == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/end'),
        headers: {'Content-Type': 'application/json', 'x-node-id': _nodeId!},
        body: jsonEncode({'query_number': queryNumber}),
      ).timeout(AppConfig.networkTimeout);

      return response.statusCode == 200 || response.statusCode == 404;
    } catch (e) {
      return false;
    }
  }

  Future<bool> healthCheck() async {
    try {
      final response = await http.get(
        Uri.parse('$_serverUrl/health'),
        headers: _nodeId != null ? {'x-node-id': _nodeId!} : {},
      ).timeout(const Duration(seconds: 5));

      final isHealthy = response.statusCode == 200;
      _isConnected = isHealthy;
      
      if (isHealthy && _nodeId == null) {
        await registerNode();
      }
      
      return isHealthy;
    } catch (e) {
      _isConnected = false;
      return false;
    }
  }

  void dispose() {
    _isConnected = false;
    _nodeId = null;
  }
}