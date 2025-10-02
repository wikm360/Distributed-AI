// download/download_manager.dart - مدیریت دانلود فایل‌ها
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../shared/models.dart';
import '../shared/logger.dart';

class DownloadManager {
  final String url;
  final String filename;
  final String? authToken;
  
  DownloadStatus _status = DownloadStatus.idle;
  http.Client? _client;
  IOSink? _sink;
  File? _targetFile;
  File? _tempFile;
  
  int _downloadedBytes = 0;
  int _totalBytes = 0;
  DateTime? _startTime;
  int _lastDownloadedBytes = 0;
  DateTime? _lastProgressTime;
  final List<int> _speedSamples = [];
  
  final StreamController<DownloadProgress> _progressController = 
      StreamController<DownloadProgress>.broadcast();

  DownloadManager(this.url, this.filename, {this.authToken});

  DownloadStatus get status => _status;
  Stream<DownloadProgress> get progressStream => _progressController.stream;
  double get progress => _totalBytes > 0 ? _downloadedBytes / _totalBytes : 0.0;

  Future<String> getFilePath() async {
    await _initFiles();
    return _targetFile!.path;
  }

  Future<bool> isFileComplete() async {
    await _initFiles();
    if (!_targetFile!.existsSync()) return false;

    try {
      final response = await http.head(Uri.parse(url), headers: _getHeaders());
      if (response.statusCode == 200) {
        final remoteSize = int.tryParse(response.headers['content-length'] ?? '0') ?? 0;
        final localSize = await _targetFile!.length();
        return localSize == remoteSize && remoteSize > 0;
      }
    } catch (e) {
      Log.w('Could not verify file', 'DownloadManager');
    }
    
    return false;
  }

  Future<void> start() async {
    if (_status == DownloadStatus.downloading) return;

    try {
      _status = DownloadStatus.downloading;
      await _initFiles();
      
      if (_tempFile!.existsSync()) {
        _downloadedBytes = await _tempFile!.length();
      } else {
        _downloadedBytes = 0;
      }

      await _download();
    } catch (e) {
      Log.e('Download failed', 'DownloadManager', e);
      _status = DownloadStatus.error;
      _emitProgress(error: e.toString());
    }
  }

  Future<void> pause() async {
    if (_status != DownloadStatus.downloading) return;
    await _cleanup();
    _status = DownloadStatus.paused;
  }

  Future<void> cancel() async {
    await _cleanup();
    if (_tempFile?.existsSync() == true) {
      await _tempFile!.delete();
    }
    _status = DownloadStatus.idle;
    _downloadedBytes = 0;
  }

  Future<void> delete() async {
    await cancel();
    if (_targetFile?.existsSync() == true) {
      await _targetFile!.delete();
    }
  }

  Future<void> _initFiles() async {
    if (_targetFile != null) return;
    
    final directory = await getApplicationDocumentsDirectory();
    _targetFile = File('${directory.path}/$filename');
    _tempFile = File('${directory.path}/$filename.tmp');
  }

  Future<void> _download() async {
    _client = http.Client();
    _startTime = DateTime.now();
    _lastProgressTime = _startTime;
    _lastDownloadedBytes = _downloadedBytes;

    final request = http.Request('GET', Uri.parse(url));
    request.headers.addAll(_getHeaders());
    
    if (_downloadedBytes > 0) {
      request.headers['Range'] = 'bytes=$_downloadedBytes-';
    }

    final streamedResponse = await _client!.send(request);
    
    if (streamedResponse.statusCode != 200 && streamedResponse.statusCode != 206) {
      throw Exception('HTTP ${streamedResponse.statusCode}');
    }

    _totalBytes = _downloadedBytes + (streamedResponse.contentLength ?? 0);
    if (streamedResponse.statusCode == 200) {
      _totalBytes = streamedResponse.contentLength ?? 0;
      _downloadedBytes = 0;
      if (_tempFile!.existsSync()) await _tempFile!.delete();
    }

    _sink = _tempFile!.openWrite(mode: FileMode.append);

    streamedResponse.stream.listen(
      (data) {
        _sink!.add(data);
        _downloadedBytes += data.length;
        _updateProgress();
      },
      onDone: () async {
        await _sink!.close();
        if (_status == DownloadStatus.downloading) {
          await _tempFile!.rename(_targetFile!.path);
          _status = DownloadStatus.completed;
          _emitProgress();
        }
        await _cleanup();
      },
      onError: (e) async {
        await _cleanup();
        _status = DownloadStatus.error;
        _emitProgress(error: e.toString());
      },
      cancelOnError: true,
    );
  }

  void _updateProgress() {
    final now = DateTime.now();
    
    if (_lastProgressTime != null && 
        now.difference(_lastProgressTime!).inMilliseconds >= 1000) {
      
      final timeDiff = now.difference(_lastProgressTime!).inMilliseconds / 1000.0;
      final bytesDiff = _downloadedBytes - _lastDownloadedBytes;
      final currentSpeed = (bytesDiff / timeDiff).round();
      
      _speedSamples.add(currentSpeed);
      if (_speedSamples.length > 5) _speedSamples.removeAt(0);
      
      _lastProgressTime = now;
      _lastDownloadedBytes = _downloadedBytes;
    }
    
    _emitProgress();
  }

  void _emitProgress({String? error}) {
    final percentage = _totalBytes > 0 ? (_downloadedBytes / _totalBytes) * 100 : 0.0;
    final avgSpeed = _speedSamples.isNotEmpty 
        ? _speedSamples.reduce((a, b) => a + b) ~/ _speedSamples.length 
        : 0;

    final progress = DownloadProgress(
      downloadedBytes: _downloadedBytes,
      totalBytes: _totalBytes,
      percentage: percentage,
      speedBps: avgSpeed,
      status: _status,
      error: error,
    );

    if (!_progressController.isClosed) {
      _progressController.add(progress);
    }
  }

  Map<String, String> _getHeaders() {
    final headers = <String, String>{'User-Agent': 'DownloadManager/1.0'};
    if (authToken != null && authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }
    return headers;
  }

  Future<void> _cleanup() async {
    _client?.close();
    _client = null;
    await _sink?.close();
    _sink = null;
  }

  void dispose() {
    cancel();
    if (!_progressController.isClosed) {
      _progressController.close();
    }
  }
}