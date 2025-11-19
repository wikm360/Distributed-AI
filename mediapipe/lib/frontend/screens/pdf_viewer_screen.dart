// ignore_for_file: unused_field

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import '../../services/translation_service.dart';
import '../../config/translation_config.dart';

class PdfViewerScreen extends StatefulWidget {
  final File pdfFile;
  final String fileName;

  const PdfViewerScreen({
    super.key,
    required this.pdfFile,
    required this.fileName,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final PdfViewerController _controller = PdfViewerController();
  final TranslationService _translationService = TranslationService();

  PdfTextRanges? _selectedTextRanges;
  String? _selectedText;
  bool _isTranslating = false;
  String? _translatedText;
  bool _isModelDownloaded = false;
  bool _isDownloadingModel = false;

  @override
  void initState() {
    super.initState();
    _initializeTranslation();
  }

  Future<void> _initializeTranslation() async {
    await _translationService.initialize();
    final isDownloaded = await _translationService.isModelDownloaded();
    if (mounted) {
      setState(() {
        _isModelDownloaded = isDownloaded;
      });
    }
  }

  Future<void> _downloadModel() async {
    if (_isDownloadingModel) return;

    setState(() {
      _isDownloadingModel = true;
    });

    final success = await _translationService.downloadModel();

    if (mounted) {
      setState(() {
        _isDownloadingModel = false;
        _isModelDownloaded = success;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Translation model downloaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to download translation model'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _translateSelectedText() async {
    if (_selectedText == null || _selectedText!.isEmpty) return;

    if (!_isModelDownloaded) {
      _showDownloadModelDialog();
      return;
    }

    setState(() {
      _isTranslating = true;
      _translatedText = null;
    });

    final translated = await _translationService.translate(_selectedText!);

    if (mounted) {
      setState(() {
        _isTranslating = false;
        _translatedText = translated;
      });

      if (translated != null) {
        _showTranslationDialog(translated);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Translation failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDownloadModelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Download Translation Model',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'To use translation, you need to download the language model first.\n\nLanguage: ${TranslationConfig.targetLanguageName}',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _downloadModel();
            },
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }

  void _showTranslationDialog(String translatedText) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Translation',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF99E6FF).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          TranslationConfig.sourceLanguageName,
                          style: const TextStyle(
                            color: Color(0xFF99E6FF),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward,
                        color: Colors.white54,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD588).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          TranslationConfig.targetLanguageName,
                          style: const TextStyle(
                            color: Color(0xFFFFD588),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        // Original text
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Original',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _selectedText ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Translated text
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFFFD588).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Translation',
                                    style: TextStyle(
                                      color: Color(0xFFFFD588),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      // Copy to clipboard
                                      // TODO: Add clipboard functionality
                                    },
                                    icon: const Icon(
                                      Icons.copy,
                                      color: Colors.white54,
                                      size: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                translatedText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                                textDirection: TextDirection.rtl,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _translationService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: Text(
          widget.fileName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // Translation model status
          if (!_isModelDownloaded)
            IconButton(
              onPressed: _isDownloadingModel ? null : _downloadModel,
              icon: _isDownloadingModel
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white70,
                      ),
                    )
                  : const Icon(Icons.download, color: Colors.white70),
              tooltip: 'Download Translation Model',
            ),
          // Clear selection
          if (_selectedText != null)
            IconButton(
              onPressed: () {
                setState(() {
                  _selectedTextRanges = null;
                  _selectedText = null;
                  _translatedText = null;
                });
              },
              icon: const Icon(Icons.clear, color: Colors.white70),
              tooltip: 'Clear Selection',
            ),
        ],
      ),
      body: Stack(
        children: [
          PdfViewer.file(
            widget.pdfFile.path,
            controller: _controller,
            params: PdfViewerParams(
              backgroundColor: const Color(0xFF0F0F0F),
              // Enable text selection
              enableTextSelection: true,
              onTextSelectionChange: (selection) {
                if (selection.isNotEmpty) {
                  setState(() {
                    _selectedTextRanges = selection.first;
                    _selectedText = selection.first.text;
                    _translatedText = null;
                  });
                } else {
                  setState(() {
                    _selectedTextRanges = null;
                    _selectedText = null;
                    _translatedText = null;
                  });
                }
              },
            ),
          ),
          // Translation button overlay
          if (_selectedText != null && _selectedText!.isNotEmpty)
            Positioned(
              bottom: 32,
              left: 24,
              right: 24,
              child: _buildTranslationButton(),
            ),
        ],
      ),
    );
  }

  Widget _buildTranslationButton() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: const Color(0xFF99E6FF),
        borderRadius: BorderRadius.circular(25),
        child: InkWell(
          onTap: _isTranslating ? null : _translateSelectedText,
          borderRadius: BorderRadius.circular(25),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isTranslating)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                else
                  const Icon(
                    Icons.translate,
                    color: Colors.black,
                    size: 20,
                  ),
                const SizedBox(width: 12),
                Text(
                  _isTranslating
                      ? 'Translating...'
                      : 'Translate to ${TranslationConfig.targetLanguageName}',
                  style: const TextStyle(
                    color: Colors.black,
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
}
