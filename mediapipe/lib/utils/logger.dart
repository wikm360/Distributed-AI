// utils/logger.dart - Enhanced logging utility
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, success, error }

/// Enhanced logger utility with better formatting and categorization
class Logger {
  static LogLevel _currentLevel = kDebugMode ? LogLevel.debug : LogLevel.info;
  static bool _showTimestamp = true;
  static bool _showCategory = true;
  
  /// Set minimum log level
  static void setLevel(LogLevel level) {
    _currentLevel = level;
  }
  
  /// Configure logger display options
  static void configure({bool? showTimestamp, bool? showCategory}) {
    _showTimestamp = showTimestamp ?? _showTimestamp;
    _showCategory = showCategory ?? _showCategory;
  }

  /// Log debug message
  static void debug(String message, [String? category]) {
    _log(LogLevel.debug, message, category, '🔍');
  }

  /// Log info message
  static void info(String message, [String? category]) {
    _log(LogLevel.info, message, category, 'ℹ️');
  }

  /// Log warning message
  static void warning(String message, [String? category]) {
    _log(LogLevel.warning, message, category, '⚠️');
  }

  /// Log success message
  static void success(String message, [String? category]) {
    _log(LogLevel.success, message, category, '✅');
  }

  /// Log error message
  static void error(String message, [String? category, Object? error]) {
    _log(LogLevel.error, message, category, '❌', error);
  }

  static void _log(LogLevel level, String message, String? category, String emoji, [Object? error]) {
    // Check if we should log this level
    if (level.index < _currentLevel.index) return;

    final timestamp = _showTimestamp ? '[${DateTime.now().toIso8601String().substring(11, 23)}] ' : '';
    final categoryText = _showCategory && category != null ? '[$category] ' : '';
    final logMessage = '$timestamp$emoji $categoryText$message';

    // Use appropriate logging method based on level
    switch (level) {
      case LogLevel.debug:
        developer.log(logMessage, name: category ?? 'Debug');
        break;
      case LogLevel.info:
        developer.log(logMessage, name: category ?? 'Info');
        break;
      case LogLevel.warning:
        developer.log(logMessage, name: category ?? 'Warning', level: 900);
        break;
      case LogLevel.success:
        developer.log(logMessage, name: category ?? 'Success', level: 800);
        break;
      case LogLevel.error:
        developer.log(
          logMessage, 
          name: category ?? 'Error', 
          level: 1000,
          error: error,
          stackTrace: error != null ? StackTrace.current : null,
        );
        break;
    }

    // Also print to console in debug mode
    if (kDebugMode) {
      if (error != null) {
        print('$logMessage\nError: $error');
      } else {
        print(logMessage);
      }
    }
  }

  /// Log a separator line for better readability
  static void separator([String? category]) {
    _log(LogLevel.info, '═' * 50, category, '');
  }

  /// Log structured data
  static void data(Map<String, dynamic> data, [String? category]) {
    final buffer = StringBuffer('Structured data:\n');
    data.forEach((key, value) {
      buffer.writeln('  $key: $value');
    });
    _log(LogLevel.info, buffer.toString().trim(), category, '📊');
  }

  /// Log performance measurement
  static void performance(String operation, Duration duration, [String? category]) {
    final ms = duration.inMilliseconds;
    final emoji = ms < 100 ? '🚀' : ms < 500 ? '⏱️' : '🐌';
    _log(LogLevel.info, '$operation completed in ${ms}ms', category, emoji);
  }

  /// Create a timer for performance logging
  static LogTimer startTimer(String operation, [String? category]) {
    return LogTimer._(operation, category);
  }
}

/// Timer utility for performance logging
class LogTimer {
  final String _operation;
  final String? _category;
  final DateTime _startTime;

  LogTimer._(this._operation, this._category) : _startTime = DateTime.now();

  /// Stop timer and log duration
  void stop() {
    final duration = DateTime.now().difference(_startTime);
    Logger.performance(_operation, duration, _category);
  }
}