// ui/screens/modernized_model_download_screen.dart - Updated version
import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemma/pigeon.g.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_gemma/core/model.dart';
import '../../core/interfaces/base_ai_backend.dart';
import '../../core/services/backend_factory.dart';
import '../../models/model.dart';
import '../../services/model_download_service.dart';
import '../../services/download_manager_service.dart';
import '../controllers/model_controller.dart';
import '../widgets/connection_status_indicator.dart';
import '../widgets/backend_selector.dart';
import 'modernized_chat_screen.dart';
import '../../utils/logger.dart';

class ModernizedModelDownloadScreen extends StatefulWidget {
  final Model model;
  final PreferredBackend? selectedBackend;
  final String? customBackendName;

  const ModernizedModelDownloadScreen({
    super.key,
    required this.model,
    this.selectedBackend,
    this.customBackendName,
  });

  @override
  State<ModernizedModelDownloadScreen> createState() => _ModernizedModelDownloadScreenState();
}

class _ModernizedModelDownloadScreenState extends State<ModernizedModelDownloadScreen> {
  // Controllers
  late final ModelController _modelController;
  late final EnhancedModelDownloadService _downloadService;
  final TextEditingController _tokenController = TextEditingController();

  // State
  bool _needToDownload = true;
  bool _isModelLoaded = false;
  
  double _progress = 0.0;
  String _token = '';
  String _status = '';
  String? _error;
  
  // Download state
  DownloadStatus _downloadStatus = DownloadStatus.idle;
  
