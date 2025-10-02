// frontend/screens/download_screen.dart - صفحه دانلود (Part 1)
import 'dart:async';
import 'package:flutter/material.dart';
import '../../shared/models.dart';
import '../../download/model_store.dart';
import '../../download/download_manager.dart';
import '../../backend/ai_engine.dart';
import '../../backend/engine_factory.dart';
import '../../config.dart';
import '../../shared/logger.dart';
import 'chat_screen.dart';

class DownloadScreen extends StatefulWidget {
  final AIModel model;

  const DownloadScreen({super.key, required this.model});

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  final _store = ModelStore();
  final _tokenController = TextEditingController();
  
  DownloadManager? _downloadManager;
  StreamSubscription<DownloadProgress>? _progressSub;
  AIEngine? _engine;
  
  bool _needsDownload = true;
  bool _isEngineReady = false;
  String _token = '';
  double _progress = 0.0;
  String _status = '';
  DownloadStatus _downloadStatus = DownloadStatus.idle;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    _downloadManager?.dispose();
    _tokenController.dispose();
    _engine?.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _token = await _store.loadToken(widget.model.name) ?? '';
    _tokenController.text = _token;
    _needsDownload = !(await _store.isModelDownloaded(widget.model, _token));
    
    if (!_needsDownload) {
      await _initEngine();
    }
    
    setState(() {
      _status = _needsDownload ? 'آماده برای دانلود' : 'مدل موجود است';
    });
  }

  Future<void> _initEngine() async {
    try {
      _engine = EngineFactory.createDefault();
      if (_engine == null) return;

      final modelPath = await _store.createDownloadManager(widget.model, _token).getFilePath();
      final config = _buildConfig();
      
      await _engine!.init(modelPath, config);
      
      final isReady = await _engine!.healthCheck();
      setState(() {
        _isEngineReady = isReady;
      });
    } catch (e) {
      Log.e('Engine init failed', 'DownloadScreen', e);
    }
  }

  Map<String, dynamic> _buildConfig() {
    return {
      'modelType': widget.model.modelType,
      'backend': widget.model.backend,
      'maxTokens': AppConfig.defaultMaxTokens,
      'hasImage': widget.model.hasImage,
      'hasFunctionCalls': widget.model.hasFunctionCalls,
      'isThinking': widget.model.isThinking,
      'temperature': AppConfig.defaultTemperature,
      'topK': AppConfig.defaultTopK,
      'topP': AppConfig.defaultTopP,
      'maxNumImages': 1,
    };
  }

  Future<void> _saveToken() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) return;
    
    await _store.saveToken(widget.model.name, token);
    await _init();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('توکن ذخیره شد')),
      );
    }
  }

  Future<void> _startDownload() async {
    if (widget.model.needsAuth && _token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً ابتدا توکن را وارد کنید')),
      );
      return;
    }

    _downloadManager = _store.createDownloadManager(widget.model, _token);
    
    _progressSub = _downloadManager!.progressStream.listen((progress) {
      setState(() {
        _progress = progress.percentage;
        _downloadStatus = progress.status;
        
        if (progress.speedBps > 0) {
          final speedMB = (progress.speedBps / 1024 / 1024);
          _status = 'در حال دانلود... ${progress.percentage.toStringAsFixed(1)}% - ${speedMB.toStringAsFixed(1)} MB/s';
        } else {
          _status = 'در حال دانلود... ${progress.percentage.toStringAsFixed(1)}%';
        }
      });

      if (progress.status == DownloadStatus.completed) {
        _needsDownload = false;
        _initEngine();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('دانلود کامل شد')),
        );
      }
    });

    try {
      await _downloadManager!.start();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا: $e')),
        );
      }
    }
  }

  Future<void> _pauseDownload() async {
    await _downloadManager?.pause();
  }

  Future<void> _resumeDownload() async {
    await _downloadManager?.start();
  }

  Future<void> _deleteModel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تایید حذف'),
        content: const Text('آیا مطمئن هستید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لغو'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _downloadManager?.delete();
      setState(() {
        _needsDownload = true;
        _progress = 0;
        _downloadStatus = DownloadStatus.idle;
      });
    }
  }

  void _navigateToChat() {
    if (_engine == null || !_isEngineReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('مدل آماده نیست')),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(engine: _engine!, model: widget.model),
      ),
    );
  }

  // UI methods in Part 2...
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConfig.bgDark,
      appBar: AppBar(
        title: Text(widget.model.name),
        backgroundColor: Colors.grey[900],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildModelInfo(),
            const SizedBox(height: 16),
            _buildStatusCard(),
            const SizedBox(height: 16),
            if (widget.model.needsAuth) ...[
              _buildTokenInput(),
              const SizedBox(height: 16),
            ],
            if (_progress > 0) ...[
              _buildProgress(),
              const SizedBox(height: 16),
            ],
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildModelInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConfig.cardDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'اطلاعات مدل',
            style: TextStyle(fontSize: 18, color: Colors.blue[400]),
          ),
          const SizedBox(height: 12),
          _buildInfoRow('نام:', widget.model.name),
          _buildInfoRow('حجم:', widget.model.sizeDisplay),
          _buildInfoRow('پردازنده:', widget.model.backend.name.toUpperCase()),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: Colors.white70)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getStatusColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getStatusColor()),
      ),
      child: Text(_status, style: TextStyle(color: _getStatusColor())),
    );
  }

  Widget _buildTokenInput() {
    return TextField(
      controller: _tokenController,
      obscureText: true,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'توکن HuggingFace',
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.grey[800],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        suffixIcon: IconButton(
          icon: const Icon(Icons.save, color: Colors.blue),
          onPressed: _saveToken,
        ),
      ),
    );
  }

  Widget _buildProgress() {
    return Column(
      children: [
        Text(
          'پیشرفت: ${_progress.toStringAsFixed(1)}%',
          style: const TextStyle(color: Colors.white),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: _progress / 100),
        const SizedBox(height: 8),
        if (_downloadStatus == DownloadStatus.downloading)
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _pauseDownload,
                  child: const Text('توقف'),
                ),
              ),
            ],
          ),
        if (_downloadStatus == DownloadStatus.paused)
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _resumeDownload,
                  child: const Text('ادامه'),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildActions() {
    if (_needsDownload && _downloadStatus == DownloadStatus.idle) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _startDownload,
          child: const Text('شروع دانلود'),
        ),
      );
    }

    if (!_needsDownload) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _navigateToChat,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('استفاده از مدل'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _deleteModel,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('حذف مدل'),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Color _getStatusColor() {
    switch (_downloadStatus) {
      case DownloadStatus.error:
        return Colors.red;
      case DownloadStatus.completed:
        return Colors.green;
      case DownloadStatus.downloading:
        return Colors.blue;
      case DownloadStatus.paused:
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }
}