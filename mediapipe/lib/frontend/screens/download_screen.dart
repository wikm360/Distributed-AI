// frontend/screens/download_screen.dart - نسخه بازنویسی شده با API جدید
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../shared/models.dart';
import '../../download/model_store.dart';
import '../../backend/ai_engine.dart';
import '../../backend/engine_factory.dart';
import '../../shared/logger.dart';
import 'chat_screen.dart';

class DownloadScreen extends StatefulWidget {
  final AIModel model;
  const DownloadScreen({super.key, required this.model});

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen>
    with TickerProviderStateMixin {
  final _store = ModelStore(); // Singleton instance
  final _tokenController = TextEditingController();
  StreamSubscription<DownloadProgress>? _progressSub;
  AIEngine? _engine;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late AnimationController _progressAnimController;
  late Animation<double> _progressAnimation;
  bool _needsDownload = true;
  bool _isEngineReady = false;
  bool _showTokenField = false;
  String _token = '';
  double _progress = 0.0;
  String _status = '';
  DownloadStatus _downloadStatus = DownloadStatus.idle;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _progressAnimController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _progressAnimation = CurvedAnimation(
      parent: _progressAnimController,
      curve: Curves.easeInOut,
    );
    _animController.forward();
    _init();
  }

  Future<void> _init() async {
    _token = await _store.loadToken(widget.model.name) ?? '';
    _tokenController.text = _token;
    _needsDownload = !(await _store.isModelDownloaded(widget.model, _token));
    
    if (!_needsDownload) {
      await _initEngine();
    }
    
    if (mounted) {
      setState(() {
        _status = _needsDownload ? 'آماده برای دانلود' : 'مدل آماده است';
        _showTokenField = widget.model.needsAuth && _token.isEmpty;
      });
    }
  }

  Future<void> _initEngine() async {
    try {
      _engine = EngineFactory.createDefault();
      if (_engine == null) return;
      
      final modelPath = await _store.getFilePath(widget.model.filename);
      final config = _buildConfig();
      
      Log.i('Initializing engine with path: $modelPath', 'DownloadScreen');
      await _engine!.init(modelPath, config);
      
      final isReady = await _engine!.healthCheck();
      if (mounted) {
        setState(() {
          _isEngineReady = isReady;
        });
      }
      
      Log.s('Engine ready: $isReady', 'DownloadScreen');
    } catch (e) {
      Log.e('Engine init failed', 'DownloadScreen', e);
      if (mounted) {
        _showSnackbar('خطا در بارگذاری مدل: $e', Colors.red);
      }
    }
  }

  Map<String, dynamic> _buildConfig() {
    return {
      'modelType': widget.model.modelType,
      'backend': widget.model.preferredBackend,
      'maxTokens': widget.model.maxTokens,
      'hasImage': widget.model.supportImage,
      'hasFunctionCalls': widget.model.supportsFunctionCalls,
      'isThinking': widget.model.isThinking,
      'temperature': widget.model.temperature,
      'topK': widget.model.topK,
      'topP': widget.model.topP,
      'maxNumImages': widget.model.maxNumImages ?? 1,
    };
  }

