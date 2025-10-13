// frontend/screens/embedding_download_screen.dart - Modern download screen for embedding models
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma/mobile/flutter_gemma_mobile.dart';
import '../../shared/models.dart' as models;
import '../../download/model_store.dart';
import '../../shared/logger.dart';

class EmbeddingDownloadScreen extends StatefulWidget {
  final models.EmbeddingModel model;
  const EmbeddingDownloadScreen({super.key, required this.model});

  @override
  State<EmbeddingDownloadScreen> createState() => _EmbeddingDownloadScreenState();
}

class _EmbeddingDownloadScreenState extends State<EmbeddingDownloadScreen>
    with TickerProviderStateMixin {
  final _store = ModelStore();
  final _tokenController = TextEditingController();
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  bool _needsDownload = true;
  bool _showTokenField = false;
  String _token = '';
  double _progress = 0.0;
  String _status = '';
  bool _isDownloading = false;
  bool _downloadCompleted = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
    _init();
  }

  Future<void> _init() async {
    _token = await _store.loadToken('embedding_${widget.model.displayName}') ?? '';
    _tokenController.text = _token;

    try {
      final mobileManager = FlutterGemmaPlugin.instance.modelManager as MobileModelManager;
      final embeddingSpec = MobileModelManager.createEmbeddingSpec(
        name: widget.model.displayName,
        modelUrl: widget.model.url,
        tokenizerUrl: widget.model.tokenizerUrl,
      );
      _needsDownload = !(await mobileManager.isModelInstalled(embeddingSpec));
    } catch (e) {
      Log.w('Failed to check model installation: $e', 'EmbeddingDownload');
      _needsDownload = true;
    }

    if (mounted) {
      setState(() {
        _status = _needsDownload ? 'Ready to download' : 'Model ready';
        _showTokenField = widget.model.needsAuth && _token.isEmpty;
      });
    }
  }

  Future<void> _saveToken() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) return;

    HapticFeedback.lightImpact();
    await _store.saveToken('embedding_${widget.model.displayName}', token);
    _token = token;
    await _init();

    if (mounted) {
      setState(() => _showTokenField = false);
    }
    _showSnackbar('Token saved', Colors.green);
  }

  Future<void> _startDownload() async {
    if (widget.model.needsAuth && _token.isEmpty) {
      if (mounted) {
        setState(() => _showTokenField = true);
      }
      _showSnackbar('Please enter token first', Colors.orange);
      return;
    }

    if (_isDownloading) {
      _showSnackbar('Download in progress', Colors.orange);
      return;
    }

    HapticFeedback.mediumImpact();

    setState(() {
      _isDownloading = true;
      _status = 'Starting download...';
      _progress = 0.0;
    });

    try {
      Log.i('Starting download for ${widget.model.displayName}', 'EmbeddingDownload');

      final mobileManager = FlutterGemmaPlugin.instance.modelManager as MobileModelManager;
      final embeddingSpec = MobileModelManager.createEmbeddingSpec(
        name: widget.model.displayName,
        modelUrl: widget.model.url,
        tokenizerUrl: widget.model.tokenizerUrl,
      );

      final downloadStream = mobileManager.downloadModelWithProgress(
        embeddingSpec,
        token: widget.model.needsAuth && _token.isNotEmpty ? _token : null,
      );

      await for (final progress in downloadStream) {
        if (!mounted) break;

        setState(() {
          _progress = progress.overallProgress.toDouble();
          _status = 'Downloading... ${_progress.toStringAsFixed(1)}%';
        });

        if (progress.overallProgress >= 100) {
          _onDownloadCompleted();
          break;
        }
      }
    } catch (e) {
      Log.e('Download failed', 'EmbeddingDownload', e);
      _onDownloadError(e.toString());
    }
  }

  void _onDownloadCompleted() {
    if (!mounted) return;

    setState(() {
      _downloadCompleted = true;
      _isDownloading = false;
      _needsDownload = false;
      _status = 'Download completed!';
      _progress = 100.0;
    });

    HapticFeedback.heavyImpact();
    _showSnackbar('Model downloaded successfully!', Colors.green);
    Log.s('Embedding model download completed', 'EmbeddingDownload');

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        Navigator.pop(context, true);
      }
    });
  }

  void _onDownloadError(String error) {
    if (!mounted) return;

    setState(() {
      _isDownloading = false;
      _status = 'Download failed';
    });

    _showSnackbar('Download error: $error', Colors.red);
    Log.e('Embedding model download failed', 'EmbeddingDownload', error);
  }

  void _showSnackbar(String message, Color backgroundColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1A1D2E),
              const Color(0xFF2A2D3E),
              Colors.indigo.shade900.withOpacity(0.3),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildModelCard(),
                        const SizedBox(height: 20),
                        if (_showTokenField || (widget.model.needsAuth && _needsDownload))
                          _buildTokenCard(),
                        const SizedBox(height: 20),
                        _buildStatusCard(),
                        const SizedBox(height: 20),
                        _buildActionButton(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2D3E),
              borderRadius: BorderRadius.circular(15),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Download',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  widget.model.displayName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2A2D3E),
            const Color(0xFF1A1D2E),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.indigo.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Colors.indigo.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.memory,
              size: 48,
              color: Colors.indigo.shade300,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            widget.model.displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildInfoBox('Dimension', '${widget.model.dimension}', Icons.filter_9_plus)),
              const SizedBox(width: 12),
              Expanded(child: _buildInfoBox('Size', widget.model.size, Icons.file_download)),
            ],
          ),
          if (widget.model.needsAuth) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock, color: Colors.orange.shade400, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Requires HuggingFace token',
                      style: TextStyle(
                        color: Colors.orange.shade200,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoBox(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.indigo.shade300, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: Colors.indigo.shade300,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTokenCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2A2D3E),
            const Color(0xFF1A1D2E),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.orange.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.vpn_key, color: Colors.orange.shade300, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'HuggingFace Token',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _tokenController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter your HF token',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.orange.shade400,
                  width: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.orange.shade600,
                    Colors.orange.shade400,
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _saveToken,
                  borderRadius: BorderRadius.circular(14),
                  child: const Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.save, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Save Token',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    Color statusColor;
    IconData statusIcon;

    if (_downloadCompleted) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (_isDownloading) {
      statusColor = Colors.blue;
      statusIcon = Icons.downloading;
    } else if (_needsDownload) {
      statusColor = Colors.orange;
      statusIcon = Icons.cloud_download;
    } else {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2A2D3E),
            const Color(0xFF1A1D2E),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(statusIcon, color: statusColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  _status,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (_isDownloading) ...[
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: LinearProgressIndicator(
                value: _progress / 100,
                minHeight: 12,
                backgroundColor: Colors.white.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_progress.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: 0.5 + (_pulseController.value * 0.5),
                      child: Text(
                        'Downloading...',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 13,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    if (_needsDownload && !_downloadCompleted) {
      return Container(
        height: 60,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isDownloading
                ? [Colors.grey.shade700, Colors.grey.shade600]
                : [Colors.indigo.shade600, Colors.indigo.shade400],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isDownloading
              ? null
              : [
                  BoxShadow(
                    color: Colors.indigo.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isDownloading ? null : _startDownload,
            borderRadius: BorderRadius.circular(16),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isDownloading)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  else
                    const Icon(Icons.download, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    _isDownloading ? 'Downloading...' : 'Download Model',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else if (_downloadCompleted) {
      return Container(
        height: 60,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade600, Colors.green.shade400],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Text(
                'Download Completed!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return Container(
        height: 60,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade700, Colors.green.shade500],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Text(
                'Model Ready',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}
