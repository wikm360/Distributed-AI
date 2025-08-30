// services/enhanced_download_manager.dart
import 'dart:async';
import 'dart:io';
// ignore_for_file: unused_import
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

enum DownloadStatus {
  idle,
  preparing,
  downloading,
  paused,
  completed,
  cancelled,
  error,
}

class DownloadProgress {
  final int downloaded;
  final int total;
  final double percentage;
  final int speed; // bytes per second
  final Duration estimatedTime;
  final DownloadStatus status;
  final String? error;

  DownloadProgress({
    required this.downloaded,
    required this.total,
    required this.percentage,
    required this.speed,
    required this.estimatedTime,
    required this.status,
    this.error,
  });

  DownloadProgress copyWith({
    int? downloaded,
    int? total,
    double? percentage,
    int? speed,
    Duration? estimatedTime,
    DownloadStatus? status,
    String? error,
  }) {
    return DownloadProgress(
      downloaded: downloaded ?? this.downloaded,
      total: total ?? this.total,
      percentage: percentage ?? this.percentage,
      speed: speed ?? this.speed,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}

class EnhancedDownloadManager {
  final String url;
  final String filename;
  final String? authToken;
  
  // Internal state
  DownloadStatus _status = DownloadStatus.idle;
  http.Client? _client;
  IOSink? _fileSink;
  File? _targetFile;
  File? _tempFile;
  StreamSubscription<List<int>>? _downloadSubscription;
  
  // Progress tracking
  int _downloadedBytes = 0;
  int _totalBytes = 0;
  DateTime? _startTime;
  DateTime? _lastProgressTime;
  int _lastDownloadedBytes = 0;
  List<int> _speedSamples = [];
  
  // Control
  bool _isPaused = false;
  bool _isCancelled = false;
  // ignore: unused_field
  Completer<void>? _pauseCompleter;
  
  // Stream controllers
  final StreamController<DownloadProgress> _progressController = 
      StreamController<DownloadProgress>.broadcast();
  final StreamController<DownloadStatus> _statusController = 
      StreamController<DownloadStatus>.broadcast();

  EnhancedDownloadManager({
    required this.url,
    required this.filename,
    this.authToken,
  });

  // Getters
  DownloadStatus get status => _status;
  Stream<DownloadProgress> get progressStream => _progressController.stream;
  Stream<DownloadStatus> get statusStream => _statusController.stream;
  bool get isDownloading => _status == DownloadStatus.downloading;
  bool get isPaused => _status == DownloadStatus.paused;
  bool get isCompleted => _status == DownloadStatus.completed;
  bool get isCancelled => _status == DownloadStatus.cancelled;
  double get progress => _totalBytes > 0 ? _downloadedBytes / _totalBytes : 0.0;

  /// Start or resume download
  Future<void> startDownload() async {
    if (_status == DownloadStatus.downloading) {
      Logger.warning("Download already in progress", "DownloadManager");
      return;
    }

    try {
      _updateStatus(DownloadStatus.preparing);
      
      // Initialize file paths
      await _initializeFiles();
      
      // Check if partial download exists
      if (_tempFile!.existsSync()) {
        _downloadedBytes = await _tempFile!.length();
        Logger.info("Resuming download from ${_downloadedBytes} bytes", "DownloadManager");
      } else {
        _downloadedBytes = 0;
      }

      _updateStatus(DownloadStatus.downloading);
      await _performDownload();
      
    } catch (e) {
      Logger.error("Download failed", "DownloadManager", e);
      _updateStatus(DownloadStatus.error);
      _emitProgress(error: e.toString());
    }
  }

  /// Pause download
  Future<void> pauseDownload() async {
    if (_status != DownloadStatus.downloading) {
      Logger.warning("Cannot pause: download not in progress", "DownloadManager");
      return;
    }

    Logger.info("Pausing download...", "DownloadManager");
    _isPaused = true;
    _pauseCompleter = Completer<void>();
    
    // Cancel current request
    await _cleanupDownload();
    
    _updateStatus(DownloadStatus.paused);
    Logger.success("Download paused", "DownloadManager");
  }

  /// Resume paused download
  Future<void> resumeDownload() async {
    if (_status != DownloadStatus.paused) {
      Logger.warning("Cannot resume: download not paused", "DownloadManager");
      return;
    }

    Logger.info("Resuming download...", "DownloadManager");
    _isPaused = false;
    _pauseCompleter = null;
    
    await startDownload();
  }

  /// Cancel download completely
  Future<void> cancelDownload() async {
    Logger.info("Cancelling download...", "DownloadManager");
    
    _isCancelled = true;
    await _cleanupDownload();
    
    // Delete temp file
    if (_tempFile?.existsSync() == true) {
      await _tempFile!.delete();
    }
    
    _updateStatus(DownloadStatus.cancelled);
    Logger.success("Download cancelled", "DownloadManager");
  }

  /// Delete downloaded file
  Future<void> deleteFile() async {
    await cancelDownload();
    
    if (_targetFile?.existsSync() == true) {
      await _targetFile!.delete();
      Logger.info("Downloaded file deleted", "DownloadManager");
    }
    
    // Clear saved progress
    await _clearSavedProgress();
  }

  /// Check if file already exists and is complete
  Future<bool> isFileComplete() async {
    await _initializeFiles();
    
    if (!_targetFile!.existsSync()) return false;
    
    try {
      // Get remote file size to compare
      final response = await http.head(Uri.parse(url), headers: _getHeaders());
      if (response.statusCode == 200) {
        final remoteSize = int.tryParse(response.headers['content-length'] ?? '0') ?? 0;
        final localSize = await _targetFile!.length();
        return localSize == remoteSize && remoteSize > 0;
      }
    } catch (e) {
      Logger.warning("Could not verify file completeness: $e", "DownloadManager");
    }
    
    return false;
  }

  /// Get file path
  Future<String> getFilePath() async {
    await _initializeFiles();
    return _targetFile!.path;
  }

  /// Initialize file paths
  Future<void> _initializeFiles() async {
    if (_targetFile != null && _tempFile != null) return;
    
    final directory = await getApplicationDocumentsDirectory();
    _targetFile = File('${directory.path}/$filename');
    _tempFile = File('${directory.path}/$filename.tmp');
  }

  /// Perform the actual download
  Future<void> _performDownload() async {
    _client = http.Client();
    _startTime = DateTime.now();
    _lastProgressTime = _startTime;
    _lastDownloadedBytes = _downloadedBytes;
    
    try {
      // Create request with range header for resume support
      final request = http.Request('GET', Uri.parse(url));
      request.headers.addAll(_getHeaders());
      
      if (_downloadedBytes > 0) {
        request.headers['Range'] = 'bytes=$_downloadedBytes-';
      }

      // Send request
      final streamedResponse = await _client!.send(request);
      
      if (streamedResponse.statusCode != 200 && streamedResponse.statusCode != 206) {
        throw Exception('HTTP ${streamedResponse.statusCode}');
      }

      // Get total file size
      _totalBytes = _downloadedBytes + (streamedResponse.contentLength ?? 0);
      if (streamedResponse.statusCode == 200) {
        _totalBytes = streamedResponse.contentLength ?? 0;
        _downloadedBytes = 0;
        // Delete existing temp file for fresh start
        if (_tempFile!.existsSync()) {
          await _tempFile!.delete();
        }
      }

      // Open file for writing
      _fileSink = _tempFile!.openWrite(mode: FileMode.append);

      // Listen to download stream
      _downloadSubscription = streamedResponse.stream.listen(
        _onDataReceived,
        onDone: _onDownloadComplete,
        onError: _onDownloadError,
        cancelOnError: true,
      );

      Logger.info("Download started: ${_downloadedBytes}/${_totalBytes} bytes", "DownloadManager");
      
    } catch (e) {
      await _cleanupDownload();
      rethrow;
    }
  }

  /// Handle received data
  void _onDataReceived(List<int> data) {
    if (_isPaused || _isCancelled) {
      _downloadSubscription?.cancel();
      return;
    }

    _fileSink?.add(data);
    _downloadedBytes += data.length;
    
    // Update progress
    _updateProgress();
    
    // Save progress periodically
    _saveProgress();
  }

  /// Handle download completion
  void _onDownloadComplete() async {
    Logger.info("Download stream completed", "DownloadManager");
    
    await _fileSink?.close();
    _fileSink = null;
    
    if (!_isCancelled && !_isPaused) {
      // Move temp file to final location
      if (_tempFile!.existsSync()) {
        await _tempFile!.rename(_targetFile!.path);
        Logger.success("File moved to final location: ${_targetFile!.path}", "DownloadManager");
      }
      
      _updateStatus(DownloadStatus.completed);
      _emitProgress();
      
      // Clear temp data
      await _clearSavedProgress();
    }
    
    await _cleanupDownload();
  }

  /// Handle download error
  void _onDownloadError(Object error) async {
    Logger.error("Download stream error", "DownloadManager", error);
    
    await _cleanupDownload();
    
    if (!_isPaused && !_isCancelled) {
      _updateStatus(DownloadStatus.error);
      _emitProgress(error: error.toString());
    }
  }

  /// Update download progress and emit events
  void _updateProgress() {
    final now = DateTime.now();
    
    // Calculate speed (every 1 second)
    if (_lastProgressTime != null && 
        now.difference(_lastProgressTime!).inMilliseconds >= 1000) {
      
      final timeDiff = now.difference(_lastProgressTime!).inMilliseconds / 1000.0;
      final bytesDiff = _downloadedBytes - _lastDownloadedBytes;
      final currentSpeed = (bytesDiff / timeDiff).round();
      
      // Keep last 5 speed samples for smoothing
      _speedSamples.add(currentSpeed);
      if (_speedSamples.length > 5) {
        _speedSamples.removeAt(0);
      }
      
      _lastProgressTime = now;
      _lastDownloadedBytes = _downloadedBytes;
    }
    
    _emitProgress();
  }

  /// Emit progress event
  void _emitProgress({String? error}) {
    final percentage = _totalBytes > 0 ? (_downloadedBytes / _totalBytes) * 100 : 0.0;
    final averageSpeed = _speedSamples.isNotEmpty 
        ? _speedSamples.reduce((a, b) => a + b) ~/ _speedSamples.length 
        : 0;
    
    Duration estimatedTime = Duration.zero;
    if (averageSpeed > 0 && _totalBytes > _downloadedBytes) {
      final remainingBytes = _totalBytes - _downloadedBytes;
      estimatedTime = Duration(seconds: remainingBytes ~/ averageSpeed);
    }

    final progress = DownloadProgress(
      downloaded: _downloadedBytes,
      total: _totalBytes,
      percentage: percentage,
      speed: averageSpeed,
      estimatedTime: estimatedTime,
      status: _status,
      error: error,
    );

    if (!_progressController.isClosed) {
      _progressController.add(progress);
    }
  }

  /// Update download status
  void _updateStatus(DownloadStatus newStatus) {
    if (_status == newStatus) return;
    
    _status = newStatus;
    Logger.info("Status changed to: $newStatus", "DownloadManager");
    
    if (!_statusController.isClosed) {
      _statusController.add(newStatus);
    }
  }

  /// Get HTTP headers
  Map<String, String> _getHeaders() {
    final headers = <String, String>{
      'User-Agent': 'EnhancedDownloadManager/1.0',
    };
    
    if (authToken != null && authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }
    
    return headers;
  }

  /// Save download progress to disk
  void _saveProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('${filename}_downloaded', _downloadedBytes);
      await prefs.setInt('${filename}_total', _totalBytes);
    } catch (e) {
      Logger.warning("Failed to save progress: $e", "DownloadManager");
    }
  }

  /// Load saved progress from disk
  // ignore: unused_element
  Future<void> _loadProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _downloadedBytes = prefs.getInt('${filename}_downloaded') ?? 0;
      _totalBytes = prefs.getInt('${filename}_total') ?? 0;
    } catch (e) {
      Logger.warning("Failed to load progress: $e", "DownloadManager");
    }
  }

  /// Clear saved progress
  Future<void> _clearSavedProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('${filename}_downloaded');
      await prefs.remove('${filename}_total');
    } catch (e) {
      Logger.warning("Failed to clear progress: $e", "DownloadManager");
    }
  }

  /// Cleanup download resources
  Future<void> _cleanupDownload() async {
    _client?.close();
    _client = null;
    
    await _downloadSubscription?.cancel();
    _downloadSubscription = null;
    
    await _fileSink?.close();
    _fileSink = null;
  }

  /// Dispose all resources
  Future<void> dispose() async {
    await cancelDownload();
    
    if (!_progressController.isClosed) {
      await _progressController.close();
    }
    
    if (!_statusController.isClosed) {
      await _statusController.close();
    }
  }
}