  Future<void> _saveToken() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) return;
    
    HapticFeedback.lightImpact();
    await _store.saveToken(widget.model.name, token);
    _token = token;
    await _init();
    
    if (mounted) {
      setState(() => _showTokenField = false);
    }
    _showSnackbar('توکن ذخیره شد', Colors.green);
  }

  Future<void> _startDownload() async {
    if (widget.model.needsAuth && _token.isEmpty) {
      if (mounted) {
        setState(() => _showTokenField = true);
      }
      _showSnackbar('لطفاً ابتدا توکن را وارد کنید', Colors.orange);
      return;
    }

    if (_isDownloading) {
      _showSnackbar('دانلود در حال انجام است', Colors.orange);
      return;
    }

    HapticFeedback.mediumImpact();
    
    setState(() {
      _isDownloading = true;
      _downloadStatus = DownloadStatus.downloading;
      _status = 'شروع دانلود...';
      _progress = 0.0;
    });

    // Cancel any existing subscription
    await _progressSub?.cancel();
    
    try {
      Log.i('Starting download for ${widget.model.name}', 'DownloadScreen');
      
      _progressSub = _store.downloadModel(widget.model, _token).listen(
        (progress) {
          if (!mounted) return;
          
          setState(() {
            _progress = progress.percentage;
            _downloadStatus = progress.status;
            
            if (progress.status == DownloadStatus.downloading) {
              _status = 'در حال دانلود... ${_progress.toStringAsFixed(1)}%';
            } else if (progress.status == DownloadStatus.error) {
              _status = 'خطا در دانلود';
              _isDownloading = false;
            }
          });
          
          if (progress.status == DownloadStatus.completed) {
            _onDownloadCompleted();
          } else if (progress.status == DownloadStatus.error) {
            _onDownloadError(progress.error ?? 'خطای نامشخص');
          }
        },
        onError: (error) {
          Log.e('Download stream error', 'DownloadScreen', error);
          _onDownloadError(error.toString());
        },
        onDone: () {
          Log.i('Download stream completed', 'DownloadScreen');
          if (_downloadStatus != DownloadStatus.completed) {
            _onDownloadCompleted();
          }
        },
        cancelOnError: false,
      );
    } catch (e) {
      Log.e('Failed to start download', 'DownloadScreen', e);
      _onDownloadError(e.toString());
    }
  }

  void _onDownloadCompleted() {
    if (!mounted) return;
    
    setState(() {
      _progress = 100.0;
      _downloadStatus = DownloadStatus.completed;
      _status = 'دانلود کامل شد';
      _isDownloading = false;
      _needsDownload = false;
    });
    
    _progressAnimController.forward();
    _showSnackbar('دانلود کامل شد', Colors.green);
    _initEngine();
  }

  void _onDownloadError(String error) {
    if (!mounted) return;
    
    setState(() {
      _downloadStatus = DownloadStatus.error;
      _status = 'خطا در دانلود';
      _isDownloading = false;
    });
    
    _showSnackbar('خطا: $error', Colors.red);
  }

  Future<void> _cancelDownload() async {
    HapticFeedback.lightImpact();
    
    await _progressSub?.cancel();
    _progressSub = null;
    
    if (mounted) {
      setState(() {
        _isDownloading = false;
        _downloadStatus = DownloadStatus.idle;
        _status = 'دانلود لغو شد';
        _progress = 0.0;
      });
    }
    
    _showSnackbar('دانلود لغو شد', Colors.orange);
  }

  Future<void> _deleteModel() async {
    HapticFeedback.mediumImpact();
    
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildDeleteDialog(),
    );
    
    if (confirmed == true) {
      try {
        await _store.deleteModel(widget.model);
        
        if (mounted) {
          setState(() {
            _needsDownload = true;
            _progress = 0;
            _downloadStatus = DownloadStatus.idle;
            _isEngineReady = false;
            _status = 'آماده برای دانلود';
          });
        }
        
        _showSnackbar('مدل حذف شد', Colors.red);
      } catch (e) {
        Log.e('Failed to delete model', 'DownloadScreen', e);
        _showSnackbar('خطا در حذف: $e', Colors.red);
      }
    }
  }

  void _navigateToChat() async {
    if (_engine == null || !_isEngineReady) {
      _showSnackbar('مدل آماده نیست', Colors.orange);
      return;
    }
    
    HapticFeedback.lightImpact();
    
    // Get model path and configuration
    final modelPath = await _store.getFilePath(widget.model.filename);
    final modelConfig = _buildConfig();
    
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ChatScreen(
              engine: _engine!, 
              model: widget.model,
              modelPath: modelPath,
              modelConfig: modelConfig,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.02),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
      ),
    );
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
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildModelCard(),
                        const SizedBox(height: 20),
                        if (_showTokenField) ...[
                          _buildTokenInput(),
                          const SizedBox(height: 20),
                        ],
                        _buildStatusCard(),
                        if (_progress > 0 && _downloadStatus != DownloadStatus.completed) ...[
                          const SizedBox(height: 20),
                          _buildProgressSection(),
                        ],
                        const SizedBox(height: 24),
                        _buildActions(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.05),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
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
            child: ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [
                  Colors.blue.shade400,
                  Colors.purple.shade400,
                ],
              ).createShader(bounds),
              child: Text(
                widget.model.displayName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.08),
              Colors.white.withOpacity(0.03),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue.shade600,
                        Colors.purple.shade600,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      widget.model.name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'اطلاعات مدل',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.model.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildInfoRow(
              Icons.storage_rounded,
              'حجم',
              widget.model.sizeDisplay,
              Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.memory_rounded,
              'پردازنده',
              widget.model.backend.name.toUpperCase(),
              Colors.purple,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.speed_rounded,
              'حداکثر توکن',
              widget.model.maxTokens.toString(),
              Colors.orange,
            ),
            if (widget.model.hasImage ||
                widget.model.hasFunctionCalls ||
                widget.model.isThinking) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (widget.model.hasFunctionCalls)
                    _buildFeatureChip('توابع', Icons.functions, Colors.purple),
                  if (widget.model.hasImage)
                    _buildFeatureChip('تصویر', Icons.image, Colors.orange),
                  if (widget.model.isThinking)
                    _buildFeatureChip('تفکر', Icons.psychology, Colors.indigo),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.2),
            color.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTokenInput() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.key_rounded,
                        color: Colors.orange.shade400,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'توکن HuggingFace مورد نیاز است',
                        style: TextStyle(
                          color: Colors.orange.shade400,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _tokenController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'توکن خود را وارد کنید',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Colors.orange.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.save_rounded),
                        color: Colors.orange,
                        onPressed: _saveToken,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusCard() {
    final statusColor = _getStatusColor();
    final statusIcon = _getStatusIcon();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor.withOpacity(0.1),
            statusColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'پیشرفت دانلود',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.shade600.withOpacity(0.2),
                      Colors.purple.shade600.withOpacity(0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_progress.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(4),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, child) {
                  return LinearProgressIndicator(
                    value: _progress / 100,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color.lerp(
                        Colors.blue.shade400,
                        Colors.purple.shade400,
                        _progressAnimation.value,
                      )!,
                    ),
                  );
                },
              ),
            ),
          ),
          if (_isDownloading) ...[
            const SizedBox(height: 16),
            _buildActionButton(
              'لغو دانلود',
              Icons.stop_rounded,
              Colors.red,
              _cancelDownload,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActions() {
    if (_needsDownload && !_isDownloading) {
      return _buildActionButton(
        'شروع دانلود',
        Icons.download_rounded,
        Colors.blue,
        _startDownload,
        isLarge: true,
      );
    }
    
    if (!_needsDownload && !_isDownloading) {
      return Column(
        children: [
          _buildActionButton(
            'استفاده از مدل',
            Icons.chat_bubble_outline_rounded,
            Colors.green,
            _navigateToChat,
            isLarge: true,
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            'حذف مدل',
            Icons.delete_outline_rounded,
            Colors.red,
            _deleteModel,
            isOutlined: true,
          ),
        ],
      );
    }
    
    return const SizedBox.shrink();
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed, {
    bool isLarge = false,
    bool isOutlined = false,
  }) {
    return AnimatedScale(
      scale: 1.0,
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(isLarge ? 20 : 16),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: 24,
              vertical: isLarge ? 18 : 14,
            ),
            decoration: BoxDecoration(
              gradient: isOutlined
                  ? null
                  : LinearGradient(
                      colors: [
                        color.withOpacity(0.8),
                        color.withOpacity(0.6),
                      ],
                    ),
              color: isOutlined ? Colors.transparent : null,
              borderRadius: BorderRadius.circular(isLarge ? 20 : 16),
              border: isOutlined
                  ? Border.all(
                      color: color.withOpacity(0.3),
                      width: 1.5,
                    )
                  : null,
              boxShadow: isOutlined
                  ? []
                  : [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isOutlined ? color : Colors.white,
                  size: isLarge ? 22 : 18,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: isOutlined ? color : Colors.white,
                    fontSize: isLarge ? 16 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteDialog() {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1A1F3A).withOpacity(0.95),
                const Color(0xFF0A0E27).withOpacity(0.95),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_rounded,
                  color: Colors.red,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'حذف مدل',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'آیا از حذف ${widget.model.displayName} مطمئن هستید؟',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'لغو',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'حذف',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
        return _needsDownload ? Colors.blue : Colors.green;
    }
  }

  IconData _getStatusIcon() {
    switch (_downloadStatus) {
      case DownloadStatus.error:
        return Icons.error_outline_rounded;
      case DownloadStatus.completed:
        return Icons.check_circle_outline_rounded;
      case DownloadStatus.downloading:
        return Icons.downloading_rounded;
      case DownloadStatus.paused:
        return Icons.pause_circle_outline_rounded;
      default:
        return _needsDownload
            ? Icons.download_for_offline_outlined
            : Icons.check_circle_outline_rounded;
    }
  }
}