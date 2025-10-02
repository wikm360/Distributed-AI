// frontend/screens/chat_screen.dart - صفحه چت
import 'dart:async';
import 'package:flutter/material.dart';
import '../../backend/ai_engine.dart';
import '../../network/distributed_manager.dart';
import '../../network/routing_client.dart';
import '../../frontend/controllers/chat_controller.dart';
import '../../frontend/widgets/common_widgets.dart';
import '../../shared/models.dart';
import '../../config.dart';

class ChatScreen extends StatefulWidget {
  final AIEngine engine;
  final AIModel model;

  const ChatScreen({
    super.key,
    required this.engine,
    required this.model,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatController _controller;
  late final TextEditingController _messageController;
  
  DistributedManager? _distributedManager;
  StreamSubscription<ChatState>? _stateSub;
  
  bool _isDistributed = false;
  ChatState _state = ChatState(messages: []);

  @override
  void initState() {
    super.initState();
    _controller = ChatController(widget.engine);
    _messageController = TextEditingController();
    
    _stateSub = _controller.stateStream.listen((state) {
      setState(() => _state = state);
    });
    
    _initDistributed();
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _messageController.dispose();
    _controller.dispose();
    _distributedManager?.dispose();
    super.dispose();
  }

  Future<void> _initDistributed() async {
    try {
      final client = RoutingClient(AppConfig.routingServerUrl);
      _distributedManager = DistributedManager(widget.engine, client);
      // Don't auto-enable, let user choose
    } catch (e) {
      // Ignore - just continue without distributed mode
    }
  }

  Future<void> _toggleDistributed() async {
    if (_distributedManager == null) return;

    try {
      if (_isDistributed) {
        await _distributedManager!.disable();
        _controller.setDistributedManager(null);
      } else {
        await _distributedManager!.enable();
        _controller.setDistributedManager(_distributedManager);
      }
      
      setState(() {
        _isDistributed = _distributedManager!.isEnabled;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isDistributed ? 'حالت توزیع‌شده فعال شد' : 'حالت محلی فعال شد'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا: $e')),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    _messageController.clear();
    
    try {
      await _controller.sendMessage(text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا: $e')),
        );
      }
    }
  }

  Future<void> _clearChat() async {
    await _controller.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('چت پاک شد')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConfig.bgDark,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.model.name, style: const TextStyle(fontSize: 16)),
            Row(
              children: [
                Text(
                  _isDistributed ? 'چت توزیع‌شده' : 'چت محلی',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(width: 8),
                StatusIndicator(
                  isActive: _isDistributed && (_distributedManager?.isWorkerRunning ?? false),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.grey[900],
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'clear':
                  _clearChat();
                  break;
                case 'toggle':
                  _toggleDistributed();
                  break;
                case 'restart':
                  Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: ListTile(
                  leading: Icon(Icons.refresh),
                  title: Text('پاک کردن چت'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'toggle',
                child: ListTile(
                  leading: Icon(_isDistributed ? Icons.computer : Icons.cloud),
                  title: Text(_isDistributed ? 'حالت محلی' : 'حالت توزیع‌شده'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'restart',
                child: ListTile(
                  leading: Icon(Icons.restart_alt),
                  title: Text('شروع مجدد'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _state.messages.length,
              itemBuilder: (context, index) {
                return MessageBubble(_state.messages[index]);
              },
            ),
          ),
          if (_state.isGenerating)
            TypingIndicator(onStop: _controller.stop),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: AppConfig.cardDark,
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                onSubmitted: _state.isGenerating ? null : (_) => _sendMessage(),
                enabled: !_state.isGenerating,
                style: const TextStyle(color: Colors.white),
                maxLines: 4,
                minLines: 1,
                decoration: const InputDecoration(
                  hintText: 'پیام خود را تایپ کنید...',
                  hintStyle: TextStyle(color: Colors.grey),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            onPressed: _state.isGenerating ? null : _sendMessage,
            backgroundColor: _state.isGenerating ? Colors.grey : Colors.blue,
            mini: true,
            child: const Icon(Icons.send, size: 22),
          ),
        ],
      ),
    );
  }
}