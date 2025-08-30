// core/utils/platform_utils.dart
import 'dart:io';
import 'package:flutter/foundation.dart';

/// ابزارهای platform detection
class PlatformUtils {
  static bool get isWeb => kIsWeb;
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isIOS => !kIsWeb && Platform.isIOS;
  static bool get isMobile => isAndroid || isIOS;
  static bool get isWindows => !kIsWeb && Platform.isWindows;
  static bool get isLinux => !kIsWeb && Platform.isLinux;
  static bool get isMacOS => !kIsWeb && Platform.isMacOS;
  static bool get isDesktop => isWindows || isLinux || isMacOS;

  static String get platformName {
    if (isWeb) return 'Web';
    if (isAndroid) return 'Android';
    if (isIOS) return 'iOS';
    if (isWindows) return 'Windows';
    if (isLinux) return 'Linux';
    if (isMacOS) return 'macOS';
    return 'Unknown';
  }

  /// آیا پلتفرم فعلی از backend خاص پشتیبانی می‌کند؟
  static bool supportsBackend(String backendName) {
    switch (backendName.toLowerCase()) {
      case 'gemma':
      case 'flutter_gemma':
        return isMobile || isWeb;
      case 'llamacpp':
      case 'llama_cpp':
        return isDesktop;
      default:
        return false;
    }
  }
}