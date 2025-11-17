// shared/models.dart - تمام مدل‌های داده
import 'package:flutter_gemma/core/model.dart';
import 'package:flutter_gemma/pigeon.g.dart';

// ========== Embedding Models ==========
enum EmbeddingModel {
  embeddingGemma1024(
    url:
        'https://huggingface.co/litert-community/embeddinggemma-300m/resolve/main/embeddinggemma-300M_seq1024_mixed-precision.tflite',
    tokenizerUrl:
        'https://huggingface.co/litert-community/embeddinggemma-300m/resolve/main/sentencepiece.model',
    filename: 'embeddinggemma-300M_seq1024_mixed-precision.tflite',
    tokenizerFilename: 'sentencepiece.model',
    displayName: 'EmbeddingGemma 1024',
    size: '183MB',
    dimension: 1024,
    needsAuth: true,
  ),

  embeddingGemma2048(
    url:
        'https://huggingface.co/litert-community/embeddinggemma-300m/resolve/main/embeddinggemma-300M_seq2048_mixed-precision.tflite',
    tokenizerUrl:
        'https://huggingface.co/litert-community/embeddinggemma-300m/resolve/main/sentencepiece.model',
    filename: 'embeddinggemma-300M_seq2048_mixed-precision.tflite',
    tokenizerFilename: 'sentencepiece.model',
    displayName: 'EmbeddingGemma 2048',
    size: '196MB',
    dimension: 2048,
    needsAuth: true,
  ),

  embeddingGemma256(
    url:
        'https://huggingface.co/litert-community/embeddinggemma-300m/resolve/main/embeddinggemma-300M_seq256_mixed-precision.tflite',
    tokenizerUrl:
        'https://huggingface.co/litert-community/embeddinggemma-300m/resolve/main/sentencepiece.model',
    filename: 'embeddinggemma-300M_seq256_mixed-precision.tflite',
    tokenizerFilename: 'sentencepiece.model',
    displayName: 'EmbeddingGemma 256',
    size: '179MB',
    dimension: 256,
    needsAuth: true,
  ),

  embeddingGemma512(
    url:
        'https://huggingface.co/litert-community/embeddinggemma-300m/resolve/main/embeddinggemma-300M_seq512_mixed-precision.tflite',
    tokenizerUrl:
        'https://huggingface.co/litert-community/embeddinggemma-300m/resolve/main/sentencepiece.model',
    filename: 'embeddinggemma-300M_seq512_mixed-precision.tflite',
    tokenizerFilename: 'sentencepiece.model',
    displayName: 'EmbeddingGemma 512',
    size: '179MB',
    dimension: 512,
    needsAuth: true,
  );

  final String url;
  final String tokenizerUrl;
  final String filename;
  final String tokenizerFilename;
  final String displayName;
  final String size;
  final int dimension;
  final bool needsAuth;

  /// Constructor
  const EmbeddingModel({
    required this.url,
    required this.tokenizerUrl,
    required this.filename,
    required this.tokenizerFilename,
    required this.displayName,
    required this.size,
    required this.dimension,
    required this.needsAuth,
  });
}

