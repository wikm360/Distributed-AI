// core/interfaces/base_ai_backend.dart
import 'dart:async';
// ignore: unused_import
import 'package:flutter_gemma/pigeon.g.dart';

/// Base interface برای تمام AI backends
abstract class BaseAIBackend {
  /// نام backend (مثل "Flutter Gemma" یا "LlamaCpp")
  String get backendName;
  
  /// آیا backend آماده استفاده است؟
  bool get isInitialized;
  
  /// آیا در حال تولید پاسخ است؟
  bool get isGenerating;
  
  /// پلتفرم‌های پشتیبانی شده
  List<String> get supportedPlatforms;
  
  /// مدل فعلی
  String? get currentModel;

  /// مقداردهی اولیه backend
  Future<void> initialize({
    required String modelPath,
    required Map<String, dynamic> config,
  });

  /// تولید پاسخ به صورت یکجا
  Future<String> generateResponse(String prompt);

  /// تولید پاسخ به صورت stream (برای streaming)
  Stream<String> generateResponseStream(String prompt);

  /// متوقف کردن تولید فعلی
  Future<void> stopGeneration();

  /// پاک کردن تاریخچه چت
  Future<void> clearHistory();

  /// اضافه کردن پیام به تاریخچه
  Future<void> addMessage(String message, bool isUser);

  /// بستن backend و آزادسازی resources
  Future<void> dispose();

  /// بررسی سلامت backend
  Future<bool> healthCheck();
}







