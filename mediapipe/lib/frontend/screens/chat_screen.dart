// frontend/screens/chat_screen.dart - طراحی مدرن (بهینه‌شده برای عملکرد)
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
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  DistributedManager? _distributedManager;
  StreamSubscription<ChatState>? _stateSub;
  bool _isDistributed = false;
  ChatState _state = ChatState(messages: []);

  @override
  void initState() {
    super.initState();
    _controller = ChatController(widget.engine);
    // Set model configuration for reset functionality
    _controller.setModelConfig(widget.modelPath, widget.modelConfig);
    _messageController = TextEditingController();
    _scrollController = ScrollController();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _animController.forward();
    _stateSub = _controller.stateStream.listen((state) {
      if (mounted) {
        setState(() => _state = state);
        _scrollToBottom();
      }
    });
    _initDistributed();
    // اضافه کردن Listener برای به‌روزرسانی UI هنگام تایپ
    _messageController.addListener(_onMessageChanged);
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _messageController.removeListener(_onMessageChanged); // حذف Listener صحیح
    _messageController.dispose();
    _scrollController.dispose();
    _animController.dispose();
    _controller.dispose();
    _distributedManager?.dispose();
    // Dispose the engine when leaving the chat screen
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
      backgroundColor: const Color(0xFF0A0E27),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0A0E27),
              const Color(0xFF151B3D).withOpacity(0.6),
              const Color(0xFF0A0E27),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildChatArea(),
                ),
              ),
              _buildInputArea(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Container(
        // ✅ حذف BackdropFilter — ریشه اصلی لگ
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.08),
              Colors.white.withOpacity(0.02),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () async {
                // Dispose engine before going back
                await widget.engine.dispose();
                if (mounted) Navigator.pop(context);
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [
                            Colors.blue.shade400,
                            Colors.purple.shade400,
                          ],
                        ).createShader(bounds),
                        child: Text(
                          widget.model.displayName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _isDistributed
                                ? [Colors.green.shade600, Colors.teal.shade600]
                                : [Colors.blue.shade600, Colors.indigo.shade600],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _isDistributed ? 'توزیع‌شده' : 'محلی',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (_isDistributed &&
                          (_distributedManager?.isWorkerRunning ?? false))
                        PulseAnimation(
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      if (_isDistributed &&
                          (_distributedManager?.isWorkerRunning ?? false))
                        const SizedBox(width: 6),
                      Text(
                        _isDistributed ? 'Worker فعال' : 'پردازش محلی',
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
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert_rounded,
                color: Colors.white.withOpacity(0.8),
              ),
              color: const Color(0xFF1A1F3A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 8,
              onSelected: (value) {
                switch (value) {
                  case 'clear':
                    _clearChat();
                    break;
                  case 'toggle':
                    _toggleDistributed();
                    break;
                }
              },
              itemBuilder: (context) => [
                _buildMenuItem(
                  'clear',
                  Icons.refresh_rounded,
                  'پاک کردن چت',
                  Colors.blue,
                ),
                _buildMenuItem(
                  'toggle',
                  _isDistributed ? Icons.computer : Icons.cloud,
                  _isDistributed ? 'حالت محلی' : 'حالت توزیع‌شده',
                  Colors.purple,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem(
    String value,
    IconData icon,
    String title,
    Color color,
  ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildChatArea() {
    if (_state.messages.isEmpty) {
      return _buildEmptyState();
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      itemCount: _state.messages.length,
      itemBuilder: (context, index) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: ModernMessageBubble(_state.messages[index]),
              ),
            );
          },
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
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade600.withOpacity(0.1),
                  Colors.purple.shade600.withOpacity(0.1),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [
                  Colors.blue.shade400,
                  Colors.purple.shade400,
                ],
              ).createShader(bounds),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 48,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'شروع گفتگو با ${widget.model.displayName}',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'پیام خود را تایپ کنید',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.4),
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.4),
            Colors.black.withOpacity(0.6),
          ],
        ),
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
                gradient: LinearGradient(
                  colors: hasText && !isGenerating
                      ? [
                          Colors.blue.shade900.withOpacity(0.3),
                          Colors.purple.shade900.withOpacity(0.3),
                        ]
                      : [
                          Colors.white.withOpacity(0.05),
                          Colors.white.withOpacity(0.02),
                        ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: hasText && !isGenerating
                      ? Colors.blue.withOpacity(0.3)
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
    );
  }

  Widget _buildSendButton({required bool hasText}) {
    return AnimatedScale(
      scale: hasText ? 1.0 : 0.9,
      duration: const Duration(milliseconds: 200),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: hasText
                ? [Colors.blue.shade600, Colors.purple.shade600]
                : [Colors.grey.shade800, Colors.grey.shade900],
          ),
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
            borderRadius: BorderRadius.circular(24),
            onTap: hasText ? _sendMessage : null,
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Icon(
                Icons.send_rounded,
                color: Colors.white.withOpacity(hasText ? 0.9 : 0.3),
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStopButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red.shade600,
            Colors.orange.shade600,
          ],
        ),
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
          borderRadius: BorderRadius.circular(24),
          onTap: _stopGeneration,
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Icon(
              Icons.stop_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

// ========== PulseAnimation ==========
class PulseAnimation extends StatefulWidget {
  final Widget child;
  const PulseAnimation({super.key, required this.child});

  @override
  State<PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  // @override
  // void dispose() {
  //   _controller.dispose();
  //   super.dispose();
  // }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: widget.child,
        );
      },
    );
  }
}