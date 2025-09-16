// backends/llama_cpp/llama_cpp_backend.dart
import 'dart:async';
// import 'dart:convert';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import '../../core/interfaces/base_ai_backend.dart';
import '../../utils/logger.dart';

/// Custom format for Qwen models
class QwenFormat extends PromptFormat {
  QwenFormat()
      : super(
          PromptFormatType.raw,
          inputSequence: '<|im_start|>user\n',
          outputSequence: '<|im_start|>assistant\n',
          systemSequence: '<|im_start|>system\n',
          stopSequence: '<|im_end|>',
        );
}

/// LlamaCpp Backend Implementation
class LlamaCppBackend implements BaseAIBackend {
  late LlamaParent _llamaParent;
  bool _isInitialized = false;
  bool _isGenerating = false;
  String? _currentModel;
  String? _libraryPath;
  
  final List<String> _conversationHistory = [];
  StreamController<String>? _currentStreamController;
  StreamSubscription? _tokenStreamSubscription;
  StreamSubscription? _completionSubscription;

  @override
  String get backendName => 'LlamaCpp';

  @override
  bool get isInitialized => _isInitialized;

  @override
  bool get isGenerating => _isGenerating;

  @override
  List<String> get supportedPlatforms => ['windows', 'macos', 'linux'];

  @override
  String? get currentModel => _currentModel;

  @override
  Future<void> initialize({
    required String modelPath,
    required Map<String, dynamic> config,
  }) async {
    try {
      Logger.info("Initializing LlamaCpp backend with model: $modelPath", "LlamaCppBackend");
      
      // Extract library path from config
      _libraryPath = config['libraryPath'] as String?;
      if (_libraryPath == null) {
        throw ArgumentError('libraryPath is required for LlamaCpp backend');
      }
      
      // Set library path
      Llama.libraryPath = _libraryPath!;

      // Configure context parameters
      final contextParams = ContextParams()
        ..nCtx = config['nCtx'] ?? 4096
        ..nBatch = config['nBatch'] ?? 512
        ..nThreads = config['nThreads'] ?? 8
        ..nPredict = config['nPredict'] ?? 128;

      // Configure sampler parameters
      final samplerParams = SamplerParams()
        ..temp = config['temperature']?.toDouble() ?? 0.6
        ..topP = config['topP']?.toDouble() ?? 0.9
        ..topK = config['topK'] ?? 50;

      // Determine prompt format based on model type
      PromptFormat format;
      final modelType = config['modelType'] as String? ?? 'qwen';
      
      switch (modelType.toLowerCase()) {
        case 'qwen':
          format = QwenFormat();
          break;
        case 'chatml':
          format = ChatMLFormat();
          break;
        default:
          format = QwenFormat(); // Default to Qwen
      }

      // Create load command
      final loadCommand = LlamaLoad(
        path: modelPath,
        modelParams: ModelParams(),
        contextParams: contextParams,
        samplingParams: samplerParams,
        format: format,
      );

      // Initialize LlamaParent
      _llamaParent = LlamaParent(loadCommand);
      await _llamaParent.init();

      // Wait for model to be ready
      int attempts = 0;
      const maxAttempts = 60; // 30 seconds timeout
      
      while (_llamaParent.status != LlamaStatus.ready && attempts < maxAttempts) {
        await Future.delayed(const Duration(milliseconds: 500));
        attempts++;
        Logger.info("Waiting for model to load... (${attempts}/${maxAttempts})", "LlamaCppBackend");
      }

      if (_llamaParent.status != LlamaStatus.ready) {
        throw Exception('Model failed to load within timeout period');
      }

      // Setup completion listener
      _llamaParent.completions.listen((event) {
        if (event.success) {
          Logger.info("Response generation completed successfully", "LlamaCppBackend");
        } else {
          Logger.error("Response generation failed", "LlamaCppBackend", event.promptId);
        }
      });

      _currentModel = modelPath;
      _isInitialized = true;
      
      Logger.success("LlamaCpp backend initialized successfully", "LlamaCppBackend");
      
    } catch (e) {
      Logger.error("Failed to initialize LlamaCpp backend", "LlamaCppBackend", e);
      _isInitialized = false;
      rethrow;
    }
  }