  // Backend selection
  String? _selectedBackendName;
  BaseAIBackend? _previewBackend;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initialize();
  }

  void _initializeControllers() {
    _modelController = ModelController();
    
    _downloadService = EnhancedModelDownloadService(
      modelUrl: widget.model.url,
      modelFilename: widget.model.filename,
      licenseUrl: widget.model.licenseUrl,
    );

    _selectedBackendName = widget.customBackendName ?? 
        (BackendFactory.supportedBackends.isNotEmpty 
            ? BackendFactory.supportedBackends.first 
            : null);
  }

  @override
  void dispose() {
    _downloadService.dispose();
    _tokenController.dispose();
    
    // Only dispose backend if we created it
    if (_previewBackend != null) {
      _previewBackend!.dispose();
    }
    
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      await _downloadService.initialize();
      
      // Load saved token
      _token = await _downloadService.loadToken() ?? '';
      _tokenController.text = _token;
      
      // Check if model exists
      _needToDownload = !(await _downloadService.checkModelExistence(_token));
      
      // Initialize preview backend if model is available
      if (!_needToDownload) {
        await _initializePreviewBackend();
      }
      
      setState(() {
        _status = _needToDownload ? 'آماده برای دانلود' : 'مدل موجود است';
        _error = null;
        _downloadStatus = _needToDownload ? DownloadStatus.idle : DownloadStatus.completed;
      });
      
      Logger.info("Initialized download screen for ${widget.model.displayName}");
    } catch (e) {
      setState(() {
        _error = "خطا در مقداردهی اولیه: $e";
        _downloadStatus = DownloadStatus.error;
      });
      Logger.error("Failed to initialize download screen", "ModelDownloadScreen", e);
    }
  }

  Future<void> _initializePreviewBackend() async {
    if (_selectedBackendName == null) return;
    
    try {
      _previewBackend = BackendFactory.createBackend(_selectedBackendName!);
      if (_previewBackend == null) return;
      
      final isHealthy = await _previewBackend!.healthCheck();
      setState(() {
        _isModelLoaded = isHealthy;
      });
    } catch (e) {
      Logger.warning("Failed to initialize preview backend", "ModelDownloadScreen");
    }
  }

  Future<void> _saveToken(String token) async {
    try {
      await _downloadService.saveToken(token);
      await _initialize();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('توکن با موفقیت ذخیره شد!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در ذخیره توکن: $e')),
        );
      }
    }
  }

  Future<void> _startDownload() async {
    if (widget.model.needsAuth && _token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً ابتدا توکن خود را وارد کنید.')),
      );
      return;
    }

    setState(() {
      _error = null;
      _downloadStatus = DownloadStatus.preparing;
    });

    try {
      await _downloadService.downloadModel(
        token: widget.model.needsAuth ? _token : '',
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _progress = progress;
              // Update status based on progress
              if (progress > 0 && progress < 100) {
                _downloadStatus = DownloadStatus.downloading;
              }
            });
          }
        },
        onStatus: (status) {
          if (mounted) {
            setState(() {
              _status = status;
              // Update download status based on service status
              if (_downloadService.isDownloading && _downloadStatus != DownloadStatus.downloading) {
                _downloadStatus = DownloadStatus.downloading;
              }
            });
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _error = error;
              _downloadStatus = DownloadStatus.error;
            });
          }
        },
      );

      // Check final status after download method completes
      if (mounted) {
        final serviceStatus = _downloadService.downloadStatus;
        if (serviceStatus != null) {
          setState(() {
            _downloadStatus = serviceStatus;
            if (_downloadService.isCompleted) {
              _needToDownload = false;
              _progress = 100.0;
            }
          });
        }
        
        if (_downloadService.isCompleted) {
          await _initializePreviewBackend();
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('مدل با موفقیت دانلود شد!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _downloadStatus = DownloadStatus.error;
          _status = 'خطا در دانلود: ${e.toString()}';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در دانلود: ${e.toString()}'),
            action: SnackBarAction(
              label: 'تلاش مجدد',
              onPressed: _startDownload,
            ),
          ),
        );
      }
    }
  }

  Future<void> _pauseDownload() async {
    try {
      Logger.info("Pausing download... Current status: $_downloadStatus", "ModelDownloadScreen");
      await _downloadService.pauseDownload();
      
      setState(() {
        _downloadStatus = DownloadStatus.paused;
      });
      
      Logger.success("Download paused successfully", "ModelDownloadScreen");
    } catch (e) {
      Logger.error("Failed to pause download", "ModelDownloadScreen", e);
      if (mounted) {
        setState(() {
          _status = 'خطا در توقف: ${e.toString()}';
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _resumeDownload() async {
    Logger.info("Resuming download... Current status: $_downloadStatus", "ModelDownloadScreen");
    
    setState(() {
      _error = null;
      _downloadStatus = DownloadStatus.preparing;
    });

    try {
      await _downloadService.resumeDownload(
        token: widget.model.needsAuth ? _token : '',
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _progress = progress;
              // Make sure we update status to downloading when progress updates
              if (progress > 0 && progress < 100 && _downloadStatus != DownloadStatus.downloading) {
                Logger.info("Setting status to downloading from progress callback", "ModelDownloadScreen");
                _downloadStatus = DownloadStatus.downloading;
              }
            });
          }
        },
        onStatus: (status) {
          if (mounted) {
            setState(() {
              _status = status;
              // Update download status when service is actively downloading
              if (_downloadService.isDownloading && _downloadStatus != DownloadStatus.downloading) {
                Logger.info("Setting status to downloading from status callback", "ModelDownloadScreen");
                _downloadStatus = DownloadStatus.downloading;
              }
            });
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _error = error;
              _downloadStatus = DownloadStatus.error;
            });
          }
        },
      );

      // Check final status after resume completes
      if (mounted) {
        final serviceStatus = _downloadService.downloadStatus;
        Logger.info("Resume completed. Service status: $serviceStatus", "ModelDownloadScreen");
        
        if (serviceStatus != null) {
          setState(() {
            _downloadStatus = serviceStatus;
            if (_downloadService.isCompleted) {
              _needToDownload = false;
              _progress = 100.0;
            }
          });
        }
        
        if (_downloadService.isCompleted) {
          await _initializePreviewBackend();
        }
      }
    } catch (e) {
      Logger.error("Failed to resume download", "ModelDownloadScreen", e);
      if (mounted) {
        setState(() {
          _error = e.toString();
          _downloadStatus = DownloadStatus.error;
          _status = 'خطا در ادامه دانلود: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _stopDownload() async {
    try {
      setState(() {
        _status = 'در حال لغو دانلود...';
      });
      
      await _downloadService.stopDownload();
      
      if (mounted) {
        setState(() {
          _progress = 0.0;
          _status = 'دانلود لغو شد';
          _downloadStatus = DownloadStatus.cancelled;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'خطا در لغو: ${e.toString()}';
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _deleteModel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: const Text('تایید حذف', style: TextStyle(color: Colors.white)),
        content: const Text(
          'آیا مطمئن هستید که می‌خواهید این مدل را حذف کنید؟',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لغو', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _downloadService.deleteModel();
        setState(() {
          _needToDownload = true;
          _status = 'مدل حذف شد';
          _isModelLoaded = false;
          _progress = 0.0;
          _downloadStatus = DownloadStatus.idle;
        });
        
        await _previewBackend?.dispose();
        _previewBackend = null;
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('مدل حذف شد.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطا در حذف: ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> _navigateToChat() async {
    try {
      BaseAIBackend? preparedBackend;
      
      // CRITICAL: We need to transfer backend ownership properly
      if (_isModelLoaded && _previewBackend != null && _previewBackend!.isInitialized) {
        Logger.info("Transferring existing initialized backend", "ModelDownloadScreen");
        
        // Verify backend health before transfer
        final isHealthy = await _previewBackend!.healthCheck();
        if (!isHealthy) {
          throw Exception('Backend health check failed');
        }
        
        preparedBackend = _previewBackend;
        _previewBackend = null; // Transfer ownership - IMPORTANT!
        
      } else {
        Logger.info("Creating and loading new backend for chat", "ModelDownloadScreen");
        
        // Create fresh backend
        BackendFactory.initialize();
        preparedBackend = BackendFactory.createBackend(_selectedBackendName!);
        preparedBackend ??= BackendFactory.createDefaultBackend();
        
        if (preparedBackend == null) {
          throw Exception('Failed to create backend');
        }
        
        // Build proper config
        final config = _buildBackendConfig();
        
        // Initialize with model file path
        final modelPath = await _downloadService.getFilePath();
        await preparedBackend.initialize(
          modelPath: modelPath,
          config: config,
        );
        
        // Verify initialization
        if (!preparedBackend.isInitialized) {
          throw Exception('Backend failed to initialize');
        }
        
        // Health check
        final isHealthy = await preparedBackend.healthCheck();
        if (!isHealthy) {
          await preparedBackend.dispose();
          throw Exception('Backend health check failed after initialization');
        }
        
        Logger.success("New backend initialized successfully", "ModelDownloadScreen");
      }
      
      if (mounted && preparedBackend != null) {
        Logger.info("Navigating to chat with initialized backend", "ModelDownloadScreen");
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ModernizedChatScreen(
              model: widget.model,
              selectedBackend: widget.selectedBackend,
              preInitializedBackend: preparedBackend, // Pass the working backend
            ),
          ),
        );
      } else {
        throw Exception('No valid backend available for chat');
      }
      
    } catch (e) {
      Logger.error("Error navigating to chat", "ModelDownloadScreen", e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در بارگذاری مدل: $e'),
            action: SnackBarAction(
              label: 'تلاش مجدد',
              onPressed: _navigateToChat,
            ),
          ),
        );
      }
    }
  }

  /// Build backend configuration map
  Map<String, dynamic> _buildBackendConfig() {
    return {
      'modelType': _getModelTypeForModel(widget.model),
      'preferredBackend': widget.selectedBackend ?? widget.model.preferredBackend,
      'maxTokens': widget.model.maxTokens,
      'supportImage': widget.model.supportImage,
      'maxNumImages': widget.model.maxNumImages ?? 1,
      'temperature': widget.model.temperature,
      'randomSeed': DateTime.now().millisecondsSinceEpoch,
      'topK': widget.model.topK,
      'topP': widget.model.topP,
      'tokenBuffer': 256,
      'supportsFunctionCalls': widget.model.supportsFunctionCalls,
      'tools': [],
      'isThinking': widget.model.isThinking,
    };
  }

  /// Get model type for backend configuration
  ModelType _getModelTypeForModel(Model model) {
    if (model.displayName.toLowerCase().contains('deepseek')) {
      return ModelType.deepSeek;
    }
    return ModelType.gemmaIt;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('دانلود مدل'),
        backgroundColor: Colors.grey[900],
        actions: [
          ConnectionStatusIndicator(
            isConnected: !_needToDownload && _isModelLoaded,
            tooltip: _isModelLoaded ? 'مدل آماده' : 'مدل در دسترس نیست',
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildModelInfoCard(),
            const SizedBox(height: 16),
            if (_selectedBackendName != null) ...[
              _buildBackendSelector(),
              const SizedBox(height: 16),
            ],
            _buildStatusCard(),
            const SizedBox(height: 16),
            if (widget.model.needsAuth) ...[
              _buildTokenInput(),
              const SizedBox(height: 16),
            ],
            if (widget.model.licenseUrl.isNotEmpty) ...[
              _buildLicenseInfo(),
              const SizedBox(height: 16),
            ],
            _buildProgressSection(),
            const SizedBox(height: 24),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Text(
      'دانلود مدل ${widget.model.displayName}',
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildModelInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[400]),
              const SizedBox(width: 8),
              Text(
                'اطلاعات مدل',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[400],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('نام:', widget.model.displayName),
          _buildInfoRow('حجم:', widget.model.size),
          _buildInfoRow('پردازنده:', widget.selectedBackend?.name.toUpperCase() ?? 
              widget.model.preferredBackend.name.toUpperCase()),
          if (widget.model.supportImage)
            _buildInfoRow('پشتیبانی تصویر:', 'بله'),
          if (widget.model.supportsFunctionCalls)
            _buildInfoRow('فراخوانی تابع:', 'بله'),
          if (widget.model.isThinking)
            _buildInfoRow('قابلیت تفکر:', 'بله'),
        ],
      ),
    );
  }

  Widget _buildBackendSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'انتخاب Backend:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          BackendSelector(
            selectedBackend: _selectedBackendName,
            onBackendChanged: (backend) {
              setState(() {
                _selectedBackendName = backend;
              });
              _initializePreviewBackend();
            },
            enabled: _downloadStatus != DownloadStatus.downloading,
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
      child: Row(
        children: [
          Icon(_getStatusIcon(), color: _getStatusColor()),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _status,
                  style: TextStyle(
                    color: _getStatusColor(),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 12,
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

  Widget _buildTokenInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _tokenController,
          obscureText: true,
          enabled: _downloadStatus != DownloadStatus.downloading,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'توکن HuggingFace',
            labelStyle: const TextStyle(color: Colors.white70),
            hintText: 'توکن دسترسی Hugging Face را وارد کنید',
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: Colors.grey[800],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[600]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[600]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.blue),
            ),
            suffixIcon: IconButton(
              icon: const Icon(Icons.save, color: Colors.blue),
              onPressed: _downloadStatus == DownloadStatus.downloading ? null : () async {
                final token = _tokenController.text.trim();
                if (token.isNotEmpty) {
                  await _saveToken(token);
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            text: 'برای ایجاد توکن دسترسی، به تنظیمات حساب خود در ',
            children: [
              TextSpan(
                text: 'https://huggingface.co/settings/tokens',
                style: const TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    launchUrl(Uri.parse('https://huggingface.co/settings/tokens'));
                  },
              ),
              const TextSpan(
                text: ' مراجعه کنید. مطمئن شوید که دسترسی read-repo به توکن داده‌اید.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLicenseInfo() {
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.white70),
        text: 'توافقنامه مجوز: ',
        children: [
          TextSpan(
            text: widget.model.licenseUrl,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.blue,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                launchUrl(Uri.parse(widget.model.licenseUrl));
              },
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    // Show progress for all non-idle and non-completed states
    if (_downloadStatus == DownloadStatus.idle && _progress == 0.0) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'پیشرفت دانلود: ${_progress.toStringAsFixed(1)}%',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
            Text(
              '${_calculateDownloadedSize()}GB / ${widget.model.size}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: _progress / 100.0,
          backgroundColor: Colors.grey[700],
          valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor()),
        ),
        const SizedBox(height: 16),
        _buildDownloadControls(),
      ],
    );
  }

  Widget _buildDownloadControls() {
    // Show controls based on current download status
    switch (_downloadStatus) {
      case DownloadStatus.preparing:
        return const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('در حال آماده‌سازی...', style: TextStyle(color: Colors.white70)),
          ],
        );
        
      case DownloadStatus.downloading:
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _pauseDownload,
                icon: const Icon(Icons.pause),
                label: const Text('توقف'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _stopDownload,
                icon: const Icon(Icons.stop),
                label: const Text('لغو'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        );
      
      case DownloadStatus.paused:
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _resumeDownload,
                icon: const Icon(Icons.play_arrow),
                label: const Text('ادامه'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _stopDownload,
                icon: const Icon(Icons.stop),
                label: const Text('لغو'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        );
        
      case DownloadStatus.error:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _startDownload,
            icon: const Icon(Icons.refresh),
            label: const Text('تلاش مجدد'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        );
        
      case DownloadStatus.cancelled:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _startDownload,
            icon: const Icon(Icons.download),
            label: const Text('شروع دانلود'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        );
        
      case DownloadStatus.completed:
        return const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 24),
            SizedBox(width: 8),
            Text('دانلود تکمیل شد', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ],
        );
        
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Main action button - Show/Hide based on download status
        if (_downloadStatus == DownloadStatus.idle || 
            _downloadStatus == DownloadStatus.error ||
            _downloadStatus == DownloadStatus.cancelled) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _needToDownload ? _startDownload : _deleteModel,
              icon: Icon(_needToDownload ? Icons.download : Icons.delete),
              label: Text(_needToDownload ? 'شروع دانلود' : 'حذف مدل'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _needToDownload ? Colors.blue : Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
        
        // Show delete button when completed
        if (_downloadStatus == DownloadStatus.completed && !_needToDownload) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _deleteModel,
              icon: const Icon(Icons.delete),
              label: const Text('حذف مدل'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
        
        // Chat button - Show when download is completed
        if (_downloadStatus == DownloadStatus.completed || !_needToDownload) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _navigateToChat,
              icon: const Icon(Icons.chat),
              label: const Text('استفاده از مدل در چت'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
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
      case DownloadStatus.cancelled:
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  Color _getProgressColor() {
    switch (_downloadStatus) {
      case DownloadStatus.error:
        return Colors.red;
      case DownloadStatus.paused:
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  IconData _getStatusIcon() {
    switch (_downloadStatus) {
      case DownloadStatus.error:
        return Icons.error;
      case DownloadStatus.completed:
        return Icons.check_circle;
      case DownloadStatus.downloading:
        return Icons.download;
      case DownloadStatus.paused:
        return Icons.pause_circle;
      case DownloadStatus.cancelled:
        return Icons.cancel;
      case DownloadStatus.preparing:
        return Icons.build;
      default:
        return Icons.info;
    }
  }

  String _calculateDownloadedSize() {
    final sizeStr = widget.model.size.replaceAll(RegExp(r'[^0-9.]'), '');
    final sizeNum = sizeStr.isEmpty ? 1.0 : double.tryParse(sizeStr) ?? 1.0;
    return (sizeNum * _progress / 100).toStringAsFixed(1);
  }
}