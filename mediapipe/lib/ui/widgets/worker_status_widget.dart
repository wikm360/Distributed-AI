// ui/widgets/worker_status_widget.dart
import 'package:flutter/material.dart';
// ignore: unused_import
import '../../core/interfaces/distributed_worker.dart';

/// Widget برای نمایش وضعیت worker
class WorkerStatusWidget extends StatelessWidget {
  final bool isRunning;
  final bool isPaused;
  final int processedQueries;
  final DateTime? lastActivity;
  final VoidCallback? onToggle;
  final VoidCallback? onShowStats;

  const WorkerStatusWidget({
    super.key,
    required this.isRunning,
    required this.isPaused,
    required this.processedQueries,
    this.lastActivity,
    this.onToggle,
    this.onShowStats,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getStatusColor(),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getStatusIcon(),
                color: _getStatusColor(),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _getStatusText(),
                  style: TextStyle(
                    color: _getStatusColor(),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (onToggle != null)
                IconButton(
                  icon: Icon(
                    isRunning ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                  ),
                  onPressed: onToggle,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تعداد پردازش شده: $processedQueries',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    if (lastActivity != null)
                      Text(
                        'آخرین فعالیت: ${_formatTime(lastActivity!)}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                  ],
                ),
              ),
              if (onShowStats != null)
                TextButton(
                  onPressed: onShowStats,
                  child: const Text(
                    'جزئیات',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    if (isRunning && !isPaused) {
      return Colors.green;
    } else if (isPaused) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  IconData _getStatusIcon() {
    if (isRunning && !isPaused) {
      return Icons.play_circle_filled;
    } else if (isPaused) {
      return Icons.pause_circle_filled;
    } else {
      return Icons.stop_circle;
    }
  }

  String _getStatusText() {
    if (isRunning && !isPaused) {
      return 'Worker در حال اجرا';
    } else if (isPaused) {
      return 'Worker متوقف شده';
    } else {
      return 'Worker غیرفعال';
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 1) {
      return 'الان';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} دقیقه پیش';
    } else {
      return '${difference.inHours} ساعت پیش';
    }
  }
}