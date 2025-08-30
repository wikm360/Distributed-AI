// core/services/backend_factory.dart
import '../interfaces/base_ai_backend.dart';
// ignore: unused_import
import '../models/backend_config.dart';
import '../utils/platform_utils.dart';
import '../../backends/gemma/gemma_backend.dart';
// import '../../backends/llama_cpp/llama_cpp_backend.dart'; // بعداً اضافه می‌شود

/// Factory برای ایجاد backend مناسب
class BackendFactory {
  static final Map<String, BaseAIBackend Function()> _factories = {};
  
  /// ثبت factory برای backend
  static void registerBackend(String name, BaseAIBackend Function() factory) {
    _factories[name.toLowerCase()] = factory;
  }
  
  /// ایجاد backend مناسب بر اساس پلتفرم
  static BaseAIBackend createDefaultBackend() {
    if (PlatformUtils.isMobile || PlatformUtils.isWeb) {
      return GemmaBackend();
    } else if (PlatformUtils.isDesktop) {
      // return LlamaCppBackend(); // بعداً اضافه می‌شود
      throw UnsupportedError('Desktop backends not implemented yet');
    } else {
      throw UnsupportedError('Unsupported platform: ${PlatformUtils.platformName}');
    }
  }
  
  /// ایجاد backend با نام مشخص
  static BaseAIBackend? createBackend(String name) {
    final factory = _factories[name.toLowerCase()];
    return factory?.call();
  }
  
  /// لیست backend های موجود
  static List<String> get availableBackends {
    return _factories.keys.toList();
  }
  
  /// لیست backend های پشتیبانی شده در پلتفرم فعلی
  static List<String> get supportedBackends {
    return _factories.keys
        .where((name) => PlatformUtils.supportsBackend(name))
        .toList();
  }
  
  /// مقداردهی اولیه factory ها
  static void initialize() {
    // ثبت backend های موجود
    if (PlatformUtils.isMobile || PlatformUtils.isWeb) {
      registerBackend('gemma', () => GemmaBackend());
      registerBackend('flutter_gemma', () => GemmaBackend());
    }
    
    // if (PlatformUtils.isDesktop) {
    //   registerBackend('llamacpp', () => LlamaCppBackend());
    //   registerBackend('llama_cpp', () => LlamaCppBackend());
    // }
  }
}
