// frontend/screens/settings_screen.dart - Settings page with modern design
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../shared/models.dart' as models;
import '../../main.dart' as main;
import '../../network/rag_worker.dart';
import '../../network/routing_client.dart';
import 'embedding_download_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  models.EmbeddingModel? _installedModel;
  bool _isLoading = true;
  bool _isModelReady = false;
  String _statusMessage = 'Checking...';
  RAGWorker? _ragWorker;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _ragWorker = main.ragWorker;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _checkStatus();
  }


  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Checking embedding model status...';
    });

    _installedModel = await main.ragManager.embeddingService.getInstalledModel();
    _isModelReady = main.ragManager.isReady;

    setState(() {
      _isLoading = false;
      if (_installedModel != null) {
        if (_isModelReady) {
          _statusMessage = 'Model ready: ${_installedModel!.displayName}';
        } else {
          _statusMessage = 'Model installed but not loaded';
        }
      } else {
        _statusMessage = 'No embedding model installed';
      }
    });
  }

  Future<void> _downloadModel(models.EmbeddingModel model) async {
    HapticFeedback.lightImpact();
    final result = await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            EmbeddingDownloadScreen(model: model),
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

    if (result == true) {
      _checkStatus();
    }
  }

  Future<void> _loadModel() async {
    if (_installedModel == null) {
      _showSnackBar('No model installed. Please download first.', Colors.orange);
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isLoading = true;
      _statusMessage = 'Loading model...';
    });

    final success = await main.ragManager.loadEmbeddingModel(_installedModel!);

    if (success) {
      _showSnackBar('Model loaded successfully', Colors.green);

      if (_ragWorker == null || !_ragWorker!.isRunning) {
        try {
          final client = RoutingClient('http://192.168.1.100:8000');
          _ragWorker = RAGWorker(main.ragManager, client);
          await _ragWorker!.start();
          main.ragWorker = _ragWorker;
          _showSnackBar('RAG Worker started', Colors.green);
        } catch (e) {
          _showSnackBar('Failed to start RAG Worker: $e', Colors.red);
        }
      }
    } else {
      _showSnackBar('Failed to load model', Colors.red);
    }

    _checkStatus();
  }

  Future<void> _disposeModel() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isLoading = true;
      _statusMessage = 'Disposing model...';
    });

    if (_ragWorker != null && _ragWorker!.isRunning) {
      await _ragWorker!.stop();
      _showSnackBar('RAG Worker stopped', Colors.orange);
    }

    await main.ragManager.embeddingService.dispose();
    _showSnackBar('Model disposed', Colors.green);

    _checkStatus();
  }

  void _showSnackBar(String message, Color backgroundColor) {
    if (mounted) {
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
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A1D2E),
            const Color(0xFF2A2D3E),
            Colors.teal.shade900.withOpacity(0.3),
          ],
        ),
      ),
      child: SafeArea(
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      _statusMessage,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        _buildStatusCard(),
                        const SizedBox(height: 16),
                        _buildEmbeddingModelSection(),
                        const SizedBox(height: 16),
                        _buildRAGWorkerSection(),
                        const SizedBox(height: 16),
                        _buildStatisticsSection(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Settings',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.teal.shade600,
                  Colors.teal.shade400,
                ],
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.teal.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () {
                HapticFeedback.lightImpact();
                _checkStatus();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final IconData icon;
    final Color color;
    final String title;

    if (_isModelReady) {
      icon = Icons.check_circle_outline;
      color = Colors.green;
      title = 'RAG System Ready';
    } else if (_installedModel != null) {
      icon = Icons.warning_amber_rounded;
      color = Colors.orange;
      title = 'Model Not Loaded';
    } else {
      icon = Icons.error_outline;
      color = Colors.red;
      title = 'No Model Installed';
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
          color: color.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _statusMessage,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmbeddingModelSection() {
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
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
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
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.shade600.withOpacity(0.3),
                      Colors.purple.shade600.withOpacity(0.3),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.memory,
                  color: Colors.blue.shade300,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Embedding Model',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_installedModel != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.green.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade400, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _installedModel!.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Dimension: ${_installedModel!.dimension} | Size: ${_installedModel!.size}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    label: 'Load',
                    icon: Icons.play_arrow,
                    color: Colors.green,
                    onPressed: _isModelReady ? null : _loadModel,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    label: 'Dispose',
                    icon: Icons.stop,
                    color: Colors.red,
                    onPressed: _isModelReady ? _disposeModel : null,
                  ),
                ),
              ],
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade400, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'No model installed',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Download a model to enable RAG features',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildActionButton(
              label: 'Download Model',
              icon: Icons.download,
              color: Colors.blue,
              onPressed: _showDownloadDialog,
              fullWidth: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRAGWorkerSection() {
    final isRunning = _ragWorker?.isRunning ?? false;
    final isPaused = _ragWorker?.isPaused ?? false;
    final processedCount = _ragWorker?.processedCount ?? 0;

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
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
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
                  gradient: LinearGradient(
                    colors: [
                      Colors.green.shade600.withOpacity(0.3),
                      Colors.teal.shade600.withOpacity(0.3),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.cloud_sync_outlined,
                  color: Colors.green.shade300,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'RAG Worker',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (isRunning ? Colors.green : Colors.red).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (isRunning ? Colors.green : Colors.red).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      isRunning ? Icons.check_circle_outline : Icons.cancel_outlined,
                      color: isRunning ? Colors.green.shade400 : Colors.red.shade400,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isRunning ? (isPaused ? 'Paused' : 'Running') : 'Stopped',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Processed queries: $processedCount',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (!_isModelReady) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Load embedding model to enable RAG Worker',
                            style: TextStyle(
                              color: Colors.orange.shade200,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildStatisticsSection() {
    final chunkCount = main.ragManager.getTotalChunkCount();
    final sources = main.ragManager.getAllSources();

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
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
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
                  gradient: LinearGradient(
                    colors: [
                      Colors.orange.shade600.withOpacity(0.3),
                      Colors.red.shade600.withOpacity(0.3),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.analytics_outlined,
                  color: Colors.orange.shade300,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Database Statistics',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _buildStatBox('Total Chunks', chunkCount.toString(), Icons.view_agenda_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatBox('Documents', sources.length.toString(), Icons.description_outlined),
              ),
            ],
          ),

          const SizedBox(height: 16),

          _buildActionButton(
            label: 'Clear All Data',
            icon: Icons.delete_forever,
            color: Colors.red,
            onPressed: chunkCount > 0 ? _clearDatabase : null,
            fullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value, IconData icon) {
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
          Icon(icon, color: Colors.blue.shade300, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: Colors.blue.shade300,
              fontSize: 24,
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
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    bool fullWidth = false,
  }) {
    return Container(
      height: 50,
      width: fullWidth ? double.infinity : null,
      decoration: BoxDecoration(
        gradient: onPressed != null
            ? LinearGradient(
                colors: [
                  color,
                  color.withOpacity(0.7),
                ],
              )
            : null,
        color: onPressed == null ? Colors.grey.shade800 : null,
        borderRadius: BorderRadius.circular(14),
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed != null
              ? () {
                  HapticFeedback.lightImpact();
                  onPressed();
                }
              : null,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDownloadDialog() {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2D3E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Text(
          'Select Embedding Model',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: models.EmbeddingModel.values.length,
            itemBuilder: (context, index) {
              final model = models.EmbeddingModel.values[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.05),
                      Colors.white.withOpacity(0.02),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: ListTile(
                  title: Text(
                    model.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Dimension: ${model.dimension} | Size: ${model.size}',
                    style: TextStyle(color: Colors.white.withOpacity(0.6)),
                  ),
                  trailing: Icon(Icons.download, color: Colors.blue.shade300),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                    _downloadModel(model);
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _clearDatabase() async {
    HapticFeedback.mediumImpact();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2D3E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Text(
          'Clear All Data?',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This will delete all document chunks from the database. This action cannot be undone.',
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context, false);
            },
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red.shade600, Colors.red.shade400],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.pop(context, true);
              },
              child: const Text(
                'Clear',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await main.ragManager.clearAll();
      if (success) {
        _showSnackBar('Database cleared', Colors.green);
        setState(() {});
      } else {
        _showSnackBar('Failed to clear database', Colors.red);
      }
    }
  }
}
