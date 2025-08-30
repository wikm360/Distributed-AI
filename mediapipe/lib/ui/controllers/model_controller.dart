// ui/controllers/model_controller.dart - نسخه تصحیح شده
// برای ModelType
import '../../core/interfaces/base_ai_backend.dart';
import '../../core/services/backend_factory.dart';
import '../../core/models/backend_config.dart';
import '../../models/model.dart';
import '../../utils/logger.dart';
import 'package:flutter_gemma/core/model.dart';

/// Controller برای مدیریت model ها
class ModelController {
  BaseAIBackend? _currentBackend;
  Model? _currentModel;
  bool _isInitializing = false;
  
  BaseAIBackend? get currentBackend => _currentBackend;
  Model? get currentModel => _currentModel;
  bool get isInitializing => _isInitializing;
  bool get hasModel => _currentBackend?.isInitialized ?? false;

  /// بارگذاری مدل
  Future<void> loadModel(Model model, {String? customBackendName}) async {
    if (_isInitializing) {
      throw StateError('Model initialization already in progress');
    }

    _isInitializing = true;
    
    try {
      Logger.info("Loading model: ${model.displayName}", "ModelController");
      
      // dispose current backend if exists
      if (_currentBackend != null) {
        await _currentBackend!.dispose();
        _currentBackend = null;
      }
      
      // Create backend
      _currentBackend = customBackendName != null 
          ? BackendFactory.createBackend(customBackendName)
          : BackendFactory.createDefaultBackend();
          
      if (_currentBackend == null) {
        throw Exception('Failed to create backend');
      }
      
      // Prepare configuration
      final config = BackendConfig.fromModel(model);
      final configMap = _backendConfigToMap(config);
      
      // Initialize backend
      await _currentBackend!.initialize(
        modelPath: model.url,
        config: configMap,
      );
      
      _currentModel = model;
      
      Logger.success("Model loaded successfully: ${model.displayName}", "ModelController");
    } catch (e) {
      Logger.error("Failed to load model", "ModelController", e);
      
      // Cleanup on failure
      if (_currentBackend != null) {
        await _currentBackend!.dispose();
        _currentBackend = null;
      }
      _currentModel = null;
      
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  /// تغییر مدل
  Future<void> switchModel(Model newModel) async {
    Logger.info("Switching to model: ${newModel.displayName}", "ModelController");
    await loadModel(newModel);
  }

/// بررسی سلامت مدل فعلی
Future<bool> healthCheck() async {
  if (_currentBackend == null) {
    Logger.info("Health check failed: no backend", "ModelController");
    return false;
  }
  
  try {
    final isHealthy = await _currentBackend!.healthCheck();
    Logger.info("Model health check result: $isHealthy", "ModelController");
    return isHealthy;
  } catch (e) {
    Logger.error("Health check error", "ModelController", e);
    return false;
  }
}

  /// لیست backend های موجود
  List<String> getAvailableBackends() {
    return BackendFactory.supportedBackends;
  }

  /// dispose controller
  Future<void> dispose() async {
    _isInitializing = false;
    
    if (_currentBackend != null) {
      await _currentBackend!.dispose();
      _currentBackend = null;
    }
    
    _currentModel = null;
  }

  /// تبدیل BackendConfig به Map
  Map<String, dynamic> _backendConfigToMap(BackendConfig config) {
    return {
      'modelType': _getModelTypeForModel(config),
      'preferredBackend': config.preferredBackend,
      'maxTokens': config.maxTokens,
      'supportImage': config.supportImage,
      'maxNumImages': config.customParams['maxNumImages'] ?? 1,
      'temperature': config.temperature,
      'randomSeed': DateTime.now().millisecondsSinceEpoch,
      'topK': config.topK,
      'topP': config.topP,
      'tokenBuffer': 256,
      'supportsFunctionCalls': config.supportsFunctionCalls,
      'tools': [],
      'isThinking': config.isThinking,
      ...config.customParams,
    };
  }

  /// تعیین ModelType بر اساس model
  ModelType _getModelTypeForModel(BackendConfig config) {
    // بر اساس نام مدل یا سایر ویژگی ها ModelType را تعیین کنیم
    if (_currentModel?.displayName.toLowerCase().contains('deepseek') == true) {
      return ModelType.deepSeek;
    }
    return ModelType.gemmaIt; // پیش فرض
  }
  }