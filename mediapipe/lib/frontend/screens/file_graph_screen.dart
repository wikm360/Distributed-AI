import 'dart:math';
import 'package:flutter/material.dart';
import '../../rag/rag_manager.dart';
import '../../rag/rag_entity.dart';
import '../widgets/file_graph_node.dart';
import '../widgets/file_graph_visualizer.dart';
import '../widgets/starfield_background.dart';

class FileGraphScreen extends StatefulWidget {
  final RAGManager ragManager;

  const FileGraphScreen({
    super.key,
    required this.ragManager,
  });

  @override
  State<FileGraphScreen> createState() => _FileGraphScreenState();
}

class _FileGraphScreenState extends State<FileGraphScreen> {
  List<FileGraphNode> _nodes = [];
  List<FileGraphEdge> _edges = [];
  bool _isLoading = true;
  String? _error;

  // Clustering parameters
  static const double _similarityThreshold = 0.3;

  @override
  void initState() {
    super.initState();
    _loadGraphData();
  }

  Future<void> _loadGraphData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Check if RAG is initialized
      if (!widget.ragManager.isInitialized) {
        throw Exception('RAG Manager not initialized');
      }

      // Get all file embeddings from ObjectBox store
      final store = widget.ragManager.store;
      if (store == null) {
        throw Exception('ObjectBox store not available');
      }

      final fileEmbeddings = store.box<DocumentFileEmbedding>().getAll();

      if (fileEmbeddings.isEmpty) {
        setState(() {
          _error = 'No files found. Upload some files to see the graph.';
          _isLoading = false;
        });
        return;
      }

      // Convert to graph nodes
      final nodes = <FileGraphNode>[];
      for (final file in fileEmbeddings) {
        nodes.add(FileGraphNode(
          id: file.id.toString(),
          fileName: file.source,
          embedding: file.embedding,
          chunkCount: file.chunkCount,
          tokenCount: file.tokenCount,
        ));
      }

      // Calculate similarities and create edges
      final edges = <FileGraphEdge>[];
      for (int i = 0; i < nodes.length; i++) {
        for (int j = i + 1; j < nodes.length; j++) {
          final similarity = nodes[i].similarityTo(nodes[j]);

          // Only create edge if similarity is above threshold
          if (similarity >= _similarityThreshold) {
            edges.add(FileGraphEdge(
              sourceId: nodes[i].id,
              targetId: nodes[j].id,
              similarity: similarity,
            ));
          }
        }
      }

      // Perform clustering
      final clusters = _performClustering(nodes, edges);

      // Assign colors to nodes based on clusters
      final clusterColors = _generateClusterColors(clusters.length);
      for (int i = 0; i < nodes.length; i++) {
        nodes[i] = nodes[i].copyWith(
          clusterId: clusters[i],
          color: clusterColors[clusters[i]],
        );
      }

      setState(() {
        _nodes = nodes;
        _edges = edges;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading graph: $e';
        _isLoading = false;
      });
    }
  }

  /// Simple clustering using connected components
  List<int> _performClustering(
    List<FileGraphNode> nodes,
    List<FileGraphEdge> edges,
  ) {
    if (nodes.isEmpty) return [];

    // Initialize each node in its own cluster
    final clusters = List.generate(nodes.length, (i) => i);

    // Union-find to merge clusters
    int find(int i) {
      if (clusters[i] != i) {
        clusters[i] = find(clusters[i]);
      }
      return clusters[i];
    }

    void union(int i, int j) {
      final rootI = find(i);
      final rootJ = find(j);
      if (rootI != rootJ) {
        clusters[rootI] = rootJ;
      }
    }

    // Merge nodes connected by strong edges
    for (final edge in edges) {
      if (edge.similarity >= 0.5) {
        // Strong similarity threshold
        final sourceIdx = nodes.indexWhere((n) => n.id == edge.sourceId);
        final targetIdx = nodes.indexWhere((n) => n.id == edge.targetId);
        if (sourceIdx != -1 && targetIdx != -1) {
          union(sourceIdx, targetIdx);
        }
      }
    }

    // Normalize cluster IDs
    final uniqueClusters = <int>{};
    for (int i = 0; i < clusters.length; i++) {
      clusters[i] = find(i);
      uniqueClusters.add(clusters[i]);
    }

    // Remap to sequential IDs
    final clusterMap = <int, int>{};
    int nextId = 0;
    for (final clusterId in uniqueClusters) {
      clusterMap[clusterId] = nextId++;
    }

    return clusters.map((c) => clusterMap[c]!).toList();
  }

  List<Color> _generateClusterColors(int count) {
    final colors = <Color>[
      const Color(0xFF6366F1), // Indigo
      const Color(0xFFEC4899), // Pink
      const Color(0xFF10B981), // Emerald
      const Color(0xFFF59E0B), // Amber
      const Color(0xFF8B5CF6), // Violet
      const Color(0xFF06B6D4), // Cyan
      const Color(0xFFEF4444), // Red
      const Color(0xFF14B8A6), // Teal
    ];

    // If we need more colors, generate them
    if (count > colors.length) {
      final random = Random(42); // Fixed seed for consistency
      for (int i = colors.length; i < count; i++) {
        colors.add(Color.fromARGB(
          255,
          random.nextInt(256),
          random.nextInt(256),
          random.nextInt(256),
        ));
      }
    }

    return colors.take(count).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('File Similarity Graph'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: _showHelpDialog,
              tooltip: 'Help',
            ),
          // IconButton(
          //   icon: const Icon(Icons.refresh),
          //   onPressed: _loadGraphData,
          //   tooltip: 'Refresh',
          // ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: StarfieldBackground(
        backgroundColor: const Color(0xFF0A0A0F),
        starCount: 150,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white70),
            SizedBox(height: 16),
            Text(
              'Loading file embeddings...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadGraphData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white24,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_nodes.isEmpty) {
      return const Center(
        child: Text(
          'No files to display',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return FileGraphVisualizer(
      nodes: _nodes,
      edges: _edges,
      onRefresh: _loadGraphData,
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text(
          'File Similarity Graph',
          style: TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHelpSection(
                'What is this?',
                'This graph visualizes relationships between your files based on their semantic embeddings. Files with similar content are positioned closer together.',
              ),
              const SizedBox(height: 16),
              _buildHelpSection(
                'Nodes',
                '• Each circle represents a file\n'
                    '• Size indicates number of chunks\n'
                    '• Color represents the cluster/topic\n'
                    '• Inner circle shows relative chunk count',
              ),
              const SizedBox(height: 16),
              _buildHelpSection(
                'Edges',
                'Lines connect similar files. Thicker/brighter lines indicate higher similarity.',
              ),
              const SizedBox(height: 16),
              _buildHelpSection(
                'Interactions',
                '• Pinch or scroll to zoom\n'
                    '• Drag to pan around\n'
                    '• Tap a node to view details\n'
                    '• Use controls to reset or pause simulation',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          content,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
