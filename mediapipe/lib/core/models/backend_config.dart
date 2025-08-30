// core/models/backend_config.dart - تصحیح import های گمشده
import 'package:flutter_gemma/pigeon.g.dart';
import '../../models/model.dart';

/// تنظیمات backend
class BackendConfig {
  final String modelPath;
  final PreferredBackend preferredBackend;
  final double temperature;
  final int topK;
  final double topP;
  final int maxTokens;
  final bool supportImage;
  final bool supportsFunctionCalls;
  final bool isThinking;
  final Map<String, dynamic> customParams;

  BackendConfig({
    required this.modelPath,
    required this.preferredBackend,
    this.temperature = 1.0,
    this.topK = 64,
    this.topP = 0.95,
    this.maxTokens = 1024,
    this.supportImage = false,
    this.supportsFunctionCalls = false,
    this.isThinking = false,
    this.customParams = const {},
  });

  factory BackendConfig.fromModel(Model model) {
    return BackendConfig(
      modelPath: model.url,
      preferredBackend: model.preferredBackend,
      temperature: model.temperature,
      topK: model.topK,
      topP: model.topP,
      maxTokens: model.maxTokens,
      supportImage: model.supportImage,
      supportsFunctionCalls: model.supportsFunctionCalls,
      isThinking: model.isThinking,
    );
  }

  BackendConfig copyWith({
    String? modelPath,
    PreferredBackend? preferredBackend,
    double? temperature,
    int? topK,
    double? topP,
    int? maxTokens,
    bool? supportImage,
    bool? supportsFunctionCalls,
    bool? isThinking,
    Map<String, dynamic>? customParams,
  }) {
    return BackendConfig(
      modelPath: modelPath ?? this.modelPath,
      preferredBackend: preferredBackend ?? this.preferredBackend,
      temperature: temperature ?? this.temperature,
      topK: topK ?? this.topK,
      topP: topP ?? this.topP,
      maxTokens: maxTokens ?? this.maxTokens,
      supportImage: supportImage ?? this.supportImage,
      supportsFunctionCalls: supportsFunctionCalls ?? this.supportsFunctionCalls,
      isThinking: isThinking ?? this.isThinking,
      customParams: customParams ?? this.customParams,
    );
  }
}