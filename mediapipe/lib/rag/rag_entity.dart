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
  @HnswIndex(
      dimensions: 512,
      distanceType: VectorDistanceType.cosine,
      neighborsPerNode: 48,
      indexingSearchCount: 200)
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

@Entity()
class DocumentFileEmbedding {
  @Id()
  int id = 0;

  @Unique()
  String source;

  int chunkCount;
  int tokenCount;

  @HnswIndex(
    dimensions: 512,
    distanceType: VectorDistanceType.cosine,
    neighborsPerNode: 48,
    indexingSearchCount: 200,
  )
  @Property(type: PropertyType.floatVector)
  List<double> embedding;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  DocumentFileEmbedding({
    required this.source,
    required this.embedding,
    this.chunkCount = 0,
    this.tokenCount = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

/// Entity for user folders in Backpack
@Entity()
class UserFolder {
  @Id()
  int id = 0;

  /// Folder name
  String name;

  /// Parent folder ID (0 for root folders)
  int parentId;

  /// Folder color (hex string)
  String? color;

  /// Folder icon name
  String? iconName;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  @Property(type: PropertyType.date)
  DateTime updatedAt;

  UserFolder({
    required this.name,
    this.parentId = 0,
    this.color,
    this.iconName,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();
}

/// Entity for user files in Backpack
@Entity()
class UserFile {
  @Id()
  int id = 0;

  /// File name
  String name;

  /// File path on device
  String filePath;

  /// Parent folder ID (0 for root)
  int folderId;

  /// File size in bytes
  int fileSize;

  /// File MIME type
  String? mimeType;

  /// File extension
  String? extension;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  @Property(type: PropertyType.date)
  DateTime updatedAt;

  UserFile({
    required this.name,
    required this.filePath,
    this.folderId = 0,
    this.fileSize = 0,
    this.mimeType,
    this.extension,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();
}
