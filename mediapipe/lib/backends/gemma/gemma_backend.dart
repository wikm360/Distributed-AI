// backends/gemma/gemma_backend.dart - تصحیح logging calls
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma/pigeon.g.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_gemma/core/model.dart';
import '../../core/interfaces/base_ai_backend.dart';
import '../../utils/logger.dart';

/// پیاده‌سازی backend برای Flutter Gemma
class GemmaBackend implements BaseAIBackend {
  final _gemma = FlutterGemmaPlugin.instance;
  InferenceModel? _inferenceModel;
  InferenceChat? _chat;
  bool _isInitialized = false;
  bool _isGenerating = false;
  String? _currentModel;
  StreamSubscription<ModelResponse>? _generationSubscription;
  
  @override
  String get backendName => 'Flutter Gemma';
  
  @override
  bool get isInitialized => _isInitialized;
  
  @override
  bool get isGenerating => _isGenerating;
  
  @override
  List<String> get supportedPlatforms => ['Android', 'iOS', 'Web'];
  
  @override
  String? get currentModel => _currentModel;

  /// Safe string truncation
  String _truncateString(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  @override
  Future<void> initialize({
    required String modelPath,
    required Map<String, dynamic> config,
  }) async {
    try {
      Logger.info("Initializing with model: $modelPath", "GemmaBackend");
      
      // Parse config
      final backendConfig = _parseConfig(config);
      
      // Set model path
      if (!await _gemma.modelManager.isModelInstalled) {
        final path = kIsWeb
            ? modelPath
            : '${(await getApplicationDocumentsDirectory()).path}/${_getFilenameFromUrl(modelPath)}';
        await _gemma.modelManager.setModelPath(path);
      }

      // Create inference model
      _inferenceModel = await _gemma.createModel(
        modelType: backendConfig['modelType'] ?? ModelType.gemmaIt,
        preferredBackend: backendConfig['preferredBackend'] ?? PreferredBackend.gpu,
        maxTokens: backendConfig['maxTokens'] ?? 1024,
        supportImage: backendConfig['supportImage'] ?? false,
        maxNumImages: backendConfig['maxNumImages'] ?? 1,
      );

      // Create chat session
      await _createChatSession(backendConfig);
      
      _currentModel = modelPath;
      _isInitialized = true;
      
      Logger.success("Initialized successfully", "GemmaBackend");
    } catch (e) {
      Logger.error("Initialization failed", "GemmaBackend", e);
      _isInitialized = false;
      rethrow;
    }
  }
  
  Future<void> _createChatSession(Map<String, dynamic> config) async {
    if (_inferenceModel == null) throw StateError('Model not initialized');
    
    // تبدیل tools به List<Tool> صحیح
    final toolsConfig = config['tools'];
    List<Tool> tools = [];
    
    if (toolsConfig is List) {
      tools = <Tool>[];
    }
    
    _chat = await _inferenceModel!.createChat(
      temperature: config['temperature']?.toDouble() ?? 1.0,
      randomSeed: config['randomSeed'] ?? DateTime.now().millisecondsSinceEpoch,
      topK: config['topK'] ?? 64,
      topP: config['topP']?.toDouble() ?? 0.95,
      tokenBuffer: config['tokenBuffer'] ?? 256,
      supportImage: config['supportImage'] ?? false,
      supportsFunctionCalls: config['supportsFunctionCalls'] ?? false,
      tools: tools,
      isThinking: config['isThinking'] ?? false,
      modelType: config['modelType'] ?? ModelType.gemmaIt,
    );
  }

  @override
  Future<String> generateResponse(String prompt) async {
    if (!_isInitialized || _chat == null) {
      throw StateError('Backend not initialized');
    }
    
    if (_isGenerating) {
      throw StateError('Already generating response');
    }

    try {
      _isGenerating = true;
      Logger.info("Generating response for: ${_truncateString(prompt, 50)}", "GemmaBackend");
      
      // Add message to chat
      await _chat!.addQueryChunk(Message.text(text: prompt, isUser: true));
      
      final StringBuffer buffer = StringBuffer();
      
      await for (final response in _chat!.generateChatResponseAsync()) {
        if (!_isGenerating) break; // Check for cancellation
        
        if (response is TextResponse) {
          buffer.write(response.token);
        }
      }

      final result = buffer.toString().trim();
      Logger.success("Generated response: ${_truncateString(result, 50)}", "GemmaBackend");
      
      return result.isEmpty ? "No response generated." : result;
    } catch (e) {
      Logger.error("Generation error", "GemmaBackend", e);
      rethrow;
    } finally {
      _isGenerating = false;
    }
  }

  @override
  Stream<String> generateResponseStream(String prompt) async* {
    if (!_isInitialized || _chat == null) {
      throw StateError('Backend not initialized');
    }
    
    if (_isGenerating) {
      throw StateError('Already generating response');
    }

    try {
      _isGenerating = true;
      Logger.info("Starting stream generation for: ${_truncateString(prompt, 50)}", "GemmaBackend");
      
      // Add message to chat
      await _chat!.addQueryChunk(Message.text(text: prompt, isUser: true));
      
      await for (final response in _chat!.generateChatResponseAsync()) {
        if (!_isGenerating) break; // Check for cancellation
        
        if (response is TextResponse) {
          yield response.token;
        }
      }
      
      Logger.success("Stream generation completed", "GemmaBackend");
    } catch (e) {
      Logger.error("Stream generation error", "GemmaBackend", e);
      rethrow;
    } finally {
      _isGenerating = false;
    }
  }

  @override
  Future<void> stopGeneration() async {
    if (_isGenerating) {
      Logger.info("Stopping generation...", "GemmaBackend");
      _isGenerating = false;
      
      await _generationSubscription?.cancel();
      _generationSubscription = null;
      
      // Recreate chat session to ensure clean state
      if (_inferenceModel != null) {
        try {
          final config = {
            'temperature': 1.0,
            'topK': 64,
            'topP': 0.95,
            'tokenBuffer': 256,
            'supportImage': false,
            'supportsFunctionCalls': false,
            'tools': <Tool>[],
            'isThinking': false,
            'modelType': ModelType.gemmaIt,
          };
          await _createChatSession(config);
        } catch (e) {
          Logger.warning("Error recreating chat session", "GemmaBackend");
        }
      }
      
      Logger.success("Generation stopped", "GemmaBackend");
    }
  }

  @override
  Future<void> clearHistory() async {
    if (!_isInitialized || _inferenceModel == null) return;
    
    try {
      Logger.info("Clearing chat history...", "GemmaBackend");
      
      // Recreate chat session with fresh state
      final config = {
        'temperature': 1.0,
        'randomSeed': DateTime.now().millisecondsSinceEpoch,
        'topK': 64,
        'topP': 0.95,
        'tokenBuffer': 256,
        'supportImage': false,
        'supportsFunctionCalls': false,
        'tools': <Tool>[],
        'isThinking': false,
        'modelType': ModelType.gemmaIt,
      };
      
      await _createChatSession(config);
      Logger.success("Chat history cleared", "GemmaBackend");
    } catch (e) {
      Logger.error("Error clearing history", "GemmaBackend", e);
      rethrow;
    }
  }

  @override
  Future<void> addMessage(String message, bool isUser) async {
    if (!_isInitialized || _chat == null) return;
    
    try {
      await _chat!.addQueryChunk(Message.text(text: message, isUser: isUser));
    } catch (e) {
      Logger.error("Error adding message", "GemmaBackend", e);
      // Don't rethrow as this is not critical
    }
  }

  @override
  Future<void> dispose() async {
    Logger.info("Disposing backend...", "GemmaBackend");
    
    try {
      await stopGeneration();
      
      if (_inferenceModel != null) {
        await _inferenceModel!.close();
        _inferenceModel = null;
      }
      
      _chat = null;
      _isInitialized = false;
      _currentModel = null;
      
      Logger.success("Backend disposed", "GemmaBackend");
    } catch (e) {
      Logger.error("Error disposing backend", "GemmaBackend", e);
    }
  }

@override
  Future<bool> healthCheck() async {
    try {
      if (!_isInitialized || _inferenceModel == null || _chat == null) {
        Logger.warning("Health check failed: components not initialized", "GemmaBackend");
        return false;
      }
      
      Logger.success("Health check passed: all components initialized", "GemmaBackend");
      return true;
      
    } catch (e) {
      Logger.error("Health check failed", "GemmaBackend", e);
      return false;
    }
  }
  
  /// Parse configuration map
  Map<String, dynamic> _parseConfig(Map<String, dynamic> config) {
    return {
      'modelType': _parseModelType(config['modelType']),
      'preferredBackend': _parsePreferredBackend(config['preferredBackend']),
      'maxTokens': config['maxTokens'] ?? 1024,
      'supportImage': config['supportImage'] ?? false,
      'maxNumImages': config['maxNumImages'] ?? 1,
      'temperature': config['temperature']?.toDouble() ?? 1.0,
      'randomSeed': config['randomSeed'] ?? DateTime.now().millisecondsSinceEpoch,
      'topK': config['topK'] ?? 64,
      'topP': config['topP']?.toDouble() ?? 0.95,
      'tokenBuffer': config['tokenBuffer'] ?? 256,
      'supportsFunctionCalls': config['supportsFunctionCalls'] ?? false,
      'tools': <Tool>[],
      'isThinking': config['isThinking'] ?? false,
    };
  }
  
  ModelType? _parseModelType(dynamic value) {
    if (value is ModelType) return value;
    if (value is String) {
      switch (value.toLowerCase()) {
        case 'gemmait':
        case 'gemma_it':
          return ModelType.gemmaIt;
        case 'deepseek':
          return ModelType.deepSeek;
        case 'general':
          return ModelType.general;
        default:
          return ModelType.gemmaIt;
      }
    }
    return ModelType.gemmaIt;
  }
  
  PreferredBackend? _parsePreferredBackend(dynamic value) {
    if (value is PreferredBackend) return value;
    if (value is String) {
      switch (value.toLowerCase()) {
        case 'cpu':
          return PreferredBackend.cpu;
        case 'gpu':
          return PreferredBackend.gpu;
        default:
          return PreferredBackend.gpu;
      }
    }
    return PreferredBackend.gpu;
  }
  
  String _getFilenameFromUrl(String url) {
    return url.split('/').last;
  }
}