// frontend/screens/chat_screen.dart - Modern Chat UI matching Model List Screen
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final String modelPath;
  final Map<String, dynamic> modelConfig;
  const ChatScreen({
    super.key,
    required this.engine,
    required this.model,
    required this.modelPath,
    required this.modelConfig,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  late final ChatController _controller;
  late final TextEditingController _messageController;
  late final ScrollController _scrollController;
  DistributedManager? _distributedManager;
  StreamSubscription<ChatState>? _stateSub;
  bool _isDistributed = false;
  ChatState _state = ChatState(messages: []);

  @override
  void initState() {
    super.initState();
    _controller = ChatController(widget.engine);
    _controller.setModelConfig(widget.modelPath, widget.modelConfig);
    _messageController = TextEditingController();
    _scrollController = ScrollController();
    // Removed fade animation for better performance
    _stateSub = _controller.stateStream.listen((state) {
      if (mounted) {
        setState(() => _state = state);
        _scrollToBottom();
      }
    });
    _initDistributed();
    _messageController.addListener(_onMessageChanged);
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _messageController.removeListener(_onMessageChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _controller.dispose();
    _distributedManager?.dispose();
    widget.engine.dispose();
    super.dispose();
  }

  void _onMessageChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initDistributed() async {
    try {
      final client = RoutingClient(AppConfig.routingServerUrl);
      _distributedManager = DistributedManager(widget.engine, client);
    } catch (e) {
      // Ignore - just continue without distributed mode
    }
  }

  Future<void> _toggleDistributed() async {
    if (_distributedManager == null) return;
    HapticFeedback.mediumImpact();
    try {
      if (_isDistributed) {
        await _distributedManager!.disable();
        _controller.setDistributedManager(null);
      } else {
        await _distributedManager!.enable();
        _controller.setDistributedManager(_distributedManager);
      }
      if (mounted) {
        setState(() {
          _isDistributed = _distributedManager!.isEnabled;
        });
      }
      _showSnackbar(
        _isDistributed ? 'حالت توزیع‌شده فعال شد' : 'حالت محلی فعال شد',
        _isDistributed ? Colors.green : Colors.blue,
      );
    } catch (e) {
      _showSnackbar('خطا: $e', Colors.red);
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    _messageController.clear();
    try {
      await _controller.sendMessage(text);
    } catch (e) {
      _showSnackbar('خطا: $e', Colors.red);
    }
  }

  void _stopGeneration() {
    HapticFeedback.mediumImpact();
    _controller.stop();
  }

  Future<void> _clearChat() async {
    HapticFeedback.mediumImpact();
    await _controller.clearAndReset();
    _showSnackbar('چت پاک شد و مدل بازنشانی شد', Colors.blue);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _showSnackbar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1D2E),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: _buildChatArea(),
            ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // Back button
            GestureDetector(
              onTap: () async {
                await widget.engine.dispose();
                if (mounted) Navigator.pop(context);
              },
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2D3E),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          const SizedBox(width: 16),
          // Model info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.model.displayName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isDistributed ? Colors.green : Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isDistributed ? 'حالت توزیع‌شده' : 'حالت محلی',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Mode toggle button
          GestureDetector(
            onTap: _toggleDistributed,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _isDistributed
                    ? Colors.green.shade600
                    : Colors.blue.shade600,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                _isDistributed ? Icons.cloud : Icons.computer,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Clear button
          GestureDetector(
            onTap: _clearChat,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2D3E),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.refresh_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildChatArea() {
    if (_state.messages.isEmpty) {
      return _buildEmptyState();
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: _state.messages.length,
      cacheExtent: 500, // Optimize scrolling performance
      itemBuilder: (context, index) {
        return RepaintBoundary(
          child: ModernMessageBubble(_state.messages[index]),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2D3E),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 64,
              color: Colors.blue.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'شروع گفتگو با ${widget.model.displayName}',
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'پیام خود را تایپ کنید',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    final text = _messageController.text.trim();
    final hasText = text.isNotEmpty;
    final isGenerating = _state.isGenerating;

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2D3E),
          border: Border(
            top: BorderSide(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
        ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1D2E),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: hasText && !isGenerating
                      ? Colors.blue.withOpacity(0.5)
                      : Colors.white.withOpacity(0.1),
                  width: 1.5,
                ),
              ),
              child: TextField(
                controller: _messageController,
                enabled: !isGenerating,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                ),
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (value) {
                  if (!isGenerating && hasText) {
                    _sendMessage();
                  }
                },
                decoration: InputDecoration(
                  hintText: isGenerating
                      ? 'در حال تولید پاسخ...'
                      : 'پیام خود را تایپ کنید...',
                  hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 14,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (isGenerating)
            _buildStopButton()
          else
            _buildSendButton(hasText: hasText),
        ],
      ),
    ),
    );
  }

  Widget _buildSendButton({required bool hasText}) {
    return AnimatedScale(
      scale: hasText ? 1.0 : 0.9,
      duration: const Duration(milliseconds: 200),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: hasText
              ? Colors.blue.shade600
              : Colors.grey.shade800,
          shape: BoxShape.circle,
          boxShadow: hasText
              ? [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(25),
            onTap: hasText ? _sendMessage : null,
            child: Icon(
              Icons.send_rounded,
              color: Colors.white.withOpacity(hasText ? 0.9 : 0.3),
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStopButton() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.red.shade600,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(25),
          onTap: _stopGeneration,
          child: const Icon(
            Icons.stop_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}
