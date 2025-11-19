import 'dart:math';
import 'package:flutter/material.dart';

/// Represents a node in the file graph visualization
class FileGraphNode {
  final String id;
  final String fileName;
  final List<double> embedding;
  final int chunkCount;
  final int tokenCount;

  // Graph properties
  Offset position;
  Offset velocity;
  double radius;
  Color color;
  int clusterId;

  // UI state
  bool isSelected;
  bool isHovered;

  FileGraphNode({
    required this.id,
    required this.fileName,
    required this.embedding,
    required this.chunkCount,
    required this.tokenCount,
    Offset? initialPosition,
    this.clusterId = 0,
    Color? color,
  })  : position = initialPosition ?? Offset.zero,
        velocity = Offset.zero,
        radius = 8.0 + (chunkCount / 10).clamp(0, 12).toDouble(),
        color = color ?? Colors.blue,
        isSelected = false,
        isHovered = false;

  /// Calculate cosine similarity between this node and another
  double similarityTo(FileGraphNode other) {
    if (embedding.length != other.embedding.length) return 0.0;

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < embedding.length; i++) {
      dotProduct += embedding[i] * other.embedding[i];
      normA += embedding[i] * embedding[i];
      normB += other.embedding[i] * other.embedding[i];
    }

    if (normA == 0.0 || normB == 0.0) return 0.0;

    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  /// Get display name (shortened if too long)
  String get displayName {
    if (fileName.length <= 25) return fileName;
    return '${fileName.substring(0, 22)}...';
  }

  /// Get file extension
  String get extension {
    final parts = fileName.split('.');
    return parts.length > 1 ? parts.last : '';
  }

  FileGraphNode copyWith({
    Offset? position,
    Offset? velocity,
    bool? isSelected,
    bool? isHovered,
    Color? color,
    int? clusterId,
  }) {
    return FileGraphNode(
      id: id,
      fileName: fileName,
      embedding: embedding,
      chunkCount: chunkCount,
      tokenCount: tokenCount,
      initialPosition: position ?? this.position,
      color: color ?? this.color,
      clusterId: clusterId ?? this.clusterId,
    )
      ..velocity = velocity ?? this.velocity
      ..isSelected = isSelected ?? this.isSelected
      ..isHovered = isHovered ?? this.isHovered
      ..radius = radius;
  }
}

/// Edge connection between two nodes
class FileGraphEdge {
  final String sourceId;
  final String targetId;
  final double similarity;
  final double weight;

  FileGraphEdge({
    required this.sourceId,
    required this.targetId,
    required this.similarity,
  }) : weight = similarity;

  double get opacity => (similarity * 0.7).clamp(0.1, 0.7);
  double get strokeWidth => (similarity * 3).clamp(0.5, 2.5);
}

/// Cluster information
class FileCluster {
  final int id;
  final List<String> nodeIds;
  final Color color;
  final Offset centroid;

  FileCluster({
    required this.id,
    required this.nodeIds,
    required this.color,
    required this.centroid,
  });
}
