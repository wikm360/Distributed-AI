// frontend/screens/worker_log_screen.dart - RAG Worker Log Screen
import 'package:flutter/material.dart';
import '../../main.dart';
import '../../shared/models.dart';

class WorkerLogScreen extends StatefulWidget {
  const WorkerLogScreen({super.key});

  @override
  State<WorkerLogScreen> createState() => _WorkerLogScreenState();
}

class _WorkerLogScreenState extends State<WorkerLogScreen> {
  final List<WorkerLog> _logs = [];
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();

    // Listen to worker logs
    ragWorker?.logStream.listen((log) {
      if (mounted) {
        setState(() {
          _logs.insert(0, log); // Add to beginning for reverse list
          if (_logs.length > 500) {
            _logs.removeLast(); // Keep only last 500 logs
          }
        });

        // Auto scroll to bottom if enabled
        if (_autoScroll && _scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final worker = ragWorker;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A1D2E),
            const Color(0xFF2A2D3E),
            Colors.blue.shade900.withOpacity(0.3),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (worker != null) _buildWorkerStatus(worker),
            Expanded(child: _buildLogList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade400.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.code,
              color: Colors.blue.shade300,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Worker',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                'RAG Query Logs',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white60,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Auto-scroll toggle
          IconButton(
            icon: Icon(
              _autoScroll ? Icons.arrow_downward : Icons.pause,
              color: _autoScroll ? Colors.blue.shade300 : Colors.white60,
            ),
            onPressed: () {
              setState(() {
                _autoScroll = !_autoScroll;
              });
            },
            tooltip: _autoScroll ? 'Disable auto-scroll' : 'Enable auto-scroll',
          ),
          // Clear logs
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white60),
            onPressed: _logs.isEmpty
                ? null
                : () {
                    setState(() {
                      _logs.clear();
                    });
                  },
            tooltip: 'Clear logs',
          ),
        ],
      ),
    );
  }

  Widget _buildWorkerStatus(dynamic worker) {
    final isRunning = worker.isRunning;
    final isPaused = worker.isPaused;
    final processedCount = worker.processedCount;
    final lastActivity = worker.lastActivity;

    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (isRunning && !isPaused) {
      statusText = 'Running';
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (isPaused) {
      statusText = 'Paused';
      statusColor = Colors.orange;
      statusIcon = Icons.pause_circle;
    } else {
      statusText = 'Stopped';
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 24),
              const SizedBox(width: 12),
              Text(
                'Status: $statusText',
                style: TextStyle(
                  color: statusColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade400.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$processedCount queries',
                  style: TextStyle(
                    color: Colors.blue.shade300,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (lastActivity != null) ...[
            const SizedBox(height: 12),
            Text(
              'Last activity: ${_formatTime(lastActivity)}',
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLogList() {
    if (_logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              size: 80,
              color: Colors.white.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'No logs yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              ragWorker == null
                  ? 'Worker not initialized'
                  : 'Waiting for worker activity...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.3),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListView.builder(
        controller: _scrollController,
        reverse: true, // Show newest first
        padding: const EdgeInsets.all(16),
        itemCount: _logs.length,
        itemBuilder: (context, index) {
          final log = _logs[index];
          return _buildLogItem(log);
        },
      ),
    );
  }

  Widget _buildLogItem(WorkerLog log) {
    Color levelColor;
    IconData levelIcon;

    switch (log.level) {
      case WorkerLogLevel.info:
        levelColor = Colors.blue.shade300;
        levelIcon = Icons.info_outline;
        break;
      case WorkerLogLevel.success:
        levelColor = Colors.green.shade300;
        levelIcon = Icons.check_circle_outline;
        break;
      case WorkerLogLevel.warning:
        levelColor = Colors.orange.shade300;
        levelIcon = Icons.warning_amber_outlined;
        break;
      case WorkerLogLevel.error:
        levelColor = Colors.red.shade300;
        levelIcon = Icons.error_outline;
        break;
      case WorkerLogLevel.token:
        levelColor = Colors.purple.shade300;
        levelIcon = Icons.token_outlined;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: levelColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: levelColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(levelIcon, color: levelColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.message,
                  style: TextStyle(
                    color: levelColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(log.timestamp),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 11,
                  ),
                ),
                if (log.data != null && log.data!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      log.data.toString(),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}
