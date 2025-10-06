// download/model_store.dart - مدیریت مدل‌ها با API جدید
// import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma_interface.dart';
import 'package:flutter_gemma/mobile/flutter_gemma_mobile.dart' hide DownloadProgress;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import '../shared/models.dart';
import '../shared/logger.dart';

class ModelStore {
  // Singleton pattern
  static final ModelStore _instance = ModelStore._internal();
  factory ModelStore() => _instance;
  ModelStore._internal();

  final _manager = FlutterGemmaPlugin.instance.modelManager;

  /// Load token for specific model
  Future<String?> loadToken(String modelName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('token_$modelName');
    } catch (e) {
      Log.e('Failed to load token', 'ModelStore', e);
      return null;
    }
  }

  /// Save token for specific model
  Future<void> saveToken(String modelName, String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token_$modelName', token);
    } catch (e) {
      Log.e('Failed to save token', 'ModelStore', e);
      rethrow;
    }
  }

  /// Get corrected file path (Android fix)
  Future<String> getFilePath(String filename) async {
    final directory = await getApplicationDocumentsDirectory();
    // Android path correction
    final correctedPath = directory.path.contains('/data/user/0/')
        ? directory.path.replaceFirst('/data/user/0/', '/data/data/')
        : directory.path;
    return '$correctedPath/$filename';
  }

  /// Check if model is installed using new API
  Future<bool> isModelDownloaded(AIModel model, [String? token]) async {
    try {
      // Create model spec
      final spec = MobileModelManager.createInferenceSpec(
        name: model.filename,
        modelUrl: model.url,
      );

      // Check via new API
      final isInstalled = await _manager.isModelInstalled(spec);
      
      if (isInstalled) {
        Log.i('Model ${model.name} is installed', 'ModelStore');
        return true;
      }

      // Fallback: Physical file check with size validation
      final filePath = await getFilePath(model.filename);
      final file = File(filePath);
      
      if (!file.existsSync()) return false;

      // Verify file size matches remote
      final headers = <String, String>{};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final headResponse = await http.head(
        Uri.parse(model.url),
        headers: headers,
      );

      if (headResponse.statusCode == 200) {
        final contentLength = headResponse.headers['content-length'];
        if (contentLength != null) {
          final remoteSize = int.parse(contentLength);
          final localSize = await file.length();
          final isValid = localSize == remoteSize;
          
          Log.i(
            'Model ${model.name}: local=$localSize, remote=$remoteSize, valid=$isValid',
            'ModelStore',
          );
          
          return isValid;
        }
      }

      return false;
    } catch (e) {
      Log.e('Error checking model ${model.name}', 'ModelStore', e);
      return false;
    }
  }

  /// Download model with progress using new API
  Stream<DownloadProgress> downloadModel(AIModel model, String? token) async* {
    try {
      Log.i('Starting download for ${model.name}', 'ModelStore');
      
      // Create model spec
      final spec = MobileModelManager.createInferenceSpec(
        name: model.filename,
        modelUrl: model.url,
      );

      // Get download stream
      final stream = _manager.downloadModelWithProgress(
        spec,
        token: token ?? '',
      );

      int lastEmittedProgress = -1;

      await for (final progress in stream) {
        final currentProgress = progress.overallProgress.toInt();
        
        // Only emit when progress changes significantly
        if (currentProgress != lastEmittedProgress) {
          lastEmittedProgress = currentProgress;
          
          yield DownloadProgress(
            downloadedBytes: 0, // Not provided by new API
            totalBytes: 0, // Not provided by new API
            percentage: progress.overallProgress.toDouble(),
            speedBps: 0, // New API doesn't provide speed
            status: progress.overallProgress >= 100 
                ? DownloadStatus.completed 
                : DownloadStatus.downloading,
          );
        }
      }

      Log.s('Download completed for ${model.name}', 'ModelStore');
    } catch (e) {
      Log.e('Download failed for ${model.name}', 'ModelStore', e);
      yield DownloadProgress(
        downloadedBytes: 0,
        totalBytes: 0,
        percentage: 0,
        speedBps: 0,
        status: DownloadStatus.error,
        error: e.toString(),
      );
    }
  }

  /// Delete model
  Future<void> deleteModel(AIModel model) async {
    try {
      final filePath = await getFilePath(model.filename);
      final file = File(filePath);
      
      if (file.existsSync()) {
        await file.delete();
        Log.s('Model ${model.name} deleted', 'ModelStore');
      }
    } catch (e) {
      Log.e('Failed to delete model ${model.name}', 'ModelStore', e);
      rethrow;
    }
  }
}