// ========== AI Models ==========
enum AIModel {
  gemma3n_2B(
    url:
        'https://huggingface.co/google/gemma-3n-E2B-it-litert-preview/resolve/main/gemma-3n-E2B-it-int4.task',
    filename: 'gemma-3n-E2B-it-int4.task',
    displayName: 'Gemma 3 Nano E2B IT',
    size: '3.1GB',
    licenseUrl: 'https://huggingface.co/google/gemma-3n-E2B-it-litert-preview',
    needsAuth: true,
    preferredBackend: PreferredBackend.gpu,
    modelType: ModelType.gemmaIt,
    temperature: 1.0,
    topK: 64,
    topP: 0.95,
    supportImage: true,
    maxTokens: 4096,
    maxNumImages: 1,
    supportsFunctionCalls: true,
  ),
  gemma3n_4B(
    url:
        'https://huggingface.co/google/gemma-3n-E4B-it-litert-preview/resolve/main/gemma-3n-E4B-it-int4.task',
    filename: 'gemma-3n-E4B-it-int4.task',
    displayName: 'Gemma 3 Nano E4B IT',
    size: '6.5GB',
    licenseUrl: 'https://huggingface.co/google/gemma-3n-E4B-it-litert-preview',
    needsAuth: true,
    preferredBackend: PreferredBackend.gpu,
    modelType: ModelType.gemmaIt,
    temperature: 1.0,
    topK: 64,
    topP: 0.95,
    supportImage: true,
    maxTokens: 4096,
    maxNumImages: 1,
    supportsFunctionCalls: true,
  ),
  gemma3_1B(
    url:
        'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/Gemma3-1B-IT_multi-prefill-seq_q4_ekv2048.task',
    filename: 'Gemma3-1B-IT_multi-prefill-seq_q4_ekv2048.task',
    displayName: 'Gemma 3 1B IT',
    size: '0.5GB',
    licenseUrl: 'https://huggingface.co/litert-community/Gemma3-1B-IT',
    needsAuth: true,
    preferredBackend: PreferredBackend.gpu,
    modelType: ModelType.gemmaIt,
    temperature: 1.0,
    topK: 64,
    topP: 0.95,
    maxTokens: 128,
  ),
  gemma3_270M(
    url:
        'https://huggingface.co/litert-community/gemma-3-270m-it/resolve/main/gemma3-270m-it-q8.task',
    filename: 'gemma3-270m-it-q8.task',
    displayName: 'Gemma 3 270M IT',
    size: '0.3GB',
    licenseUrl: 'https://huggingface.co/litert-community/gemma-3-270m-it',
    needsAuth: true,
    preferredBackend: PreferredBackend.cpu,
    modelType: ModelType.gemmaIt,
    temperature: 1.0,
    topK: 64,
    topP: 0.95,
    maxTokens: 1024,
    supportsFunctionCalls: false,
  ),
  deepseek(
    url:
        'https://huggingface.co/litert-community/DeepSeek-R1-Distill-Qwen-1.5B/resolve/main/deepseek_q8_ekv1280.task',
    filename: 'deepseek_q8_ekv1280.task',
    displayName: 'DeepSeek R1 Distill Qwen 1.5B',
    size: '1.7GB',
    licenseUrl: '',
    needsAuth: false,
    preferredBackend: PreferredBackend.cpu,
    modelType: ModelType.deepSeek,
    temperature: 0.6,
    topK: 40,
    topP: 0.7,
    supportsFunctionCalls: true,
    isThinking: true,
  ),
  qwen25_1_5B_Instruct(
    url:
        'https://huggingface.co/litert-community/Qwen2.5-1.5B-Instruct/resolve/main/Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv1280.task',
    filename: 'Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv1280.task',
    displayName: 'Qwen 2.5 1.5B Instruct',
    size: '1.6GB',
    licenseUrl: 'https://huggingface.co/litert-community/Qwen2.5-1.5B-Instruct',
    needsAuth: true,
    preferredBackend: PreferredBackend.gpu,
    modelType: ModelType.qwen,
    temperature: 1.0,
    topK: 40,
    topP: 0.95,
    maxTokens: 1024,
    supportsFunctionCalls: true,
  ),
  qwen25_0_5B_instruct(
    url:
        'https://huggingface.co/litert-community/Qwen2.5-0.5B-Instruct/resolve/main/Qwen2.5-0.5B-Instruct_multi-prefill-seq_q8_ekv1280.task',
    filename: 'Qwen2.5-0.5B-Instruct_multi-prefill-seq_q8_ekv1280.task',
    displayName: 'Qwen 2.5 0.5B Instruct',
    size: '0.6GB',
    licenseUrl: 'https://huggingface.co/litert-community/Qwen2.5-0.5B-Instruct',
    needsAuth: true,
    preferredBackend: PreferredBackend.cpu,
    modelType: ModelType.qwen,
    temperature: 1.0,
    topK: 40,
    topP: 0.95,
    maxTokens: 1024,
    supportsFunctionCalls: true,
  ),
  tinyLlama_1_1B(
    url:
        'https://huggingface.co/litert-community/TinyLlama-1.1B-Chat-v1.0/resolve/main/TinyLlama-1.1B-Chat-v1.0_multi-prefill-seq_q8_ekv1280.task',
    filename: 'TinyLlama-1.1B-Chat-v1.0_multi-prefill-seq_q8_ekv1280.task',
    displayName: 'TinyLlama 1.1B Chat',
    size: '1.2GB',
    licenseUrl:
        'https://huggingface.co/litert-community/TinyLlama-1.1B-Chat-v1.0',
    needsAuth: true,
    preferredBackend: PreferredBackend.cpu,
    modelType: ModelType.general,
    temperature: 0.7,
    topK: 40,
    topP: 0.9,
    maxTokens: 1024,
    supportsFunctionCalls: false,
  ),
  hammer2_1_0_5B(
    url:
        'https://huggingface.co/litert-community/Hammer2.1-0.5b/resolve/main/hammer2p1_05b_.task',
    filename: 'hammer2p1_05b_.task',
    displayName: 'Hammer 2.1 0.5B Action Model',
    size: '0.5GB',
    licenseUrl: 'https://huggingface.co/litert-community/Hammer2.1-0.5b',
    needsAuth: true,
    preferredBackend: PreferredBackend.cpu,
    modelType: ModelType.general,
    temperature: 0.3,
    topK: 40,
    topP: 0.8,
    maxTokens: 1024,
    supportsFunctionCalls: true,
  ),
  llama32_1B(
    url:
        'https://huggingface.co/litert-community/Llama-3.2-1B-Instruct/resolve/main/Llama-3.2-1B-Instruct_seq128_q8_ekv1280.tflite',
    filename: 'Llama-3.2-1B-Instruct_seq128_q8_ekv1280.tflite',
    displayName: 'Llama 3.2 1B Instruct',
    size: '1.1GB',
    licenseUrl: 'https://huggingface.co/litert-community/Llama-3.2-1B-Instruct',
    needsAuth: true,
    preferredBackend: PreferredBackend.cpu,
    modelType: ModelType.general,
    temperature: 0.6,
    topK: 40,
    topP: 0.9,
    maxTokens: 1024,
    supportsFunctionCalls: false,
  );

