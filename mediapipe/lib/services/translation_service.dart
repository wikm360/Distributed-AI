import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import '../config/translation_config.dart';
import '../shared/logger.dart';

/// Service for translating text using Google ML Kit
class TranslationService {
  OnDeviceTranslator? _translator;
  bool _isModelDownloaded = false;

  /// Initialize the translator
  Future<void> initialize() async {
    try {
      Log.i(
        'Initializing translator (${TranslationConfig.sourceLanguageName} → ${TranslationConfig.targetLanguageName})',
        'TranslationService',
      );

      _translator = OnDeviceTranslator(
        sourceLanguage: TranslationConfig.sourceLanguage,
        targetLanguage: TranslationConfig.targetLanguage,
      );

      Log.s('Translator initialized successfully', 'TranslationService');
    } catch (e, stack) {
      Log.e('Failed to initialize translator', 'TranslationService', e);
      Log.e('Stack trace:', 'TranslationService', stack);
      rethrow;
    }
  }

  /// Check if translation model is downloaded
  Future<bool> isModelDownloaded() async {
    if (_translator == null) {
      await initialize();
    }

    try {
      final modelManager = OnDeviceTranslatorModelManager();
      _isModelDownloaded = await modelManager.isModelDownloaded(
        TranslationConfig.targetLanguage.bcpCode,
      );
      return _isModelDownloaded;
    } catch (e) {
      Log.e('Failed to check if model is downloaded', 'TranslationService', e);
      return false;
    }
  }

  /// Download translation model
  Future<bool> downloadModel({
    Function(double progress)? onProgress,
  }) async {
    if (_translator == null) {
      await initialize();
    }

    try {
      Log.i('Starting model download...', 'TranslationService');

      final modelManager = OnDeviceTranslatorModelManager();

      // Check if already downloaded
      final isDownloaded = await modelManager.isModelDownloaded(
        TranslationConfig.targetLanguage.bcpCode,
      );

      if (isDownloaded) {
        Log.i('Model already downloaded', 'TranslationService');
        _isModelDownloaded = true;
        return true;
      }

      // Download the model
      final success = await modelManager.downloadModel(
        TranslationConfig.targetLanguage.bcpCode,
      );

      if (success) {
        Log.s('Model downloaded successfully', 'TranslationService');
        _isModelDownloaded = true;
      } else {
        Log.w('Model download failed', 'TranslationService');
      }

      return success;
    } catch (e, stack) {
      Log.e('Failed to download translation model', 'TranslationService', e);
      Log.e('Stack trace:', 'TranslationService', stack);
      return false;
    }
  }

  /// Translate text
  Future<String?> translate(String text) async {
    if (_translator == null) {
      await initialize();
    }

    if (text.trim().isEmpty) {
      return null;
    }

    try {
      Log.i('Translating text (${text.length} chars)', 'TranslationService');

      final translatedText = await _translator!.translateText(text);

      if (translatedText.isNotEmpty) {
        Log.s('Translation successful', 'TranslationService');
        return translatedText;
      } else {
        Log.w('Translation returned empty text', 'TranslationService');
        return null;
      }
    } catch (e, stack) {
      Log.e('Translation failed', 'TranslationService', e);
      Log.e('Stack trace:', 'TranslationService', stack);
      return null;
    }
  }

  /// Delete translation model to free up space
  Future<bool> deleteModel() async {
    try {
      final modelManager = OnDeviceTranslatorModelManager();
      final success = await modelManager.deleteModel(
        TranslationConfig.targetLanguage.bcpCode,
      );

      if (success) {
        Log.i('Model deleted successfully', 'TranslationService');
        _isModelDownloaded = false;
      }

      return success;
    } catch (e) {
      Log.e('Failed to delete model', 'TranslationService', e);
      return false;
    }
  }

  /// Close the translator and free resources
  Future<void> dispose() async {
    try {
      await _translator?.close();
      _translator = null;
      Log.i('Translator closed', 'TranslationService');
    } catch (e) {
      Log.e('Failed to close translator', 'TranslationService', e);
    }
  }

  /// Get model download status
  bool get isReady => _isModelDownloaded;
}
