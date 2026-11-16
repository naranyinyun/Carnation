import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../script/script_models.dart';
import '../scene_metadata.dart';
import 'glass_modal_shell.dart';

class FlowchartEdge {
  const FlowchartEdge({
    required this.fromId,
    required this.toId,
    this.label,
  });

  final String fromId;
  final String toId;
  final String? label;
}

class FlowchartModal extends StatelessWidget {
  const FlowchartModal({
    super.key,
    required this.script,
    required this.currentSceneId,
    required this.debugMode,
    required this.onSelectScene,
  });

  final NovelScript script;
  final String currentSceneId;
  final bool debugMode;
  final ValueChanged<String> onSelectScene;

  @override
  Widget build(BuildContext context) {
    final edges = <FlowchartEdge>[];
    final depths = <String, int>{script.startSceneId: 0};

    for (var i = 0; i < script.scenes.length; i++) {
      final scene = script.scenes[i];
      final currentDepth = depths[scene.id] ?? i;
      final options = scene.lines.last.options;

      if (options.isNotEmpty) {
        for (final opt in options) {
          edges.add(FlowchartEdge(
            fromId: scene.id,
            toId: opt.targetSceneId,
            label: shortenOptionText(opt.text),
          ));
          final prevDepth = depths[opt.targetSceneId] ?? 0;
          if (currentDepth + 1 > prevDepth) {
            depths[opt.targetSceneId] = currentDepth + 1;
          }
        }
      } else if (!scene.isEnd && i + 1 < script.scenes.length) {
        final nextId = script.scenes[i + 1].id;
        edges.add(FlowchartEdge(fromId: scene.id, toId: nextId));
        final prevDepth = depths[nextId] ?? 0;
        if (currentDepth + 1 > prevDepth) {
          depths[nextId] = currentDepth + 1;
        }
      }
    }

    final columns = <int, List<NovelScene>>{};
    var maxDepth = 0;
    var maxRows = 1;
    for (final scene in script.scenes) {
      final d = depths[scene.id] ?? 0;
      if (d > maxDepth) maxDepth = d;
      final list = columns.putIfAbsent(d, () => []);
      list.add(scene);
      if (list.length > maxRows) maxRows = list.length;
    }

    const nodeW = 152.0;
    const nodeH = 74.0;
    const colGap = 76.0;
    const rowGap = 48.0;
    const padX = 36.0;
    const padY = 44.0;

    final canvasW = padX * 2 + (maxDepth + 1) * nodeW + maxDepth * colGap;
    final canvasH =
        math.max(300.0, padY * 2 + maxRows * nodeH + (maxRows - 1) * rowGap);

    final nodeRects = <String, Rect>{};

    for (final entry in columns.entries) {
      final col = entry.key;
      final scenesInCol = entry.value;
      final totalColH =
          scenesInCol.length * nodeH + (scenesInCol.length - 1) * rowGap;
      final startY = (canvasH - totalColH) / 2;
      final x = padX + col * (nodeW + colGap);

      for (var row = 0; row < scenesInCol.length; row++) {
        final scene = scenesInCol[row];
        final y = startY + row * (nodeH + rowGap);
        nodeRects[scene.id] = Rect.fromLTWH(x, y, nodeW, nodeH);
      }
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880, maxHeight: 460),
        child: GlassModalShell(
          title: '流程图',
          onClose: () => Navigator.of(context).pop(),
          child: Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SizedBox(
                  width: canvasW,
                  height: canvasH,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: TreeEdgePainter(
                            edges: edges,
                            nodeRects: nodeRects,
                          ),
                        ),
                      ),
                      for (final scene in script.scenes)
                        if (nodeRects[scene.id] != null)
                          Positioned.fromRect(
                            rect: nodeRects[scene.id]!,
                            child: TreeSceneNode(
                              scene: scene,
                              isCurrent: scene.id == currentSceneId,
                              debugMode: debugMode,
                              onTap: () => onSelectScene(scene.id),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TreeSceneNode extends StatelessWidget {
  const TreeSceneNode({
    super.key,
    required this.scene,
    required this.isCurrent,
    required this.debugMode,
    required this.onTap,
  });

  final NovelScene scene;
  final bool isCurrent;
  final bool debugMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = isCurrent
        ? const Color(0xFFF0C66B)
        : scene.isEnd
            ? const Color(0xAAFF8F7D)
            : Colors.white30;

    return Material(
      color: isCurrent ? const Color(0x55E55B45) : const Color(0x40161F33),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: borderColor, width: isCurrent ? 1.8 : 1.0),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                sceneDisplayTitle(scene.id),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (debugMode) ...[
                const SizedBox(height: 4),
                Text(
                  scene.id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ] else if (scene.isEnd) ...[
                const SizedBox(height: 3),
                const Text(
                  '结局',
                  style: TextStyle(
                    color: Color(0xFFF0C66B),
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class TreeEdgePainter extends CustomPainter {
  const TreeEdgePainter({
    required this.edges,
    required this.nodeRects,
  });

  final List<FlowchartEdge> edges;
  final Map<String, Rect> nodeRects;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0x88E8D5B7)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = const Color(0xFFF0C66B)
      ..style = PaintingStyle.fill;

    for (final edge in edges) {
      final fromRect = nodeRects[edge.fromId];
      final toRect = nodeRects[edge.toId];
      if (fromRect == null || toRect == null) continue;

      final start = Offset(fromRect.right, fromRect.center.dy);
      final end = Offset(toRect.left, toRect.center.dy);
      final midX = (start.dx + end.dx) / 2;

      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(midX, start.dy, midX, end.dy, end.dx, end.dy);

      canvas.drawPath(path, linePaint);
      canvas.drawCircle(start, 3.0, dotPaint);
      canvas.drawCircle(end, 3.5, dotPaint);

      if (edge.label != null && edge.label!.isNotEmpty) {
        final tp = TextPainter(
          text: TextSpan(
            text: edge.label,
            style: const TextStyle(
              color: Color(0xFFF0C66B),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 90);

        final labelCenter = Offset(midX, (start.dy + end.dy) / 2 - 12);
        tp.paint(
          canvas,
          Offset(labelCenter.dx - tp.width / 2, labelCenter.dy - tp.height / 2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant TreeEdgePainter oldDelegate) =>
      oldDelegate.edges != edges || oldDelegate.nodeRects != nodeRects;
}
