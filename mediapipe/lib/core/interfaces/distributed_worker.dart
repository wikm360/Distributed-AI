// core/interfaces/distributed_worker.dart
import 'dart:async';
/// رویدادهای مختلف worker
enum WorkerEventType {
  started,
  stopped,
  paused,
  resumed,
  queryReceived,
  queryProcessed,
  responseSent,
  error,
  connectionLost,
  connectionRestored,
}

/// رویداد worker
class WorkerEvent {
  final WorkerEventType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final String? message;

  WorkerEvent({
    required this.type,
    this.data = const {},
    DateTime? timestamp,
    this.message,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    return 'WorkerEvent(type: $type, message: $message, timestamp: $timestamp)';
  }
}

/// Query که از سرور دریافت می‌شود
class DistributedQuery {
  final int queryNumber;
  final String query;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  DistributedQuery({
    required this.queryNumber,
    required this.query,
    DateTime? timestamp,
    this.metadata = const {},
  }) : timestamp = timestamp ?? DateTime.now();

  factory DistributedQuery.fromJson(Map<String, dynamic> json) {
    // Parse query_number به صورت safe
    
    print(json['query'].runtimeType);
    // ignore: unused_local_variable
    int queryNumber;
    final queryNumberRaw = json['query_number'];
    if (queryNumberRaw is int) {
      queryNumber = queryNumberRaw;
    } else if (queryNumberRaw is double) {
      queryNumber = queryNumberRaw.toInt();
    } else if (queryNumberRaw is String) {
      queryNumber = int.tryParse(queryNumberRaw) ?? 0;
    } else {
      queryNumber = 0;
    }

    print(queryNumberRaw.runtimeType);
    // print(DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now().runtimeType);
    // print(json['metadata'].runtimeType);

    return DistributedQuery(
        queryNumber: queryNumber,
        query: json['query'] as String,
        // timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
        // metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'query_number': queryNumber,
      'query': query,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }
}

/// پاسخ که به سرور ارسال می‌شود
class DistributedResponse {
  final int queryNumber;
  final String response;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  DistributedResponse({
    required this.queryNumber,
    required this.response,
    DateTime? timestamp,
    this.metadata = const {},
  }) : timestamp = timestamp ?? DateTime.now();

  factory DistributedResponse.fromJson(Map<String, dynamic> json) {
    return DistributedResponse(
      queryNumber: json['query_number'] as int,
      response: json['response'] as String,
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'query_number': queryNumber,
      'response': response,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }
}

/// Interface برای worker پس‌زمینه
abstract class DistributedWorker {
  /// آیا worker در حال اجرا است؟
  bool get isRunning;
  
  /// آیا worker متوقف شده؟
  bool get isPaused;
  
  /// تعداد query های پردازش شده
  int get processedQueries;
  
  /// آخرین زمان فعالیت
  DateTime? get lastActivity;
  
  /// Stream رویدادهای worker
  Stream<WorkerEvent> get events;

  /// شروع worker
  Future<void> start();

  /// متوقف کردن worker
  Future<void> stop();

  /// توقف موقت worker
  Future<void> pause();

  /// ادامه worker بعد از توقف
  Future<void> resume();

  /// بررسی وضعیت سرور
  Future<bool> checkServerConnection();

  /// تنظیم فاصله زمانی polling
  void setPollingInterval(Duration interval);
}