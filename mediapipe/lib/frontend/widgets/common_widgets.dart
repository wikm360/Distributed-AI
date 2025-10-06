// frontend/widgets/common_widgets.dart - طراحی مدرن (بهینه‌شده برای عملکرد)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../shared/models.dart';

// ========== Modern Message Bubble ==========
class ModernMessageBubble extends StatefulWidget {
  final ChatMessage message;
  const ModernMessageBubble(this.message, {super.key});

  @override
  State<ModernMessageBubble> createState() => _ModernMessageBubbleState();
}

class _ModernMessageBubbleState extends State<ModernMessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<double>(
      begin: 20.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.isUser;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment:
                    isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!isUser) ...[
                    _buildAvatar(isUser),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: GestureDetector(
                      onLongPress: () {
                        HapticFeedback.lightImpact();
                        _copyToClipboard(context);
                      },
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          gradient: isUser
                              ? LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.blue.shade600,
                                    Colors.blue.shade700,
                                  ],
                                )
                              : null,
                          color: !isUser
                              ? Colors.white.withOpacity(0.05)
                              : null,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft:
                                isUser ? const Radius.circular(20) : const Radius.circular(4),
                            bottomRight:
                                isUser ? const Radius.circular(4) : const Radius.circular(20),
                          ),
                          border: !isUser
                              ? Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                  width: 1,
                                )
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: isUser
                                  ? Colors.blue.withOpacity(0.2)
                                  : Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isUser && widget.message.text.isEmpty)
                              const TypingAnimation()
                            else
                              SelectableText(
                                widget.message.text,
                                style: TextStyle(
                                  color: isUser
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.9),
                                  fontSize: 15,
                                  height: 1.5,
                                ),
                              ),
                            if (!isUser) ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildActionButton(
                                    Icons.copy_rounded,
                                    () => _copyToClipboard(context),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildActionButton(
                                    Icons.refresh_rounded,
                                    () {
                                      // Regenerate action
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (isUser) ...[
                    const SizedBox(width: 8),
                    _buildAvatar(isUser),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatar(bool isUser) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isUser
              ? [Colors.purple.shade600, Colors.pink.shade600]
              : [Colors.green.shade600, Colors.teal.shade600],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: isUser
                ? Colors.purple.withOpacity(0.3)
                : Colors.green.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          isUser ? Icons.person : Icons.smart_toy_rounded,
          color: Colors.white,
          size: 16,
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, VoidCallback onPressed) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 14,
            color: Colors.white.withOpacity(0.5),
          ),
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: widget.message.text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('کپی شد'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}

// ========== Original Message Bubble (for compatibility) ==========
class MessageBubble extends ModernMessageBubble {
  const MessageBubble(super.message, {super.key});
}

// ========== Typing Animation ==========
class TypingAnimation extends StatefulWidget {
  const TypingAnimation({super.key});

  @override
  State<TypingAnimation> createState() => _TypingAnimationState();
}

class _TypingAnimationState extends State<TypingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _animations = List.generate(3, (index) {
      return Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            index * 0.2,
            0.6 + index * 0.2,
            curve: Curves.easeInOut,
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _animations[index],
          builder: (context, child) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.scale(
                scale: 0.5 + (_animations[index].value * 0.5),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(
                      0.3 + (_animations[index].value * 0.4)
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

// ========== Modern Status Indicator ==========
class StatusIndicator extends StatefulWidget {
  final bool isActive;
  final String? tooltip;
  const StatusIndicator({
    super.key,
    required this.isActive,
    this.tooltip,
  });

  @override
  State<StatusIndicator> createState() => _StatusIndicatorState();
}

class _StatusIndicatorState extends State<StatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = Tween(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(StatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip ?? (widget.isActive ? 'فعال' : 'غیرفعال'),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: widget.isActive
                    ? [
                        Colors.green.withOpacity(_animation.value),
                        Colors.green.withOpacity(_animation.value * 0.5),
                      ]
                    : [
                        Colors.red.withOpacity(0.8),
                        Colors.red.withOpacity(0.4),
                      ],
              ),
              boxShadow: widget.isActive
                  ? [
                      BoxShadow(
                        color: Colors.green.withOpacity(_animation.value * 0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : [],
            ),
          );
        },
      ),
    );
  }
}

// ========== Modern Progress Bar ==========
class ProgressBar extends StatelessWidget {
  final double progress;
  final String label;
  final Color? color;
  const ProgressBar({
    super.key,
    required this.progress,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progressColor = color ?? Colors.blue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    progressColor.withOpacity(0.2),
                    progressColor.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${progress.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: progressColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(3),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: progress / 100),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return LinearProgressIndicator(
                  value: value,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ========== Modern Typing Indicator (بهینه‌شده بدون BackdropFilter) ==========
class TypingIndicator extends StatelessWidget {
  final VoidCallback? onStop;
  const TypingIndicator({super.key, this.onStop});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const TypingAnimation(),
          const SizedBox(width: 12),
          Text(
            'در حال تولید پاسخ...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          const Spacer(),
          if (onStop != null)
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                onStop!();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.red.withOpacity(0.2),
                      Colors.red.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.stop_rounded,
                      size: 14,
                      color: Colors.red.shade400,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'توقف',
                      style: TextStyle(
                        color: Colors.red.shade400,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ========== Modern Worker Log Viewer (بهینه‌شده بدون BackdropFilter) ==========
class WorkerLogViewer extends StatefulWidget {
  final Stream<WorkerLog>? logStream;
  const WorkerLogViewer({super.key, this.logStream});

  @override
  State<WorkerLogViewer> createState() => _WorkerLogViewerState();
}

class _WorkerLogViewerState extends State<WorkerLogViewer>
    with SingleTickerProviderStateMixin {
  final List<WorkerLog> _logs = [];
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<WorkerLog>? _logSubscription;
  late AnimationController _animController;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
    _setupLogStream();
  }

  @override
  void didUpdateWidget(WorkerLogViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.logStream != oldWidget.logStream) {
      _logSubscription?.cancel();
      _setupLogStream();
    }
  }

  void _setupLogStream() {
    _logSubscription = widget.logStream?.listen((log) {
      setState(() {
        _logs.add(log);
        if (_logs.length > 100) {
          _logs.removeAt(0);
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _logSubscription?.cancel();
    _scrollController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _slideAnimation,
      child: Container(
        height: 300,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0A0E27).withOpacity(0.95),
              const Color(0xFF151B3D).withOpacity(0.95),
            ],
          ),
          border: Border(
            top: BorderSide(
              color: Colors.green.withOpacity(0.2),
              width: 2,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.green.withOpacity(0.1),
                    Colors.teal.withOpacity(0.1),
                  ],
                ),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.green.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.terminal,
                      color: Colors.green,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Worker Logs',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.green.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_logs.length}',
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.clear_all_rounded,
                      size: 18,
                    ),
                    color: Colors.white.withOpacity(0.5),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() => _logs.clear());
                    },
                    tooltip: 'پاک کردن لاگ‌ها',
                  ),
                ],
              ),
            ),
            // Logs
            Expanded(
              child: _logs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.05),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.hourglass_empty_rounded,
                              color: Colors.green.withOpacity(0.3),
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'در انتظار لاگ‌های Worker...',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.3),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        final log = _logs[index];
                        return _LogItem(log: log);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogItem extends StatelessWidget {
  final WorkerLog log;
  const _LogItem({required this.log});

  Color get _levelColor {
    switch (log.level) {
      case WorkerLogLevel.info:
        return Colors.blue.shade400;
      case WorkerLogLevel.success:
        return Colors.green.shade400;
      case WorkerLogLevel.warning:
        return Colors.orange.shade400;
      case WorkerLogLevel.error:
        return Colors.red.shade400;
      case WorkerLogLevel.token:
        return Colors.purple.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _levelColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: _levelColor,
            width: 3,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _levelColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              log.timeString,
              style: TextStyle(
                color: _levelColor,
                fontSize: 10,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Icon
          Text(
            log.levelIcon,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(width: 8),
          // Message
          Expanded(
            child: Text(
              log.message,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}