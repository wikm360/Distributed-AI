import 'package:google_mlkit_translation/google_mlkit_translation.dart';

/// Translation configuration settings
class TranslationConfig {
  // Source language (the language of the PDF text)
  static const TranslateLanguage sourceLanguage = TranslateLanguage.english;

  // Target language (the language to translate to)
  static const TranslateLanguage targetLanguage = TranslateLanguage.persian;

  // Get language display names
  static String get sourceLanguageName {
    switch (sourceLanguage) {
      case TranslateLanguage.english:
        return 'English';
      case TranslateLanguage.persian:
        return 'فارسی';
      case TranslateLanguage.arabic:
        return 'العربية';
      case TranslateLanguage.french:
        return 'Français';
      case TranslateLanguage.german:
        return 'Deutsch';
      case TranslateLanguage.spanish:
        return 'Español';
      default:
        return sourceLanguage.name;
    }
  }

  static String get targetLanguageName {
    switch (targetLanguage) {
      case TranslateLanguage.english:
        return 'English';
      case TranslateLanguage.persian:
        return 'فارسی';
      case TranslateLanguage.arabic:
        return 'العربية';
      case TranslateLanguage.french:
        return 'Français';
      case TranslateLanguage.german:
        return 'Deutsch';
      case TranslateLanguage.spanish:
        return 'Español';
      default:
        return targetLanguage.name;
    }
  }
}
