// model_download_screen.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemma/pigeon.g.dart';
import 'chat_screen.dart';
import 'services/model_download_service.dart';
import 'models/model.dart';
import 'package:url_launcher/url_launcher.dart';

class ModelDownloadScreen extends StatefulWidget {
  final Model model;
  final PreferredBackend? selectedBackend;

  const ModelDownloadScreen({
    super.key, 
    required this.model, 
    this.selectedBackend,
  });

  @override
  State<ModelDownloadScreen> createState() => _ModelDownloadScreenState();
}

class _ModelDownloadScreenState extends State<ModelDownloadScreen> {
  late ModelDownloadService _downloadService;
  bool needToDownload = true;
  double _progress = 0.0;
  String _token = '';
  String _status = '';
  final TextEditingController _tokenController = TextEditingController();
  
  // Download control states
  bool _isDownloading = false;
  bool _isPaused = false;
  bool _canResume = false;

  @override
  void initState() {
    super.initState();
    _downloadService = ModelDownloadService(
      modelUrl: widget.model.url,
      modelFilename: widget.model.filename,
      licenseUrl: widget.model.licenseUrl,
    );
    _initialize();
  }

  @override
  void dispose() {
    _downloadService.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    _token = await _downloadService.loadToken() ?? '';
    _tokenController.text = _token;
    needToDownload = !(await _downloadService.checkModelExistence(_token));
    setState(() {
      _status = needToDownload ? 'آماده برای دانلود' : 'مدل موجود است';
    });
  }

  Future<void> _saveToken(String token) async {
    await _downloadService.saveToken(token);
    await _initialize();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('توکن با موفقیت ذخیره شد!')),
      );
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
      _isDownloading = true;
      _isPaused = false;
      _canResume = false;
    });

    try {
      await _downloadService.downloadModel(
        token: widget.model.needsAuth ? _token : '',
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _progress = progress;
            });
          }
        },
        onStatus: (status) {
          if (mounted) {
            setState(() {
              _status = status;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          needToDownload = false;
          _isDownloading = false;
          _progress = 0.0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('مدل با موفقیت دانلود شد!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _canResume = true;
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
      await _downloadService.pauseDownload();
      setState(() {
        _isPaused = true;
        _canResume = true;
        _status = 'دانلود متوقف شد';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'خطا در توقف: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _resumeDownload() async {
    setState(() {
      _isPaused = false;
      _canResume = false;
      _isDownloading = true;
      _status = 'در حال از سرگیری...';
    });

    try {
      await _downloadService.resumeDownload(
        token: widget.model.needsAuth ? _token : '',
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _progress = progress;
            });
          }
        },
        onStatus: (status) {
          if (mounted) {
            setState(() {
              _status = status;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          needToDownload = false;
          _isDownloading = false;
          _progress = 0.0;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _canResume = true;
          _status = 'خطا در ادامه دانلود: ${e.toString()}';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در ادامه دانلود: ${e.toString()}'),
            action: SnackBarAction(
              label: 'تلاش مجدد',
              onPressed: _startDownload,
            ),
          ),
        );
      }
    }
  }

  Future<void> _stopDownload() async {
    try {
      setState(() {
        _status = 'در حال لغو دانلود...';
      });
      
      await _downloadService.stopDownload();
      
      // Wait a bit for cleanup
      await Future.delayed(const Duration(milliseconds: 1000));
      
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _isPaused = false;
          _canResume = false;
          _progress = 0.0;
          _status = 'دانلود لغو شد';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _isPaused = false;
          _canResume = false;
          _progress = 0.0;
          _status = 'خطا در لغو: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _deleteModel() async {
    // Show confirmation dialog
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
          needToDownload = true;
          _status = 'مدل حذف شد';
        });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('دانلود مدل'),
        backgroundColor: Colors.grey[900],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          spacing: 16,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'دانلود مدل ${widget.model.displayName}',
              style: const TextStyle(
                fontSize: 24, 
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            
            // Model info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'اطلاعات مدل',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow('نام:', widget.model.displayName),
                  _buildInfoRow('حجم:', widget.model.size),
                  _buildInfoRow('پردازنده:', widget.selectedBackend?.name.toUpperCase() ?? widget.model.preferredBackend.name.toUpperCase()),
                  if (widget.model.supportImage)
                    _buildInfoRow('پشتیبانی تصویر:', 'بله'),
                  if (widget.model.supportsFunctionCalls)
                    _buildInfoRow('فراخوانی تابع:', 'بله'),
                  if (widget.model.isThinking)
                    _buildInfoRow('قابلیت تفکر:', 'بله'),
                ],
              ),
            ),

            // Status indicator
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getStatusColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _getStatusColor()),
              ),
              child: Row(
                children: [
                  Icon(_getStatusIcon(), color: _getStatusColor()),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _status,
                      style: TextStyle(color: _getStatusColor(), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

            // Token input (if needed)
            if (widget.model.needsAuth) ...[
              TextField(
                controller: _tokenController,
                obscureText: true,
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
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.save, color: Colors.blue),
                    onPressed: () async {
                      final token = _tokenController.text.trim();
                      if (token.isNotEmpty) {
                        await _saveToken(token);
                      }
                    },
                  ),
                ),
              ),
              
              RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.white70),
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

            // License info
            if (widget.model.licenseUrl.isNotEmpty)
              RichText(
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
              ),

            const Spacer(),

            // Download progress section
            if (_isDownloading || _progress > 0) ...[
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'پیشرفت دانلود: ${_progress.toStringAsFixed(1)}%',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '${(() {
                          final sizeStr = widget.model.size.replaceAll(RegExp(r'[^0-9.]'), '');
                          final sizeNum = sizeStr.isEmpty ? 1.0 : double.tryParse(sizeStr) ?? 1.0;
                          return (sizeNum * _progress / 100).toStringAsFixed(1);
                        })()}GB / ${widget.model.size}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _progress / 100.0,
                    backgroundColor: Colors.grey[700],
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (_isDownloading && !_isPaused)
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
                      if (_isPaused || _canResume) ...[
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
                      ],
                      if (_isDownloading || _canResume)
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
                  ),
                ],
              ),
            ] else ...[
              // Download/Delete buttons when not downloading
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: needToDownload ? _startDownload : _deleteModel,
                  icon: Icon(needToDownload ? Icons.download : Icons.delete),
                  label: Text(needToDownload ? 'شروع دانلود' : 'حذف مدل'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: needToDownload ? Colors.blue : Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],

            // Chat button
            if (!needToDownload && !_isDownloading)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute<void>(
                        builder: (context) => ChatScreen(
                          model: widget.model, 
                          selectedBackend: widget.selectedBackend,
                        ),
                      ),
                    );
                  },
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

            const SizedBox(height: 16),
          ],
        ),
      ),
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
              style: const TextStyle(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    if (_status.contains('خطا') || _status.contains('لغو')) {
      return Colors.red;
    } else if (_status.contains('تکمیل') || _status.contains('موجود')) {
      return Colors.green;
    } else if (_status.contains('متوقف') || _status.contains('توقف')) {
      return Colors.orange;
    } else {
      return Colors.blue;
    }
  }

  IconData _getStatusIcon() {
    if (_status.contains('خطا')) {
      return Icons.error;
    } else if (_status.contains('تکمیل') || _status.contains('موجود')) {
      return Icons.check_circle;
    } else if (_status.contains('متوقف')) {
      return Icons.pause_circle;
    } else if (_status.contains('لغو')) {
      return Icons.cancel;
    } else {
      return Icons.info;
    }
  }
}