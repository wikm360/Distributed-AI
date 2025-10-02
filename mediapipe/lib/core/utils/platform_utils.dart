// core/utils/platform_utils.dart - Updated version
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Utilities برای تشخیص پلتفرم و قابلیت‌ها
class PlatformUtils {
  /// آیا در حال اجرا روی موبایل هستیم؟
  static bool get isMobile {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// آیا در حال اجرا روی دسکتاپ هستیم؟
  static bool get isDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  /// آیا در حال اجرا روی وب هستیم؟
  static bool get isWeb => kIsWeb;

  /// نام پلتفرم فعلی
  static String get platformName {
    if (kIsWeb) return 'Web';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }

  /// آیا پلتفرم فعلی از backend مشخص پشتیبانی می‌کند؟
  static bool supportsBackend(String backendName) {
    final name = backendName.toLowerCase();
    
    // Gemma backends - Mobile and Web
    if (name.contains('gemma') || name.contains('flutter')) {
      return isMobile || isWeb;
    }
    
    // LlamaCpp backends - Desktop only
    if (name.contains('llama') || name.contains('cpp')) {
      return isDesktop;
    }
    
    return false;
  }

  /// دریافت پسوند مناسب فایل کتابخانه برای پلتفرم فعلی
  static String get libraryExtension {
    if (kIsWeb) return '.js';
    if (Platform.isWindows) return '.dll';
    if (Platform.isMacOS) return '.dylib';
    if (Platform.isLinux) return '.so';
    return '.so'; // fallback
  }

  /// دریافت مسیر پیش‌فرض برای کتابخانه‌های native
  static String get defaultLibraryPath {
    if (kIsWeb) return '';
    
    final extension = libraryExtension;
    
    if (Platform.isWindows) {
      return './llama.dll';
    } else if (Platform.isMacOS) {
      return './libllama.dylib';
    } else if (Platform.isLinux) {
      return './libllama.so';
    }
    
    return './libllama$extension';
  }

  /// بررسی در دسترس بودن قابلیت‌های GPU
  static bool get hasGpuSupport {
    // Mobile devices typically have GPU
    if (isMobile) return true;
    
    // Desktop GPU support depends on hardware
    // This would need more sophisticated detection
    if (isDesktop) return true;
    
    // Web has limited GPU access
    if (isWeb) return false;
    
    return false;
  }

  /// بررسی در دسترس بودن multi-threading
  static bool get hasMultiThreadingSupport {
    // Desktop has full multi-threading support
    if (isDesktop) return true;
    
    // Mobile has limited multi-threading
    if (isMobile) return true;
    
    // Web has limited multi-threading (Web Workers)
    if (isWeb) return false;
    
    return false;
  }

  /// تعداد پیشنهادی thread ها برای پلتفرم فعلی
  static int get recommendedThreadCount {
    if (isDesktop) {
      // Desktop can handle more threads
      return 8;
    } else if (isMobile) {
      // Mobile should be more conservative
      return 4;
    } else {
      // Web - single threaded
      return 1;
    }
  }

  /// حداکثر حافظه پیشنهادی برای context (بر حسب MB)
  static int get recommendedContextSize {
    if (isDesktop) {
      // Desktop can handle larger contexts
      return 4096;
    } else if (isMobile) {
      // Mobile should be more conservative
      return 2048;
    } else if (isWeb) {
      // Web has memory limitations
      return 1024;
    }
    
    return 2048; // fallback
  }

  /// آیا پلتفرم از دانلود فایل‌های بزرگ پشتیبانی می‌کند؟
  static bool get supportsLargeFileDownload {
    // Desktop has no major limitations
    if (isDesktop) return true;
    
    // Mobile might have storage limitations
    if (isMobile) return true;
    
    // Web has significant limitations
    if (isWeb) return false;
    
    return true;
  }

  /// حداکثر اندازه فایل مدل پیشنهادی (بر حسب GB)
  static double get maxRecommendedModelSize {
    if (isDesktop) {
      return 50.0; // Desktop can handle very large models
    } else if (isMobile) {
      return 10.0; // Mobile should be more conservative
    } else if (isWeb) {
      return 2.0; // Web has strict limitations
    }
    
    return 5.0; // fallback
  }

  /// آیا پلتفرم از background processing پشتیبانی می‌کند؟
  static bool get supportsBackgroundProcessing {
    // Desktop has full background processing
    if (isDesktop) return true;
    
    // Mobile has limited background processing
    if (isMobile) return true;
    
    // Web has very limited background processing
    if (isWeb) return false;
    
    return false;
  }

  /// تنظیمات بهینه برای backend بر اساس پلتفرم
  static Map<String, dynamic> getOptimalBackendConfig(String backendName) {
    final name = backendName.toLowerCase();
    
    if (name.contains('llama') && isDesktop) {
      return {
        'nCtx': recommendedContextSize,
        'nBatch': 512,
        'nThreads': recommendedThreadCount,
        'nPredict': 256,
        'temperature': 0.6,
        'topP': 0.9,
        'topK': 50,
        'libraryPath': defaultLibraryPath,
      };
    }
    
    if (name.contains('gemma') && (isMobile || isWeb)) {
      return {
        'maxTokens': recommendedContextSize,
        'temperature': 0.7,
        'topK': 40,
        'topP': 0.95,
        'preferredBackend': hasGpuSupport ? 'gpu' : 'cpu',
      };
    }
    
    // Default configuration
    return {
      'temperature': 0.7,
      'topK': 50,
      'topP': 0.9,
    };
  }

  /// Debug info برای پلتفرم فعلی
  static Map<String, dynamic> get debugInfo => {
    'platform_name': platformName,
    'is_mobile': isMobile,
    'is_desktop': isDesktop,
    'is_web': isWeb,
    'library_extension': libraryExtension,
    'default_library_path': defaultLibraryPath,
    'has_gpu_support': hasGpuSupport,
    'has_multithreading': hasMultiThreadingSupport,
    'recommended_threads': recommendedThreadCount,
    'recommended_context_size': recommendedContextSize,
    'supports_large_files': supportsLargeFileDownload,
    'max_model_size_gb': maxRecommendedModelSize,
    'supports_background': supportsBackgroundProcessing,
  };
}