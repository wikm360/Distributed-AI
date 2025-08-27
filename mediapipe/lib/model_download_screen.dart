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
  final TextEditingController _tokenController = TextEditingController();

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

  Future<void> _initialize() async {
    _token = await _downloadService.loadToken() ?? '';
    _tokenController.text = _token;
    needToDownload = !(await _downloadService.checkModelExistence(_token));
    setState(() {});
  }

  Future<void> _saveToken(String token) async {
    await _downloadService.saveToken(token);
    await _initialize();
  }

  Future<void> _downloadModel() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (widget.model.needsAuth && _token.isEmpty) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('لطفاً ابتدا توکن خود را وارد کنید.')),
      );
      return;
    }

    try {
      await _downloadService.downloadModel(
        token: widget.model.needsAuth ? _token : '',
        onProgress: (progress) {
          setState(() {
            _progress = progress;
          });
        },
      );
      setState(() {
        needToDownload = false;
      });
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('مدل با موفقیت دانلود شد!')),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('خطا در دانلود مدل.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _progress = 0.0;
        });
      }
    }
  }

  Future<void> _deleteModel() async {
    await _downloadService.deleteModel();
    setState(() {
      needToDownload = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('مدل حذف شد.')),
    );
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
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('توکن با موفقیت ذخیره شد!'),
                            ),
                          );
                        }
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

            // Download section
            Center(
              child: _progress > 0.0
                  ? Column(
                      children: [
                        Text(
                          'پیشرفت دانلود: ${_progress.toStringAsFixed(1)}%',
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: _progress / 100.0,
                          backgroundColor: Colors.grey[700],
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                      ],
                    )
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: !needToDownload ? _deleteModel : _downloadModel,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: !needToDownload ? Colors.red : Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          !needToDownload ? 'حذف مدل' : 'دانلود مدل',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
            ),

            // Chat button
            if (!needToDownload)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'استفاده از مدل در چت',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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
}