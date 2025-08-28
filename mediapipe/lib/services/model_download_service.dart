// services/model_download_service.dart
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma_interface.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ModelDownloadService {
  final String modelUrl;
  final String modelFilename;
  final String licenseUrl;
  
  // Download control variables
  StreamSubscription<num>? _downloadSubscription;
  bool _isDownloading = false;
  bool _isPaused = false;
  bool _isStopped = false;
  
  // Completer for download control
  Completer<void>? _downloadCompleter;

  ModelDownloadService({
    required this.modelUrl,
    required this.modelFilename,
    required this.licenseUrl,
  });

  /// Load the token from SharedPreferences.
  Future<String?> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token_${modelFilename}');
  }

  /// Save the token to SharedPreferences with model-specific key.
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token_${modelFilename}', token);
  }

  /// Helper method to get the file path.
  Future<String> getFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$modelFilename';
  }

  /// Enhanced model existence check with better validation
  Future<bool> checkModelExistence(String token) async {
    try {
      final filePath = await getFilePath();
      final file = File(filePath);

      if (!file.existsSync()) {
        if (kDebugMode) {
          print('Model file does not exist: $filePath');
        }
        return false;
      }

      // Check if file size matches expected size
      final localFileSize = await file.length();
      if (localFileSize == 0) {
        // Empty file, delete it
        await file.delete();
        return false;
      }

      // Optional: Check remote file size for validation
      try {
        final Map<String, String> headers =
            token.isNotEmpty ? {'Authorization': 'Bearer $token'} : {};
        final headResponse = await http.head(
          Uri.parse(modelUrl), 
          headers: headers,
        ).timeout(const Duration(seconds: 10));

        if (headResponse.statusCode == 200) {
          final contentLengthHeader = headResponse.headers['content-length'];
          if (contentLengthHeader != null) {
            final remoteFileSize = int.parse(contentLengthHeader);
            if (localFileSize != remoteFileSize) {
              if (kDebugMode) {
                print('File size mismatch: local=$localFileSize, remote=$remoteFileSize');
              }
              // Size mismatch - file might be corrupted or partially downloaded
              // Don't delete automatically, let user decide
              return localFileSize > (remoteFileSize * 0.9); // Consider as existing if > 90%
            }
          }
        }
      } catch (e) {
        // Network check failed, but local file exists - consider it valid
        if (kDebugMode) {
          print('Remote size check failed: $e');
        }
      }

      // File exists and seems valid
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking model existence: $e');
      }
      return false;
    }
  }

  /// Enhanced download with proper state management
  Future<void> downloadModel({
    required String token,
    required Function(double) onProgress,
    required Function(String) onStatus,
  }) async {
    // Force cleanup any previous state
    await _forceCleanup();
    
    if (_isDownloading) {
      throw Exception('Download already in progress');
    }

    _isDownloading = true;
    _isPaused = false;
    _isStopped = false;
    _downloadCompleter = Completer<void>();

    try {
      onStatus('آماده‌سازی دانلود...');
      
      // Small delay to ensure UI updates
      await Future.delayed(const Duration(milliseconds: 200));
      
      if (_isStopped) {
        throw Exception('Download cancelled during initialization');
      }
      
      onStatus('شروع دانلود...');
      
      final stream = FlutterGemmaPlugin.instance.modelManager
          .downloadModelFromNetworkWithProgress(modelUrl, token: token);
      
      _downloadSubscription = stream.listen(
        (progress) {
          if (_isStopped) {
            return; // Ignore progress updates if stopped
          }
          
          if (!_isPaused) {
            onProgress(progress.toDouble());
            if (progress < 100) {
              onStatus('در حال دانلود... ${progress.toStringAsFixed(1)}%');
            } else {
              onStatus('تکمیل دانلود');
            }
          }
        },
        onDone: () {
          if (_isStopped) {
            return; // Don't complete if manually stopped
          }
          
          if (!_downloadCompleter!.isCompleted) {
            _downloadCompleter!.complete();
          }
          _cleanup();
          onStatus('دانلود با موفقیت تکمیل شد');
        },
        onError: (error) {
          if (!_downloadCompleter!.isCompleted) {
            _downloadCompleter!.completeError(error);
          }
          _cleanup();
          onStatus('خطا در دانلود: $error');
        },
      );

      await _downloadCompleter!.future;
    } catch (e) {
      _cleanup();
      if (kDebugMode) {
        print('Error downloading model: $e');
      }
      rethrow;
    }
  }

  /// Force cleanup of any ongoing operations
  Future<void> _forceCleanup() async {
    try {
      await _downloadSubscription?.cancel();
      _downloadSubscription = null;
      
      if (_downloadCompleter != null && !_downloadCompleter!.isCompleted) {
        _downloadCompleter!.completeError('Force cleanup');
      }
      _downloadCompleter = null;
      
      _isDownloading = false;
      _isPaused = false;
      _isStopped = false;
      
      // Give some time for cleanup
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      if (kDebugMode) {
        print('Error in force cleanup: $e');
      }
    }
  }

  /// Internal cleanup method
  void _cleanup() {
    _isDownloading = false;
    _isPaused = false;
    _isStopped = false;
  }

  /// Pause download - Note: This may not work properly with Flutter Gemma
  Future<void> pauseDownload() async {
    if (_isDownloading && !_isPaused) {
      _isPaused = true;
      // Note: We keep the subscription active but just ignore progress updates
    }
  }

  /// Resume download - Actually restart the download
  Future<void> resumeDownload({
    required String token,
    required Function(double) onProgress,
    required Function(String) onStatus,
  }) async {
    if (!_isPaused && _isDownloading) {
      throw Exception('Download is not paused');
    }

    // Since Flutter Gemma doesn't support true pause/resume, we restart
    await _forceCleanup();
    await downloadModel(
      token: token,
      onProgress: onProgress,
      onStatus: onStatus,
    );
  }

  /// Stop download completely with force cleanup
  Future<void> stopDownload() async {
    _isStopped = true;
    
    try {
      // Cancel subscription first
      await _downloadSubscription?.cancel();
      _downloadSubscription = null;
      
      // Complete or error the completer
      if (_downloadCompleter != null && !_downloadCompleter!.isCompleted) {
        _downloadCompleter!.completeError('Download cancelled by user');
      }
      _downloadCompleter = null;
      
      // Reset states
      _isDownloading = false;
      _isPaused = false;
      
      // Try to delete partial file
      try {
        final filePath = await getFilePath();
        final file = File(filePath);
        if (file.existsSync()) {
          final fileSize = await file.length();
          // Only delete if file is relatively small (incomplete)
          if (fileSize < 100 * 1024 * 1024) { // Less than 100MB
            await file.delete();
            if (kDebugMode) {
              print('Deleted partial file: $filePath');
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error deleting partial file: $e');
        }
      }
      
      // Force cleanup after a delay
      Future.delayed(const Duration(seconds: 1), () {
        _isStopped = false;
      });
      
    } catch (e) {
      if (kDebugMode) {
        print('Error stopping download: $e');
      }
      _cleanup();
      _isStopped = false;
    }
  }

  /// Check download status
  bool get isDownloading => _isDownloading && !_isStopped;
  bool get isPaused => _isPaused && !_isStopped;
  bool get isStopped => _isStopped;

  /// Enhanced delete with proper cleanup
  Future<void> deleteModel() async {
    try {
      // Stop any ongoing download first
      await stopDownload();
      
      // Wait a bit for cleanup
      await Future.delayed(const Duration(milliseconds: 500));
      
      final filePath = await getFilePath();
      final file = File(filePath);

      if (file.existsSync()) {
        await file.delete();
        if (kDebugMode) {
          print('Model deleted: $filePath');
        }
      }

      // Clear related preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token_${modelFilename}');
      
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting model: $e');
      }
      rethrow;
    }
  }

  /// Cleanup resources
  void dispose() {
    _isStopped = true;
    _downloadSubscription?.cancel();
    if (_downloadCompleter != null && !_downloadCompleter!.isCompleted) {
      _downloadCompleter!.completeError('Service disposed');
    }
    _cleanup();
  }
}