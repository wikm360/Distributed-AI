// frontend/widgets/common_widgets.dart - ویجت‌های مشترک
import 'package:flutter/material.dart';
import '../../shared/models.dart';
import 'dart:async';

// ========== Message Bubble ==========
class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const MessageBubble(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final color = isUser ? Colors.blue[600]! : Colors.grey[800]!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7,
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(4),
                bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
              ),
            ),
            child: SelectableText(
              message.text.isEmpty && !isUser ? '...' : message.text,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
        ),
      ),
    );
  }
}

// ========== Status Indicator ==========
class StatusIndicator extends StatelessWidget {
  final bool isActive;
  final String? tooltip;

  const StatusIndicator({
    super.key,
    required this.isActive,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? (isActive ? 'فعال' : 'غیرفعال'),
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? Colors.green : Colors.red,
        ),
      ),
    );
  }
}

// ========== Progress Bar ==========
class ProgressBar extends StatelessWidget {
  final double progress;
  final String label;

  const ProgressBar({
    super.key,
    required this.progress,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ${progress.toStringAsFixed(1)}%',
          style: const TextStyle(color: Colors.white),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress / 100.0,
          backgroundColor: Colors.grey[700],
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
        ),
      ],
    );
  }
}

// ========== Typing Indicator ==========
class TypingIndicator extends StatelessWidget {
  final VoidCallback? onStop;

  const TypingIndicator({super.key, this.onStop});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.blueGrey[900],
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'در حال تولید پاسخ...',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          if (onStop != null)
            ElevatedButton.icon(
              onPressed: onStop,
              icon: const Icon(Icons.stop, size: 16),
              label: const Text('توقف'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
        ],
      ),
    );
  }
}

// ========== Worker Log Viewer ==========
class WorkerLogViewer extends StatefulWidget {
  final Stream<WorkerLog>? logStream;

  const WorkerLogViewer({super.key, this.logStream});

  @override
  State<WorkerLogViewer> createState() => _WorkerLogViewerState();
}

class _WorkerLogViewerState extends State<WorkerLogViewer> {
  final List<WorkerLog> _logs = [];
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<WorkerLog>? _logSubscription;

  @override
  void initState() {
    super.initState();
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
        // حداکثر 100 لاگ نگه دار
        if (_logs.length > 100) {
          _logs.removeAt(0);
        }
      });
      
      // Auto scroll to bottom
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.black87,
        border: Border(top: BorderSide(color: Colors.grey[700]!)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              border: Border(bottom: BorderSide(color: Colors.grey[700]!)),
            ),
            child: Row(
              children: [
                const Icon(Icons.terminal, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Worker Logs',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_logs.length} logs',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: Colors.white70,
                  onPressed: () {
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
                        Icon(Icons.info_outline, color: Colors.grey[600], size: 48),
                        const SizedBox(height: 8),
                        Text(
                          'در انتظار لاگ‌های Worker...',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      return _LogItem(log: log);
                    },
                  ),
          ),
        ],
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
        return Colors.blue;
      case WorkerLogLevel.success:
        return Colors.green;
      case WorkerLogLevel.warning:
        return Colors.orange;
      case WorkerLogLevel.error:
        return Colors.red;
      case WorkerLogLevel.token:
        return const Color.fromARGB(255, 174, 54, 244);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time
          Text(
            log.timeString,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 8),
          
          // Icon
          Text(
            log.levelIcon,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 8),
          
          // Message
          Expanded(
            child: Text(
              log.message,
              style: TextStyle(
                color: _levelColor,
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