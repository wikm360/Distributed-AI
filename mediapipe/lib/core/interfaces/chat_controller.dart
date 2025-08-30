// core/interfaces/chat_controller.dart
import 'base_ai_backend.dart';

/// Controller برای مدیریت چت
abstract class ChatController {
  /// پیام‌های چت
  List<ChatMessage> get messages;
  
  /// آیا در حال تولید پاسخ است؟
  bool get isGenerating;
  
  /// Backend فعلی
  BaseAIBackend? get currentBackend;
  
  /// Stream تغییرات state
  Stream<ChatState> get stateStream;

  /// ارسال پیام
  Future<void> sendMessage(String message);

  /// متوقف کردن تولید فعلی
  Future<void> stopGeneration();

  /// پاک کردن تاریخچه چت
  Future<void> clearHistory();

  /// تنظیم backend
  Future<void> setBackend(BaseAIBackend backend);

  /// dispose controller
  Future<void> dispose();
}

/// پیام چت
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<int>? imageBytes;
  final Map<String, dynamic> metadata;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.imageBytes,
    this.metadata = const {},
  }) : timestamp = timestamp ?? DateTime.now();

  bool get hasImage => imageBytes != null && imageBytes!.isNotEmpty;

  ChatMessage copyWith({
    String? text,
    bool? isUser,
    DateTime? timestamp,
    List<int>? imageBytes,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessage(
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      imageBytes: imageBytes ?? this.imageBytes,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// وضعیت چت
class ChatState {
  final List<ChatMessage> messages;
  final bool isGenerating;
  final String? error;
  final BaseAIBackend? backend;

  ChatState({
    required this.messages,
    this.isGenerating = false,
    this.error,
    this.backend,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isGenerating,
    String? error,
    BaseAIBackend? backend,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isGenerating: isGenerating ?? this.isGenerating,
      error: error,
      backend: backend ?? this.backend,
    );
  }
}