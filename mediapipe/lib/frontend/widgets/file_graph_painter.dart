import 'package:flutter/material.dart';
import 'file_graph_node.dart';

class FileGraphPainter extends CustomPainter {
  final List<FileGraphNode> nodes;
  final List<FileGraphEdge> edges;
  final double scale;
  final Offset offset;
  final FileGraphNode? selectedNode;
  final FileGraphNode? hoveredNode;

  FileGraphPainter({
    required this.nodes,
    required this.edges,
    this.scale = 1.0,
    this.offset = Offset.zero,
    this.selectedNode,
    this.hoveredNode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();

    // Apply transformations
    canvas.translate(size.width / 2 + offset.dx, size.height / 2 + offset.dy);
    canvas.scale(scale);

    // Draw edges first (behind nodes)
    _drawEdges(canvas);

    // Draw nodes
    _drawNodes(canvas);

    // Draw labels for selected/hovered nodes
    _drawLabels(canvas);

    canvas.restore();
  }

  void _drawEdges(Canvas canvas) {
    for (final edge in edges) {
      final source = nodes.firstWhere((n) => n.id == edge.sourceId);
      final target = nodes.firstWhere((n) => n.id == edge.targetId);

      final paint = Paint()
        ..color = Colors.white.withValues(alpha: edge.opacity)
        ..strokeWidth = edge.strokeWidth
        ..style = PaintingStyle.stroke;

      canvas.drawLine(source.position, target.position, paint);
    }
  }

  void _drawNodes(Canvas canvas) {
    for (final node in nodes) {
      final isHighlighted = node.isSelected || node.isHovered;
      final radius = node.radius * (isHighlighted ? 1.3 : 1.0);

      // Draw shadow/glow for highlighted nodes
      if (isHighlighted) {
        final glowPaint = Paint()
          ..color = node.color.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawCircle(node.position, radius * 1.5, glowPaint);
      }

      // Draw node border
      final borderPaint = Paint()
        ..color = isHighlighted ? Colors.white : node.color.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isHighlighted ? 3.0 : 2.0;
      canvas.drawCircle(node.position, radius, borderPaint);

      // Draw node fill
      final fillPaint = Paint()
        ..color = node.color.withValues(alpha: isHighlighted ? 0.9 : 0.6)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(node.position, radius - 1, fillPaint);

      // Draw chunk count indicator (inner circle size represents chunks)
      final chunkRadius = (node.chunkCount / 50.0).clamp(2.0, radius - 3);
      final innerPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(node.position, chunkRadius, innerPaint);
    }
  }

  void _drawLabels(Canvas canvas) {
    final nodesToLabel = [
      if (selectedNode != null) selectedNode!,
      if (hoveredNode != null && hoveredNode != selectedNode) hoveredNode!,
    ];

    for (final node in nodesToLabel) {
      _drawLabel(canvas, node);
    }
  }

  void _drawLabel(Canvas canvas, FileGraphNode node) {
    final textSpan = TextSpan(
      text: node.displayName,
      style: TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.8),
            blurRadius: 4,
          ),
        ],
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // Position label above the node
    final labelOffset = Offset(
      node.position.dx - textPainter.width / 2,
      node.position.dy - node.radius - textPainter.height - 8,
    );

    // Draw background
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        labelOffset.dx - 6,
        labelOffset.dy - 2,
        textPainter.width + 12,
        textPainter.height + 4,
      ),
      const Radius.circular(4),
    );

    final bgPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(bgRect, bgPaint);

    // Draw text
    textPainter.paint(canvas, labelOffset);

    // Draw metadata (chunk count and token count)
    final metaSpan = TextSpan(
      text: '${node.chunkCount} chunks • ${node.tokenCount} tokens',
      style: TextStyle(
        color: Colors.white70,
        fontSize: 9,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.8),
            blurRadius: 3,
          ),
        ],
      ),
    );

    final metaPainter = TextPainter(
      text: metaSpan,
      textDirection: TextDirection.ltr,
    );
    metaPainter.layout();

    final metaOffset = Offset(
      node.position.dx - metaPainter.width / 2,
      labelOffset.dy - metaPainter.height - 4,
    );

    metaPainter.paint(canvas, metaOffset);
  }

  @override
  bool shouldRepaint(FileGraphPainter oldDelegate) {
    return nodes != oldDelegate.nodes ||
        edges != oldDelegate.edges ||
        scale != oldDelegate.scale ||
        offset != oldDelegate.offset ||
        selectedNode != oldDelegate.selectedNode ||
        hoveredNode != oldDelegate.hoveredNode;
  }
}
