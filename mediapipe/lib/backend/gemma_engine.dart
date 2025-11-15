import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
// import 'package:flutter_gemma/mobile/flutter_gemma_mobile.dart';
import 'package:path_provider/path_provider.dart';
import 'ai_engine.dart';
import '../shared/logger.dart';

class GemmaEngine implements AIEngine {
  final _gemma = FlutterGemmaPlugin.instance;
  InferenceModel? _model;
  InferenceChat? _chat;
  bool _isReady = false;
  bool _isGenerating = false;

  @override
  String get name => 'Gemma';
  
  @override
  bool get isReady => _isReady;
  
  @override
  bool get isGenerating => _isGenerating;

  @override
  Future<void> init(String modelPath, Map<String, dynamic> config) async {
    try {
      Log.i('Initializing Gemma...', 'GemmaEngine');
      
      // Apply Android path correction
      String correctedPath = modelPath;
      if (!kIsWeb && Platform.isAndroid) {
        if (modelPath.contains('/data/user/0/')) {
          correctedPath = modelPath.replaceFirst('/data/user/0/', '/data/data/');
        }
        // Also ensure we're using the full absolute path
        if (!correctedPath.startsWith('/')) {
          final directory = await getApplicationDocumentsDirectory();
          final baseDir = directory.path.contains('/data/user/0/')
              ? directory.path.replaceFirst('/data/user/0/', '/data/data/')
              : directory.path;
          correctedPath = '$baseDir/${_getFilename(modelPath)}';
        }
      }

      Log.i('Model path: $correctedPath', 'GemmaEngine');

      // Set model path for flutter_gemma
      // Note: setModelPath may trigger cleanup, but we use createModel with explicit path
      final manager = _gemma.modelManager;
      await manager.setModelPath(correctedPath);

      // Create model with updated parameters
      _model = await _gemma.createModel(
        modelType: config['modelType'] ?? ModelType.gemmaIt,
        preferredBackend: config['backend'] ?? PreferredBackend.gpu,
        maxTokens: config['maxTokens'] ?? 1024,
        supportImage: config['hasImage'] ?? false,
        maxNumImages: config['maxNumImages'] ?? 1,
      );

      // Create chat
      _chat = await _model!.createChat(
        temperature: config['temperature']?.toDouble() ?? 1.0,
        randomSeed: DateTime.now().millisecondsSinceEpoch,
        topK: config['topK'] ?? 64,
        topP: config['topP']?.toDouble() ?? 0.95,
        tokenBuffer: 256,
        supportImage: config['hasImage'] ?? false,
        supportsFunctionCalls: config['hasFunctionCalls'] ?? false,
        tools: [],
        isThinking: config['isThinking'] ?? false,
        modelType: config['modelType'] ?? ModelType.gemmaIt,
      );

      _isReady = true;
      Log.s('Gemma initialized successfully', 'GemmaEngine');
    } catch (e) {
      _isReady = false;
      Log.e('Gemma init failed', 'GemmaEngine', e);
      rethrow;
    }
  }

  @override
  Future<String> generate(String prompt) async {
    if (!_isReady || _chat == null) throw StateError('Not initialized');
    if (_isGenerating) throw StateError('Already generating');

    try {
      _isGenerating = true;
      await _chat!.addQueryChunk(Message.text(text: prompt, isUser: true));
      
      final buffer = StringBuffer();
      await for (final response in _chat!.generateChatResponseAsync()) {
        if (!_isGenerating) break;
        if (response is TextResponse) {
          buffer.write(response.token);
        }
      }

      return buffer.toString().trim();
    } finally {
      _isGenerating = false;
    }
  }

  @override
  Stream<String> generateStream(String prompt) async* {
    if (!_isReady || _chat == null) throw StateError('Not initialized');
    if (_isGenerating) throw StateError('Already generating');

    try {
      _isGenerating = true;
      await _chat!.addQueryChunk(Message.text(text: prompt, isUser: true));
      
      await for (final response in _chat!.generateChatResponseAsync()) {
        if (!_isGenerating) break;
        if (response is TextResponse) {
          yield response.token;
        }
      }
    } finally {
      _isGenerating = false;
    }
  }

  @override
  Future<void> stop() async {
    _isGenerating = false;
    if (_model != null) {
      try {
        await _model!.session?.stopGeneration();
        Log.i('Generation stopped successfully', 'GemmaEngine');
      } catch (e) {
        Log.e('Failed to stop generation', 'GemmaEngine', e);
      }
    }
  }

  @override
  Future<void> clearHistory() async {
    if (_model != null) {
      await _recreateChat();
    }
  }

  /// Completely disposes the model and recreates it from scratch
  Future<void> resetModel(String modelPath, Map<String, dynamic> config) async {
    Log.i('Resetting Gemma model completely', 'GemmaEngine');
    
    // First dispose everything
    await dispose();
    
    // Then reinitialize
    await init(modelPath, config);
    
    Log.s('Gemma model reset successfully', 'GemmaEngine');
  }

  Future<void> _recreateChat() async {
    _chat = await _model!.createChat(
      temperature: 1.0,
      randomSeed: DateTime.now().millisecondsSinceEpoch,
      topK: 64,
      topP: 0.95,
      tokenBuffer: 256,
      supportImage: false,
      supportsFunctionCalls: false,
      tools: [],
      isThinking: false,
      modelType: ModelType.gemmaIt,
    );
  }

  @override
  Future<void> dispose() async {
    await stop();
    if (_model != null) {
      await _model!.close();
      _model = null;
    }
    _chat = null;
    _isReady = false;
  }

  @override
  Future<bool> healthCheck() async {
    return _isReady && _model != null && _chat != null;
  }

  String _getFilename(String url) => url.split('/').last;
}