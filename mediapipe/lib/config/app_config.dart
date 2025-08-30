// config/app_config.dart - نسخه تصحیح شده
import 'package:flutter/material.dart';

/// تنظیمات کلی اپلیکیشن
class AppConfig {
  // Server Configuration
  static const String defaultRoutingServerUrl = "http://85.133.228.31:8313";
  static const Duration defaultPollingInterval = Duration(seconds: 3);
  static const Duration maxWorkerWaitTime = Duration(seconds: 25);
  
  // UI Configuration
  static const Color primaryColor = Colors.blue;
  static const Color backgroundColor = Color(0xFF121212);
  static const Color cardColor = Color(0xFF1E1E1E);
  static const Color surfaceColor = Color(0xFF2D2D2D);
  
  // Performance Configuration
  static const int maxTokenBuffer = 256;
  static const int defaultMaxTokens = 1024;
  static const double defaultTemperature = 1.0;
  static const int defaultTopK = 64;
  static const double defaultTopP = 0.95;
  
  // Timeouts
  static const Duration networkTimeout = Duration(seconds: 10);
  static const Duration generationTimeout = Duration(seconds: 60);
  static const Duration distributedGenerationTimeout = Duration(seconds: 90);
  
  // Debug
  static const bool enableDebugLogs = true;
  static const bool enableWorkerLogs = true;
  
  /// Get server URL from environment or use default
  static String get routingServerUrl {
    // In a real app, you might get this from environment variables
    // const String.fromEnvironment('ROUTING_SERVER_URL', defaultValue: defaultRoutingServerUrl);
    return defaultRoutingServerUrl;
  }
  
  /// Check if debug mode is enabled
  static bool get isDebugMode {
    return enableDebugLogs;
  }
}
