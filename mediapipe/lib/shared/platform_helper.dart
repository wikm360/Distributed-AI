// shared/platform_helper.dart - کمک‌های پلتفرم
import 'dart:io';
import 'package:flutter/foundation.dart';

class PlatformHelper {
  static bool get isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  static bool get isDesktop => !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
  static bool get isWeb => kIsWeb;
  
  static String get name {
    if (kIsWeb) return 'Web';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }

  static bool supportsGemma() => isMobile || isWeb;
  static bool supportsLlama() => isDesktop;
}