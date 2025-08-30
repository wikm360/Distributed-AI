// backends/llama_cpp/llama_cpp_backend.dart
import 'dart:async';
import '../../core/interfaces/base_ai_backend.dart';

/// پیاده‌سازی backend برای LlamaCpp (برای آینده)
class LlamaCppBackend implements BaseAIBackend {
  bool _isInitialized = false;
  bool _isGenerating = false;
  String? _currentModel;
  
  @override
  String get backendName => 'LlamaCpp';
  
  @override
  bool get isInitialized => _isInitialized;
  
  @override
  bool get isGenerating => _isGenerating;
  
  @override
  List<String> get supportedPlatforms => ['Windows', 'Linux', 'macOS'];
  
  @override
  String? get currentModel => _currentModel;

  @override
  Future<void> initialize({
    required String modelPath,
    required Map<String, dynamic> config,
  }) async {
    // TODO: Implement LlamaCpp initialization
    throw UnimplementedError('LlamaCpp backend not implemented yet');
  }

  @override
  Future<String> generateResponse(String prompt) async {
    // TODO: Implement LlamaCpp response generation
    throw UnimplementedError('LlamaCpp backend not implemented yet');
  }

  @override
  Stream<String> generateResponseStream(String prompt) async* {
    // TODO: Implement LlamaCpp streaming
    throw UnimplementedError('LlamaCpp backend not implemented yet');
  }

  @override
  Future<void> stopGeneration() async {
    // TODO: Implement stop generation
    throw UnimplementedError('LlamaCpp backend not implemented yet');
  }

  @override
  Future<void> clearHistory() async {
    // TODO: Implement clear history
    throw UnimplementedError('LlamaCpp backend not implemented yet');
  }

  @override
  Future<void> addMessage(String message, bool isUser) async {
    // TODO: Implement add message
    throw UnimplementedError('LlamaCpp backend not implemented yet');
  }

  @override
  Future<void> dispose() async {
    // TODO: Implement dispose
    throw UnimplementedError('LlamaCpp backend not implemented yet');
  }

  @override
  Future<bool> healthCheck() async {
    // TODO: Implement health check
    return false;
  }
}