// backend/ai_engine.dart - Interface اصلی AI Engine
abstract class AIEngine {
  String get name;
  bool get isReady;
  bool get isGenerating;
  
  Future<void> init(String modelPath, Map<String, dynamic> config);
  Future<String> generate(String prompt);
  Stream<String> generateStream(String prompt);
  Future<void> stop();
  Future<void> clearHistory();
  Future<void> dispose();
  Future<bool> healthCheck();
  
  /// Completely resets the model (disposes and reinitializes)
  Future<void> resetModel(String modelPath, Map<String, dynamic> config);
}