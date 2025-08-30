// ui/controllers/chat_controller_impl.dart - تصحیح logging
import 'dart:async';
import '../../core/interfaces/base_ai_backend.dart';
import '../../core/interfaces/chat_controller.dart';
import '../../utils/logger.dart';

/// پیاده‌سازی controller برای مدیریت چت
class ChatControllerImpl implements ChatController {
  final List<ChatMessage> _messages = [];
  BaseAIBackend? _backend;
  bool _isGenerating = false;
  StreamSubscription<String>? _generationSubscription;
  
  final StreamController<ChatState> _stateController = StreamController<ChatState>.broadcast();
  
  @override
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  
  @override
  bool get isGenerating => _isGenerating;
  
  @override
  BaseAIBackend? get currentBackend => _backend;
  
  @override
  Stream<ChatState> get stateStream => _stateController.stream;

  /// Safe string truncation
  String _truncateString(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  @override
  Future<void> sendMessage(String message) async {
    if (_backend == null || !_backend!.isInitialized) {
      _emitState(error: 'Backend not initialized');
      throw StateError('Backend not initialized');
    }

    if (_isGenerating) {
      _emitState(error: 'Already generating response');
      throw StateError('Already generating response');
    }

    final trimmedMessage = message.trim();
    if (trimmedMessage.isEmpty) return;

    // Add user message
    final userMessage = ChatMessage(text: trimmedMessage, isUser: true);
    _messages.add(userMessage);
    
    // Add empty assistant message for streaming
    final assistantMessage = ChatMessage(text: '', isUser: false);
    _messages.add(assistantMessage);
    
    _isGenerating = true;
    _emitState();

    try {
      Logger.info("Sending message: ${_truncateString(trimmedMessage, 50)}", "ChatController");
      
      final StringBuffer responseBuffer = StringBuffer();
      
      await for (final token in _backend!.generateResponseStream(trimmedMessage)) {
        if (!_isGenerating) break; // Check for cancellation
        
        responseBuffer.write(token);
        
        // Update the last message with current response
        _messages.last = assistantMessage.copyWith(text: responseBuffer.toString());
        _emitState();
      }
      
      final finalResponse = responseBuffer.toString().trim();
      if (finalResponse.isEmpty) {
        _messages.last = assistantMessage.copyWith(text: "No response generated.");
      } else {
        _messages.last = assistantMessage.copyWith(text: finalResponse);
      }
      
      Logger.success("Response completed: ${_truncateString(finalResponse, 50)}", "ChatController");
      
    } catch (e) {
      Logger.error("Error generating response", "ChatController", e);
      _messages.last = assistantMessage.copyWith(text: "Error: $e");
      _emitState(error: e.toString());
    } finally {
      _isGenerating = false;
      _emitState();
    }
  }

  @override
  Future<void> stopGeneration() async {
    if (!_isGenerating) return;
    
    Logger.info("Stopping generation...", "ChatController");
    
    _isGenerating = false;
    
    await _generationSubscription?.cancel();
    _generationSubscription = null;
    
    if (_backend != null) {
      await _backend!.stopGeneration();
    }
    
    // Update last message to indicate it was stopped
    if (_messages.isNotEmpty && !_messages.last.isUser) {
      final currentText = _messages.last.text;
      _messages.last = _messages.last.copyWith(
        text: "$currentText\n\n[تولید متوقف شد]"
      );
    }
    
    _emitState();
    Logger.success("Generation stopped", "ChatController");
  }

  @override
  Future<void> clearHistory() async {
    Logger.info("Clearing chat history...", "ChatController");
    
    // Stop any ongoing generation
    if (_isGenerating) {
      await stopGeneration();
    }
    
    // Clear messages
    _messages.clear();
    
    // Clear backend history
    if (_backend != null) {
      await _backend!.clearHistory();
    }
    
    _emitState();
    Logger.success("Chat history cleared", "ChatController");
  }

  @override
  Future<void> setBackend(BaseAIBackend backend) async {
    Logger.info("Setting backend: ${backend.backendName}", "ChatController");
    
    // Stop current generation if any
    if (_isGenerating) {
      await stopGeneration();
    }
    
    // Dispose old backend if different
    if (_backend != null && _backend != backend) {
      await _backend!.dispose();
    }
    
    _backend = backend;
    
    // Initialize if not already initialized
    if (!backend.isInitialized) {
      throw StateError('Backend must be initialized before setting');
    }
    
    _emitState();
    Logger.success("Backend set successfully", "ChatController");
  }

  @override
  Future<void> dispose() async {
    Logger.info("Disposing chat controller...", "ChatController");
    
    await stopGeneration();
    await _stateController.close();
    
    if (_backend != null) {
      await _backend!.dispose();
      _backend = null;
    }
    
    _messages.clear();
    Logger.success("Chat controller disposed", "ChatController");
  }

  void _emitState({String? error}) {
    final state = ChatState(
      messages: messages,
      isGenerating: _isGenerating,
      error: error,
      backend: _backend,
    );
    
    _stateController.add(state);
  }
}