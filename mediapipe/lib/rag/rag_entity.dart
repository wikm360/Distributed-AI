// rag/rag_entity.dart - ObjectBox Entity for RAG document chunks
import 'package:objectbox/objectbox.dart';

@Entity()
class DocumentChunk {
  @Id()
  int id = 0;

  /// Original document filename or source
  String? source;

  /// Text content of the chunk
  String? content;

  /// Embedding vector (must match embedding model dimension)
  /// Note: mobilebert-uncased embedding dimension is 768
  @HnswIndex(dimensions: 768, distanceType: VectorDistanceType.cosine)
  @Property(type: PropertyType.floatVector)
  List<double>? embedding;

  /// Metadata (e.g., page number, section title)
  String? metadata;

  /// Timestamp when chunk was created
  @Property(type: PropertyType.date)
  DateTime? createdAt;

  DocumentChunk({
    this.source,
    this.content,
    this.embedding,
    this.metadata,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}