  final String url;
  final String filename;
  final String displayName;
  final String size;
  final String licenseUrl;
  final bool needsAuth;
  final PreferredBackend preferredBackend;
  final ModelType modelType;
  final double temperature;
  final int topK;
  final double topP;
  final bool supportImage;
  final int maxTokens;
  final int? maxNumImages;
  final bool supportsFunctionCalls;
  final bool isThinking;

  const AIModel({
    required this.url,
    required this.filename,
    required this.displayName,
    required this.size,
    required this.licenseUrl,
    required this.needsAuth,
    required this.preferredBackend,
    required this.modelType,
    required this.temperature,
    required this.topK,
    required this.topP,
    this.supportImage = false,
    this.maxTokens = 1024,
    this.maxNumImages,
    this.supportsFunctionCalls = false,
    this.isThinking = false,
  });

  String get sizeDisplay => size;

  // برای سازگاری با کدهای قدیم
  bool get hasImage => supportImage;
  bool get hasFunctionCalls => supportsFunctionCalls;
  PreferredBackend get backend => preferredBackend;
  String get name => displayName;
}

// ========== Labs ==========
class LabCardEntry {
  final String id;
  final String title;
  final String description;
  final String author;
  final String dateLabel;
  final List<String> tags;

  const LabCardEntry({
    required this.id,
    required this.title,
    required this.description,
    required this.author,
    required this.dateLabel,
    required this.tags,
  });

  factory LabCardEntry.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    final tags = rawTags is List
        ? rawTags
            .map((tag) => tag == null ? '' : tag.toString())
            .where((tag) => tag.trim().isNotEmpty)
            .toList()
        : <String>[];

    return LabCardEntry(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? json['summary'] ?? '').toString(),
      author: (json['author'] ?? json['creator'] ?? 'Unknown').toString(),
      dateLabel: (json['date_label'] ?? json['date'] ?? '').toString(),
      tags: tags,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'author': author,
        'date_label': dateLabel,
        'tags': tags,
      };
}

// ========== Chat Message ==========
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<int>? imageBytes;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.imageBytes,
  }) : timestamp = timestamp ?? DateTime.now();

  ChatMessage copyWith({String? text}) => ChatMessage(
        text: text ?? this.text,
        isUser: isUser,
        timestamp: timestamp,
        imageBytes: imageBytes,
      );
}

// ========== Distributed Query/Response ==========
class DistributedQuery {
  final int queryNumber;
  final String query;
  final DateTime timestamp;

  DistributedQuery({
    required this.queryNumber,
    required this.query,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory DistributedQuery.fromJson(Map<String, dynamic> json) {
    final qNum = json['query_number'];
    return DistributedQuery(
      queryNumber: qNum is int
          ? qNum
          : (qNum is double
              ? qNum.toInt()
              : int.tryParse(qNum.toString()) ?? 0),
      query: json['query'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'query_number': queryNumber,
        'query': query,
        'timestamp': timestamp.toIso8601String(),
      };
}

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

  Map<String, dynamic> toJson() => {
        'query_number': queryNumber,
        'response': response,
        'timestamp': timestamp.toIso8601String(),
        'metadata': metadata,
      };
}

// ========== Download Progress ==========
enum DownloadStatus {
  idle,
  downloading,
  paused,
  completed,
  error,
}

class DownloadProgress {
  final int downloadedBytes;
  final int totalBytes;
  final double percentage;
  final int speedBps;
  final DownloadStatus status;
  final String? error;

  DownloadProgress({
    required this.downloadedBytes,
    required this.totalBytes,
    required this.percentage,
    required this.speedBps,
    required this.status,
    this.error,
  });
}

// ========== Worker Log ==========
enum WorkerLogLevel { info, success, warning, error, token }

class WorkerLog {
  final String message;
  final WorkerLogLevel level;
  final DateTime timestamp;
  final Map<String, dynamic>? data;

  WorkerLog({
    required this.message,
    required this.level,
    DateTime? timestamp,
    this.data,
  }) : timestamp = timestamp ?? DateTime.now();

  String get levelIcon {
    switch (level) {
      case WorkerLogLevel.info:
        return 'ℹ️';
      case WorkerLogLevel.success:
        return '✅';
      case WorkerLogLevel.warning:
        return '⚠️';
      case WorkerLogLevel.error:
        return '❌';
      case WorkerLogLevel.token:
        return '🔤';
    }
  }

  String get timeString {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
  }
}
