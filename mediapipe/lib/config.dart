// config.dart - تمام تنظیمات برنامه
import 'package:flutter/material.dart';

class AppConfig {
  // Server Configuration
  static const String routingServerUrl = "http://85.133.228.31:8313";
  static const String labsEndpoint = "https://example.com/api/labs";
  static const Duration pollingInterval = Duration(seconds: 3);
  static const Duration maxWaitTime = Duration(seconds: 30);

  // UI Colors
  static const Color primaryColor = Colors.blue;
  static const Color bgDark = Color(0xFF121212);
  static const Color cardDark = Color(0xFF1E1E1E);
  static const Color surfaceDark = Color(0xFF2D2D2D);

  // AI Settings
  static const int defaultMaxTokens = 1024;
  static const double defaultTemperature = 1.0;
  static const int defaultTopK = 64;
  static const double defaultTopP = 0.95;

  // Timeouts
  static const Duration networkTimeout = Duration(seconds: 10);
  static const Duration generationTimeout = Duration(seconds: 60);

  // Debug
  static const bool enableLogs = true;
}
