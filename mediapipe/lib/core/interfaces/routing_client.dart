// core/interfaces/routing_client.dart
import 'dart:async';
import 'distributed_worker.dart';
/// Client برای ارتباط با سرور مسیریابی
abstract class RoutingClient {
  /// آدرس سرور
  String get serverUrl;
  
  /// آیا متصل به سرور است؟
  bool get isConnected;
  
  /// آخرین زمان ارتباط موفق
  DateTime? get lastSuccessfulConnection;

  /// تنظیم آدرس سرور
  void setServerUrl(String url);

  /// ارسال query به سرور و دریافت query number
  Future<int?> submitQuery(String query);

  /// دریافت query های جدید از سرور
  Future<List<DistributedQuery>> getNewQueries();

  /// ارسال پاسخ به سرور
  Future<bool> sendResponse(DistributedResponse response);

  /// دریافت پاسخ‌های دیگر نودها برای یک query
  Future<List<String>> getResponses(int queryNumber);

  /// پاک کردن query از سرور
  Future<bool> cleanupQuery(int queryNumber);

  /// بررسی سلامت ارتباط با سرور
  Future<bool> healthCheck();

  /// بستن اتصال
  Future<void> dispose();
}