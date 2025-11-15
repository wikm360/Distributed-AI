// shared/logger.dart - لاگر ساده
import 'dart:developer' as dev;
import '../config.dart';

class Log {
  static void i(String msg, [String? tag]) {
    if (!AppConfig.enableLogs) return;
    dev.log('ℹ️ $msg', name: tag ?? 'Info');
  }

  static void s(String msg, [String? tag]) {
    if (!AppConfig.enableLogs) return;
    dev.log('✅ $msg', name: tag ?? 'Success');
  }

  static void w(String msg, [String? tag]) {
    if (!AppConfig.enableLogs) return;
    dev.log('⚠️ $msg', name: tag ?? 'Warning', level: 900);
  }

  static void e(String msg, [String? tag, Object? error]) {
    if (!AppConfig.enableLogs) return;
    dev.log('❌ $msg', name: tag ?? 'Error', error: error, level: 1000);
  }
}