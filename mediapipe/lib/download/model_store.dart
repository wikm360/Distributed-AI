// download/model_store.dart - ذخیره و مدیریت مدل‌ها
import 'package:shared_preferences/shared_preferences.dart';
import 'download_manager.dart';
import '../shared/models.dart';
import '../shared/logger.dart';

class ModelStore {
  Future<String?> loadToken(String modelName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('token_$modelName');
    } catch (e) {
      Log.e('Failed to load token', 'ModelStore', e);
      return null;
    }
  }

  Future<void> saveToken(String modelName, String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token_$modelName', token);
    } catch (e) {
      Log.e('Failed to save token', 'ModelStore', e);
      rethrow;
    }
  }

  Future<bool> isModelDownloaded(AIModel model, [String? token]) async {
    try {
      final manager = DownloadManager(model.url, model.filename, authToken: token);
      final exists = await manager.isFileComplete();
      manager.dispose();
      return exists;
    } catch (e) {
      return false;
    }
  }

  DownloadManager createDownloadManager(AIModel model, String? token) {
    return DownloadManager(
      model.url, 
      model.filename, 
      authToken: token,
    );
  }
}