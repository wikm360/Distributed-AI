import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'file_graph_node.dart';
import 'file_graph_painter.dart';

class FileGraphVisualizer extends StatefulWidget {
  final List<FileGraphNode> nodes;
  final List<FileGraphEdge> edges;
  final VoidCallback? onRefresh;

  const FileGraphVisualizer({
    super.key,
    required this.nodes,
    required this.edges,
    this.onRefresh,
  });

  @override
  State<FileGraphVisualizer> createState() => _FileGraphVisualizerState();
}

class _FileGraphVisualizerState extends State<FileGraphVisualizer>
    with TickerProviderStateMixin {
  late List<FileGraphNode> _nodes;
  late List<FileGraphEdge> _edges;

  // Viewport controls
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  Offset _lastFocalPoint = Offset.zero;

  // Interaction state
  FileGraphNode? _selectedNode;
  FileGraphNode? _hoveredNode;

  // Animation
  Timer? _physicsTimer;
  bool _isSimulationRunning = true;

  // Physics parameters
  static const double _repulsionStrength = 5000.0;
  static const double _attractionStrength = 0.01;
  static const double _damping = 0.85;
  static const double _centeringForce = 0.002;
  static const double _minDistance = 50.0;

  @override
  void initState() {
    super.initState();
    _initializeGraph();
    _startPhysicsSimulation();
  }

  void _initializeGraph() {
    _nodes = List.from(widget.nodes);
    _edges = List.from(widget.edges);

    // Initialize random positions in a circle
    final random = Random();
    final radius = 200.0;

    for (int i = 0; i < _nodes.length; i++) {
      final angle = (i / _nodes.length) * 2 * pi;
      final r = radius * (0.5 + random.nextDouble() * 0.5);
      _nodes[i] = _nodes[i].copyWith(
        position: Offset(r * cos(angle), r * sin(angle)),
      );
    }
  }

  void _startPhysicsSimulation() {
    _physicsTimer?.cancel();
    _physicsTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (_isSimulationRunning && mounted) {
        _updatePhysics();
      }
    });
  }

  void _updatePhysics() {
    if (_nodes.isEmpty) return;

    // Apply forces
    for (int i = 0; i < _nodes.length; i++) {
      Offset force = Offset.zero;

      // Repulsion between all nodes
      for (int j = 0; j < _nodes.length; j++) {
        if (i == j) continue;

        final delta = _nodes[i].position - _nodes[j].position;
        final distance = max(delta.distance, _minDistance);
        final repulsion = delta / distance * (_repulsionStrength / (distance * distance));
        force += repulsion;
      }

      // Attraction along edges
      for (final edge in _edges) {
        if (edge.sourceId == _nodes[i].id) {
          final target = _nodes.firstWhere((n) => n.id == edge.targetId);
          final delta = target.position - _nodes[i].position;
          force += delta * _attractionStrength * edge.weight;
        } else if (edge.targetId == _nodes[i].id) {
          final source = _nodes.firstWhere((n) => n.id == edge.sourceId);
          final delta = source.position - _nodes[i].position;
          force += delta * _attractionStrength * edge.weight;
        }
      }

      // Centering force (weak pull to origin)
      force += -_nodes[i].position * _centeringForce;

      // Update velocity and position
      final newVelocity = (_nodes[i].velocity + force) * _damping;
      final newPosition = _nodes[i].position + newVelocity;

      _nodes[i] = _nodes[i].copyWith(
        velocity: newVelocity,
        position: newPosition,
      );
    }

    // Check if simulation should stop (low energy)
    final totalEnergy = _nodes.fold<double>(
      0.0,
      (sum, node) => sum + node.velocity.distance,
    );

    if (totalEnergy < 0.5 && _isSimulationRunning) {
      setState(() {
        _isSimulationRunning = false;
      });
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _lastFocalPoint = details.focalPoint;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      // Handle zoom
      if (details.scale != 1.0) {
        final newScale = (_scale * details.scale).clamp(0.3, 3.0);
        _scale = newScale;
      }

      // Handle pan
      final delta = details.focalPoint - _lastFocalPoint;
      _offset += delta;
      _lastFocalPoint = details.focalPoint;
    });
  }

  void _handleTapDown(TapDownDetails details) {
    final localPosition = _screenToGraph(details.localPosition);

    // Find node at tap position
    FileGraphNode? tappedNode;
    for (final node in _nodes) {
      final distance = (node.position - localPosition).distance;
      if (distance <= node.radius * 1.5) {
        tappedNode = node;
        break;
      }
    }

    setState(() {
      if (_selectedNode == tappedNode) {
        _selectedNode = null;
      } else {
        _selectedNode = tappedNode;
      }
    });
  }

  void _handleHover(PointerEvent event) {
    final localPosition = _screenToGraph(event.localPosition);

    FileGraphNode? hoveredNode;
    for (final node in _nodes) {
      final distance = (node.position - localPosition).distance;
      if (distance <= node.radius * 1.5) {
        hoveredNode = node;
        break;
      }
    }

    if (hoveredNode != _hoveredNode) {
      setState(() {
        _hoveredNode = hoveredNode;
      });
    }
  }

  Offset _screenToGraph(Offset screenPos) {
    final size = context.size ?? Size.zero;
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    return Offset(
      (screenPos.dx - centerX - _offset.dx) / _scale,
      (screenPos.dy - centerY - _offset.dy) / _scale,
    );
  }

  void _resetView() {
    setState(() {
      _scale = 1.0;
      _offset = Offset.zero;
      _selectedNode = null;
      _hoveredNode = null;
    });
  }

  void _restartSimulation() {
    setState(() {
      _isSimulationRunning = true;
      _initializeGraph();
    });
  }

  @override
  void dispose() {
    _physicsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Graph canvas
        GestureDetector(
          onScaleStart: _handleScaleStart,
          onScaleUpdate: _handleScaleUpdate,
          onTapDown: _handleTapDown,
          child: MouseRegion(
            onHover: _handleHover,
            child: Container(
              color: Colors.transparent,
              child: CustomPaint(
                painter: FileGraphPainter(
                  nodes: _nodes,
                  edges: _edges,
                  scale: _scale,
                  offset: _offset,
                  selectedNode: _selectedNode,
                  hoveredNode: _hoveredNode,
                ),
                size: Size.infinite,
              ),
            ),
          ),
        ),

        // Controls overlay
        Positioned(
          bottom: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildControlButton(
                icon: Icons.refresh,
                tooltip: 'Restart Simulation',
                onPressed: _restartSimulation,
              ),
              const SizedBox(height: 8),
              _buildControlButton(
                icon: Icons.center_focus_strong,
                tooltip: 'Reset View',
                onPressed: _resetView,
              ),
              const SizedBox(height: 8),
              _buildControlButton(
                icon: _isSimulationRunning ? Icons.pause : Icons.play_arrow,
                tooltip: _isSimulationRunning ? 'Pause' : 'Resume',
                onPressed: () {
                  setState(() {
                    _isSimulationRunning = !_isSimulationRunning;
                  });
                },
              ),
            ],
          ),
        ),

        // Info overlay
        Positioned(
          bottom: 16,
          left: 16,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_nodes.length} files • ${_edges.length} connections',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pinch to zoom • Drag to pan • Tap to select',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Selected node info panel
        if (_selectedNode != null)
          Positioned(
            bottom: 16,
            left: 16,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 300),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedNode!.color,
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedNode!.fileName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 18),
                        onPressed: () {
                          setState(() {
                            _selectedNode = null;
                          });
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow('Chunks', '${_selectedNode!.chunkCount}'),
                  _buildInfoRow('Tokens', '${_selectedNode!.tokenCount}'),
                  _buildInfoRow('Cluster', '#${_selectedNode!.clusterId}'),
                  if (_selectedNode!.extension.isNotEmpty)
                    _buildInfoRow('Type', '.${_selectedNode!.extension}'),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
