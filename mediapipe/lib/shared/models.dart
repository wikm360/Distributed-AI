// shared/models.dart - تمام مدل‌های داده
import 'package:flutter_gemma/core/model.dart';
import 'package:flutter_gemma/pigeon.g.dart';

// ========== AI Models ==========
enum AIModel {
  gemma3n_2B(
    url: 'https://huggingface.co/google/gemma-3n-E2B-it-litert-preview/resolve/main/gemma-3n-E2B-it-int4.task',
    filename: 'gemma-3n-E2B-it-int4.task',
    name: 'Gemma 3 Nano E2B IT',
    sizeMB: 3100,
    needsAuth: true,
    backend: PreferredBackend.gpu,
    modelType: ModelType.gemmaIt,
    hasImage: true,
    hasFunctionCalls: true,
  ),
  gemma3n_4B(
    url: 'https://huggingface.co/google/gemma-3n-E4B-it-litert-preview/resolve/main/gemma-3n-E4B-it-int4.task',
    filename: 'gemma-3n-E4B-it-int4.task',
    name: 'Gemma 3 Nano E4B IT',
    sizeMB: 6500,
    needsAuth: true,
    backend: PreferredBackend.gpu,
    modelType: ModelType.gemmaIt,
    hasImage: true,
    hasFunctionCalls: true,
  ),
  gemma3_1B(
    url: 'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/Gemma3-1B-IT_multi-prefill-seq_q4_ekv2048.task',
    filename: 'Gemma3-1B-IT_multi-prefill-seq_q4_ekv2048.task',
    name: 'Gemma 3 1B IT',
    sizeMB: 500,
    needsAuth: true,
    backend: PreferredBackend.gpu,
    modelType: ModelType.gemmaIt,
  ),
  deepseek(
    url: 'https://huggingface.co/litert-community/DeepSeek-R1-Distill-Qwen-1.5B/resolve/main/deepseek_q8_ekv1280.task',
    filename: 'deepseek_q8_ekv1280.task',
    name: 'DeepSeek R1 Distill Qwen 1.5B',
    sizeMB: 1700,
    needsAuth: false,
    backend: PreferredBackend.cpu,
    modelType: ModelType.deepSeek,
    hasFunctionCalls: true,
    isThinking: true,
  );

  final String url;
  final String filename;
  final String name;
  final int sizeMB;
  final bool needsAuth;
  final PreferredBackend backend;
  final ModelType modelType;
  final bool hasImage;
  final bool hasFunctionCalls;
  final bool isThinking;

  const AIModel({
    required this.url,
    required this.filename,
    required this.name,
    required this.sizeMB,
    required this.needsAuth,
    required this.backend,
    required this.modelType,
    this.hasImage = false,
    this.hasFunctionCalls = false,
    this.isThinking = false,
  });

  String get sizeDisplay => sizeMB >= 1024 
      ? '${(sizeMB / 1024).toStringAsFixed(1)}GB' 
      : '${sizeMB}MB';
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
      queryNumber: qNum is int ? qNum : (qNum is double ? qNum.toInt() : int.tryParse(qNum.toString()) ?? 0),
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