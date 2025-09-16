// core/services/backend_factory.dart - Updated version
import '../interfaces/base_ai_backend.dart';
import '../utils/platform_utils.dart';
import '../../backends/gemma/gemma_backend.dart';
import '../../backends/llama_cpp/llama_cpp_backend.dart';

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
      return LlamaCppBackend();
    } else {
      throw UnsupportedError('Unsupported platform: ${PlatformUtils.platformName}');
    }
  }
  
  /// ایجاد backend با نام مشخص
  static BaseAIBackend? createBackend(String name) {
    final factory = _factories[name.toLowerCase()];
    return factory?.call();
  }
  
  /// ایجاد LlamaCpp backend با تنظیمات مشخص
  static LlamaCppBackend createLlamaCppBackend({
    required String libraryPath,
    Map<String, dynamic>? config,
  }) {
    final backend = LlamaCppBackend();
    // Pre-configure for LlamaCpp specific needs
    return backend;
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
    // Clear existing factories
    _factories.clear();
    
    // Register mobile/web backends
    if (PlatformUtils.isMobile || PlatformUtils.isWeb) {
      registerBackend('gemma', () => GemmaBackend());
      registerBackend('flutter_gemma', () => GemmaBackend());
    }
    
    // Register desktop backends
    if (PlatformUtils.isDesktop) {
      registerBackend('llamacpp', () => LlamaCppBackend());
      registerBackend('llama_cpp', () => LlamaCppBackend());
      registerBackend('llama-cpp', () => LlamaCppBackend());
    }
    
    // Register universal backends (available on all platforms)
    // Add here if you have backends that work on all platforms
  }
  
  /// Check if a specific backend is supported on current platform
  static bool isBackendSupported(String backendName) {
    final name = backendName.toLowerCase();
    
    if (name.contains('gemma') || name.contains('flutter')) {
      return PlatformUtils.isMobile || PlatformUtils.isWeb;
    }
    
    if (name.contains('llama') || name.contains('cpp')) {
      return PlatformUtils.isDesktop;
    }
    
    return false;
  }
  
  /// Get recommended backend for current platform
  static String getRecommendedBackend() {
    if (PlatformUtils.isMobile || PlatformUtils.isWeb) {
      return 'gemma';
    } else if (PlatformUtils.isDesktop) {
      return 'llamacpp';
    } else {
      return 'gemma'; // fallback
    }
  }
  
  /// Get backend info
  static Map<String, dynamic> getBackendInfo(String backendName) {
    final name = backendName.toLowerCase();
    
    if (name.contains('gemma')) {
      return {
        'name': 'Flutter Gemma',
        'platforms': ['Android', 'iOS', 'Web'],
        'description': 'Optimized for mobile devices with GPU acceleration',
        'features': ['GPU Support', 'Multimodal', 'Function Calls'],
      };
    }
    
    if (name.contains('llama')) {
      return {
        'name': 'LlamaCpp',
        'platforms': ['Windows', 'macOS', 'Linux'],
        'description': 'High-performance CPU inference for desktop',
        'features': ['Multi-threading', 'Large Models', 'Custom Formats'],
      };
    }
    
    return {
      'name': 'Unknown',
      'platforms': [],
      'description': 'Unknown backend',
      'features': [],
    };
  }
}