// services/enhanced_model_download_service.dart
// ignore_for_file: unused_import

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';
import 'download_manager_service.dart';

/// Enhanced model download service with full control capabilities
class EnhancedModelDownloadService {
  final String modelUrl;
  final String modelFilename;
  final String licenseUrl;
  
  EnhancedDownloadManager? _downloadManager;
  StreamSubscription<DownloadProgress>? _progressSubscription;
  StreamSubscription<DownloadStatus>? _statusSubscription;
  
  // Callback functions
  Function(double)? _onProgress;
  Function(String)? _onStatus;
  Function(String)? _onError;
  
  // Current state
  bool _isInitialized = false;
  String? _lastError;

  EnhancedModelDownloadService({
    required this.modelUrl,
    required this.modelFilename,
    required this.licenseUrl,
  });

  /// Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      Logger.info("Initializing enhanced model download service", "ModelDownloadService");
      _isInitialized = true;
    } catch (e) {
      Logger.error("Failed to initialize service", "ModelDownloadService", e);
      rethrow;
    }
  }

  /// Load saved auth token
  Future<String?> loadToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('auth_token_$modelFilename');
    } catch (e) {
      Logger.error("Failed to load token", "ModelDownloadService", e);
      return null;
    }
  }

  /// Save auth token
  Future<void> saveToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token_$modelFilename', token);
      Logger.success("Token saved successfully", "ModelDownloadService");
    } catch (e) {
      Logger.error("Failed to save token", "ModelDownloadService", e);
      rethrow;
    }
  }

  /// Get the target file path
  Future<String> getFilePath() async {
    await initialize();
    
    // Create temporary download manager to get file path
    final tempManager = EnhancedDownloadManager(
      url: modelUrl,
      filename: modelFilename,
    );
    
    final path = await tempManager.getFilePath();
    tempManager.dispose();
    
    return path;
  }

  /// Check if model exists and is complete
  Future<bool> checkModelExistence([String? token]) async {
    try {
      await initialize();
      
      // Create temporary download manager
      final tempManager = EnhancedDownloadManager(
        url: modelUrl,
        filename: modelFilename,
        authToken: token,
      );
      
      final exists = await tempManager.isFileComplete();
      tempManager.dispose();
      
      Logger.info("Model existence check: $exists", "ModelDownloadService");
      return exists;
    } catch (e) {
      Logger.error("Error checking model existence", "ModelDownloadService", e);
      return false;
    }
  }

  /// Start downloading the model
  Future<void> downloadModel({
    required String token,
    required Function(double) onProgress,
    required Function(String) onStatus,
    Function(String)? onError,
  }) async {
    if (_downloadManager?.isDownloading == true) {
      throw StateError('Download already in progress');
    }

    await initialize();
    
    _onProgress = onProgress;
    _onStatus = onStatus;
    _onError = onError;
    _lastError = null;

    try {
      onStatus('آماده‌سازی دانلود...');
      
      // Create download manager
      _downloadManager = EnhancedDownloadManager(
        url: modelUrl,
        filename: modelFilename,
        authToken: token,
      );

      // Setup listeners
      _setupListeners();
      
      // Check if file already complete
      if (await _downloadManager!.isFileComplete()) {
        onStatus('مدل از قبل دانلود شده است');
        onProgress(100.0);
        return;
      }

      onStatus('شروع دانلود...');
      await _downloadManager!.startDownload();
      
    } catch (e) {
      _lastError = e.toString();
      Logger.error("Download failed", "ModelDownloadService", e);
      onStatus('خطا در دانلود: $e');
      if (onError != null) {
        onError(e.toString());
      }
      await _cleanup();
      rethrow;
    }
  }

  /// Pause current download
  Future<void> pauseDownload() async {
    if (_downloadManager == null) {
      Logger.warning("No active download to pause", "ModelDownloadService");
      return;
    }

    try {
      await _downloadManager!.pauseDownload();
      _onStatus?.call('دانلود متوقف شد');
      Logger.success("Download paused successfully", "ModelDownloadService");
    } catch (e) {
      Logger.error("Failed to pause download", "ModelDownloadService", e);
      _onStatus?.call('خطا در توقف دانلود: $e');
      rethrow;
    }
  }

  /// Resume paused download
  Future<void> resumeDownload({
    required String token,
    required Function(double) onProgress,
    required Function(String) onStatus,
    Function(String)? onError,
  }) async {
    if (_downloadManager == null || !_downloadManager!.isPaused) {
      // If no manager or not paused, start fresh
      return downloadModel(
        token: token,
        onProgress: onProgress,
        onStatus: onStatus,
        onError: onError,
      );
    }

    _onProgress = onProgress;
    _onStatus = onStatus;
    _onError = onError;

    try {
      onStatus('در حال ادامه دانلود...');
      await _downloadManager!.resumeDownload();
      Logger.success("Download resumed successfully", "ModelDownloadService");
    } catch (e) {
      Logger.error("Failed to resume download", "ModelDownloadService", e);
      onStatus('خطا در ادامه دانلود: $e');
      if (onError != null) {
        onError(e.toString());
      }
      rethrow;
    }
  }

  /// Stop/cancel current download
  Future<void> stopDownload() async {
    if (_downloadManager == null) {
      Logger.warning("No active download to stop", "ModelDownloadService");
      return;
    }

    try {
      await _downloadManager!.cancelDownload();
      _onStatus?.call('دانلود لغو شد');
      Logger.success("Download cancelled successfully", "ModelDownloadService");
    } catch (e) {
      Logger.error("Failed to cancel download", "ModelDownloadService", e);
      _onStatus?.call('خطا در لغو دانلود: $e');
    } finally {
      await _cleanup();
    }
  }

  /// Delete downloaded model
  Future<void> deleteModel() async {
    try {
      // Stop any active download first
      await stopDownload();
      
      // Create temporary manager to delete file
      if (_downloadManager == null) {
        _downloadManager = EnhancedDownloadManager(
          url: modelUrl,
          filename: modelFilename,
        );
      }
      
      await _downloadManager!.deleteFile();
      
      // Clear saved token
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token_$modelFilename');
      
      Logger.success("Model deleted successfully", "ModelDownloadService");
    } catch (e) {
      Logger.error("Failed to delete model", "ModelDownloadService", e);
      rethrow;
    } finally {
      await _cleanup();
    }
  }

  /// Setup progress and status listeners
  void _setupListeners() {
    if (_downloadManager == null) return;

    // Progress listener
    _progressSubscription = _downloadManager!.progressStream.listen(
      (progress) {
        _onProgress?.call(progress.percentage);
        
        if (progress.status == DownloadStatus.downloading) {
          final speedMB = (progress.speed / 1024 / 1024);
          final remainingTime = progress.estimatedTime;
          
          String statusText = 'در حال دانلود... ${progress.percentage.toStringAsFixed(1)}%';
          
          if (speedMB > 0) {
            statusText += ' - ${speedMB.toStringAsFixed(1)} MB/s';
          }
          
          if (remainingTime.inSeconds > 0) {
            final minutes = remainingTime.inMinutes;
            final seconds = remainingTime.inSeconds % 60;
            statusText += ' - باقیمانده: ${minutes}m ${seconds}s';
          }
          
          _onStatus?.call(statusText);
        }
        
        if (progress.error != null) {
          _lastError = progress.error;
          _onError?.call(progress.error!);
        }
      },
      onError: (error) {
        _lastError = error.toString();
        Logger.error("Progress stream error", "ModelDownloadService", error);
        _onError?.call(error.toString());
      },
    );

    // Status listener
    _statusSubscription = _downloadManager!.statusStream.listen(
      (status) {
        switch (status) {
          case DownloadStatus.preparing:
            _onStatus?.call('آماده‌سازی دانلود...');
            break;
          case DownloadStatus.downloading:
            _onStatus?.call('در حال دانلود...');
            break;
          case DownloadStatus.paused:
            _onStatus?.call('دانلود متوقف شده');
            break;
          case DownloadStatus.completed:
            _onStatus?.call('دانلود با موفقیت تکمیل شد');
            _onProgress?.call(100.0);
            _cleanup();
            break;
          case DownloadStatus.cancelled:
            _onStatus?.call('دانلود لغو شد');
            _cleanup();
            break;
          case DownloadStatus.error:
            _onStatus?.call('خطا در دانلود: $_lastError');
            _cleanup();
            break;
          default:
            break;
        }
      },
      onError: (error) {
        Logger.error("Status stream error", "ModelDownloadService", error);
        _onError?.call(error.toString());
      },
    );
  }

  /// Get current download status
  DownloadStatus? get downloadStatus => _downloadManager?.status;
  
  /// Check if download is active
  bool get isDownloading => _downloadManager?.isDownloading ?? false;
  
  /// Check if download is paused
  bool get isPaused => _downloadManager?.isPaused ?? false;
  
  /// Check if download is completed
  bool get isCompleted => _downloadManager?.isCompleted ?? false;
  
  /// Check if download is cancelled
  bool get isCancelled => _downloadManager?.isCancelled ?? false;
  
  /// Get current download progress (0.0 to 1.0)
  double get progress => _downloadManager?.progress ?? 0.0;
  
  /// Get last error message
  String? get lastError => _lastError;

  /// Cleanup resources
  Future<void> _cleanup() async {
    await _progressSubscription?.cancel();
    await _statusSubscription?.cancel();
    
    _progressSubscription = null;
    _statusSubscription = null;
    _onProgress = null;
    _onStatus = null;
    _onError = null;
  }

  /// Dispose the service
  Future<void> dispose() async {
    try {
      await _cleanup();
      await _downloadManager?.dispose();
      _downloadManager = null;
      _isInitialized = false;
      Logger.info("Model download service disposed", "ModelDownloadService");
    } catch (e) {
      Logger.error("Error disposing service", "ModelDownloadService", e);
    }
  }
}