  @override
  Future<String> generateResponse(String prompt) async {
    if (!_isInitialized) {
      throw StateError('Backend not initialized');
    }

    if (_isGenerating) {
      throw StateError('Already generating response');
    }

    try {
      _isGenerating = true;
      Logger.info("Generating response for prompt: ${_truncateString(prompt, 50)}", "LlamaCppBackend");

      final completer = Completer<String>();
      final buffer = StringBuffer();

      // Listen to token stream
      final streamSub = _llamaParent.stream.listen(
        (token) {
          buffer.write(token);
        },
        onError: (e) {
          if (!completer.isCompleted) {
            completer.completeError(e);
          }
        },
      );

      // Listen to completion events
      final completionSub = _llamaParent.completions.listen(
        (event) {
          if (event.success && !completer.isCompleted) {
            completer.complete(buffer.toString().trim());
          } else if (!completer.isCompleted) {
            completer.completeError("Response generation failed");
          }
        },
        onError: (e) {
          if (!completer.isCompleted) {
            completer.completeError(e);
          }
        },
      );

      // Send prompt to model
      final formattedPrompt = _formatPrompt(prompt);
      await _llamaParent.sendPrompt(formattedPrompt);

      // Wait for response with timeout
      final result = await completer.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () => "Response timed out",
      );

      // Cleanup
      await streamSub.cancel();
      await completionSub.cancel();

      // Add to conversation history
      _conversationHistory.add("User: $prompt");
      _conversationHistory.add("Assistant: $result");

      Logger.success("Response generated successfully", "LlamaCppBackend");
      return result;

    } catch (e) {
      Logger.error("Error generating response", "LlamaCppBackend", e);
      return "Error: $e";
    } finally {
      _isGenerating = false;
    }
  }

  @override
  Stream<String> generateResponseStream(String prompt) {
    if (!_isInitialized) {
      throw StateError('Backend not initialized');
    }

    if (_isGenerating) {
      throw StateError('Already generating response');
    }

    Logger.info("Starting streaming response for prompt: ${_truncateString(prompt, 50)}", "LlamaCppBackend");

    _currentStreamController = StreamController<String>();
    _isGenerating = true;

    _generateStreamingResponse(prompt);
    
    return _currentStreamController!.stream;
  }

  Future<void> _generateStreamingResponse(String prompt) async {
    try {
      // Listen to token stream
      _tokenStreamSubscription = _llamaParent.stream.listen(
        (token) {
          if (_currentStreamController != null && !_currentStreamController!.isClosed) {
            _currentStreamController!.add(token);
          }
        },
        onError: (e) {
          Logger.error("Stream error", "LlamaCppBackend", e);
          if (_currentStreamController != null && !_currentStreamController!.isClosed) {
            _currentStreamController!.addError(e);
          }
        },
      );

      // Listen to completion events
      final buffer = StringBuffer();
      _completionSubscription = _llamaParent.completions.listen(
        (event) {
          if (event.success) {
            Logger.success("Streaming response completed", "LlamaCppBackend");
            
            // Add to conversation history
            _conversationHistory.add("User: $prompt");
            _conversationHistory.add("Assistant: ${buffer.toString().trim()}");
            
          } else {
            Logger.error("Streaming response failed", "LlamaCppBackend", event.promptId);
            if (_currentStreamController != null && !_currentStreamController!.isClosed) {
              _currentStreamController!.addError("Response generation failed");
            }
          }
          
          // Always close the stream
          if (_currentStreamController != null && !_currentStreamController!.isClosed) {
            _currentStreamController!.close();
          }
          _isGenerating = false;
        },
        onError: (e) {
          Logger.error("Completion error", "LlamaCppBackend", e);
          if (_currentStreamController != null && !_currentStreamController!.isClosed) {
            _currentStreamController!.addError(e);
          }
          _isGenerating = false;
        },
      );

      // Send prompt to model
      final formattedPrompt = _formatPrompt(prompt);
      await _llamaParent.sendPrompt(formattedPrompt);

    } catch (e) {
      Logger.error("Error starting streaming response", "LlamaCppBackend", e);
      if (_currentStreamController != null && !_currentStreamController!.isClosed) {
        _currentStreamController!.addError(e);
      }
      _isGenerating = false;
    }
  }

  @override
  Future<void> stopGeneration() async {
    if (!_isGenerating) return;

    try {
      Logger.info("Stopping generation", "LlamaCppBackend");
      
      // Cancel subscriptions
      await _tokenStreamSubscription?.cancel();
      await _completionSubscription?.cancel();
      
      // Close stream controller
      if (_currentStreamController != null && !_currentStreamController!.isClosed) {
        _currentStreamController!.close();
      }
      
      _isGenerating = false;
      Logger.success("Generation stopped", "LlamaCppBackend");
      
    } catch (e) {
      Logger.error("Error stopping generation", "LlamaCppBackend", e);
    }
  }

  @override
  Future<void> clearHistory() async {
    Logger.info("Clearing conversation history", "LlamaCppBackend");
    _conversationHistory.clear();
  }

  @override
  Future<void> addMessage(String message, bool isUser) async {
    final prefix = isUser ? "User: " : "Assistant: ";
    _conversationHistory.add("$prefix$message");
    Logger.info("Added message to history: ${prefix}${_truncateString(message, 30)}", "LlamaCppBackend");
  }

  @override
  Future<void> dispose() async {
    try {
      Logger.info("Disposing LlamaCpp backend", "LlamaCppBackend");
      
      await stopGeneration();
      
      if (_isInitialized) {
        _llamaParent.dispose();
      }
      
      _conversationHistory.clear();
      _isInitialized = false;
      _currentModel = null;
      
      Logger.success("LlamaCpp backend disposed", "LlamaCppBackend");
      
    } catch (e) {
      Logger.error("Error disposing LlamaCpp backend", "LlamaCppBackend", e);
    }
  }

  @override
  Future<bool> healthCheck() async {
    if (!_isInitialized) return false;
    
    try {
      // Simple test to verify the model is responsive
      return _llamaParent.status == LlamaStatus.ready && !_isGenerating;
    } catch (e) {
      Logger.error("Health check failed", "LlamaCppBackend", e);
      return false;
    }
  }

  /// Format prompt based on conversation history and model format
  String _formatPrompt(String userPrompt) {
    final buffer = StringBuffer();
    
    // Add system message
    buffer.writeln('<|im_start|>system');
    buffer.writeln('You are a helpful, concise AI assistant. Answer shortly and directly.');
    buffer.writeln('<|im_end|>');
    
    // Add conversation history (keep last 10 messages for context)
    final recentHistory = _conversationHistory.length > 10 
        ? _conversationHistory.sublist(_conversationHistory.length - 10)
        : _conversationHistory;
    
    for (final historyItem in recentHistory) {
      if (historyItem.startsWith('User: ')) {
        buffer.writeln('<|im_start|>user');
        buffer.writeln(historyItem.substring(6));
        buffer.writeln('<|im_end|>');
      } else if (historyItem.startsWith('Assistant: ')) {
        buffer.writeln('<|im_start|>assistant');
        buffer.writeln(historyItem.substring(11));
        buffer.writeln('<|im_end|>');
      }
    }
    
    // Add current user prompt
    buffer.writeln('<|im_start|>user');
    buffer.writeln(userPrompt);
    buffer.writeln('<|im_end|>');
    buffer.write('<|im_start|>assistant');
    
    return buffer.toString();
  }

  /// Truncate string for logging
  String _truncateString(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  /// Create backend with distributed capabilities (for background worker)
  static LlamaCppBackend createForDistributed({
    required String modelPath,
    required String libraryPath,
    Map<String, dynamic>? additionalConfig,
  }) {
    final backend = LlamaCppBackend();
    
    // Configure for distributed usage
    final config = {
      'libraryPath': libraryPath,
      'nCtx': 4096,
      'nBatch': 512,
      'nThreads': 8,
      'nPredict': 256, // Longer responses for distributed
      'temperature': 0.6,
      'topP': 0.9,
      'topK': 50,
      'modelType': 'qwen',
      ...?additionalConfig,
    };
    
    return backend;
  }

  /// Get backend statistics
  Map<String, dynamic> get statistics => {
    'backend_name': backendName,
    'is_initialized': _isInitialized,
    'is_generating': _isGenerating,
    'current_model': _currentModel,
    'conversation_length': _conversationHistory.length,
    'library_path': _libraryPath,
    'status': _isInitialized ? _llamaParent.status.toString() : 'not_initialized',
  };
}