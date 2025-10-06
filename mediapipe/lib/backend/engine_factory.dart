// backend/engine_factory.dart - Factory برای ساخت Engine
import 'ai_engine.dart';
import 'gemma_engine.dart';
// import 'llama_engine.dart';
import '../shared/platform_helper.dart';

class EngineFactory {
  static AIEngine createDefault() {
    if (PlatformHelper.supportsGemma()) {
      return GemmaEngine();
    // } else if (PlatformHelper.supportsLlama()) {
    //   return LlamaEngine();
    }
    throw UnsupportedError('No supported engine for this platform');
  }

  static AIEngine? create(String name) {
    switch (name.toLowerCase()) {
      case 'gemma':
        return PlatformHelper.supportsGemma() ? GemmaEngine() : null;
      // case 'llama':
      // case 'llamacpp':
      //   return PlatformHelper.supportsLlama() ? LlamaEngine() : null;
      default:
        return null;
    }
  }

  static List<String> getSupportedEngines() {
    final engines = <String>[];
    if (PlatformHelper.supportsGemma()) engines.add('Gemma');
    if (PlatformHelper.supportsLlama()) engines.add('LlamaCpp');
    return engines;
  }
}