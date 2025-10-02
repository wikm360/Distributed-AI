// backend/gemma_engine.dart - پیاده‌سازی Gemma
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma/pigeon.g.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_gemma/core/model.dart';
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
      
      // Set model path
      if (!await _gemma.modelManager.isModelInstalled) {
        final path = kIsWeb
            ? modelPath
            : '${(await getApplicationDocumentsDirectory()).path}/${_getFilename(modelPath)}';
        await _gemma.modelManager.setModelPath(path);
      }

      // Create model
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
      Log.s('Gemma initialized', 'GemmaEngine');
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
      await _recreateChat();
    }
  }

  @override
  Future<void> clearHistory() async {
    if (_model != null) {
      await _recreateChat();
    }
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