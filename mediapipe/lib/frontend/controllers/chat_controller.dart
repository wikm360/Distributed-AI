// frontend/controllers/chat_controller.dart - کنترلر چت
import 'dart:async';
import '../../backend/ai_engine.dart';
import '../../network/distributed_manager.dart';
import '../../shared/models.dart';
import '../../shared/logger.dart';

class ChatController {
  final AIEngine _engine;
  DistributedManager? _distributedManager;
  
  final List<ChatMessage> _messages = [];
  bool _isGenerating = false;
  bool _isDistributed = false;
  
  final StreamController<ChatState> _stateController = 
      StreamController<ChatState>.broadcast();

  ChatController(this._engine);

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isGenerating => _isGenerating;
  bool get isDistributed => _isDistributed;
  Stream<ChatState> get stateStream => _stateController.stream;

  void setDistributedManager(DistributedManager? manager) {
    _distributedManager = manager;
    _isDistributed = manager != null && manager.isEnabled;
    _emitState();
  }

  Future<void> sendMessage(String text) async {
    if (_isGenerating) throw StateError('Already generating');
    
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    _messages.add(ChatMessage(text: trimmed, isUser: true));
    _messages.add(ChatMessage(text: '', isUser: false));
    _isGenerating = true;
    _emitState();

    try {
      if (_isDistributed && _distributedManager != null) {
        await _sendDistributed(trimmed);
      } else {
        await _sendLocal(trimmed);
      }
    } catch (e) {
      Log.e('Send message failed', 'ChatController', e);
      _messages.last = _messages.last.copyWith(text: 'خطا: $e');
      _emitState();
    } finally {
      _isGenerating = false;
      _emitState();
    }
  }

  Future<void> _sendLocal(String prompt) async {
    final buffer = StringBuffer();
    await for (final token in _engine.generateStream(prompt)) {
      buffer.write(token);
      _messages.last = _messages.last.copyWith(text: buffer.toString());
      _emitState();
    }
  }

  Future<void> _sendDistributed(String prompt) async {
    await _distributedManager!.processDistributed(prompt, (token) {
      final currentText = _messages.last.text + token;
      _messages.last = _messages.last.copyWith(text: currentText);
      _emitState();
    });
  }

  Future<void> stop() async {
    if (!_isGenerating) return;
    _isGenerating = false;
    await _engine.stop();
    _emitState();
  }

  Future<void> clear() async {
    if (_isGenerating) await stop();
    _messages.clear();
    await _engine.clearHistory();
    _emitState();
  }

  void _emitState() {
    if (!_stateController.isClosed) {
      _stateController.add(ChatState(
        messages: messages,
        isGenerating: _isGenerating,
        isDistributed: _isDistributed,
      ));
    }
  }

  void dispose() {
    stop();
    _stateController.close();
  }
}

class ChatState {
  final List<ChatMessage> messages;
  final bool isGenerating;
  final bool isDistributed;

  ChatState({
    required this.messages,
    this.isGenerating = false,
    this.isDistributed = false,
  });
}