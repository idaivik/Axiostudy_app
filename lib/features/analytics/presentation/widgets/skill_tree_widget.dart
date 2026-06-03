import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/models/enums.dart';
import '../../domain/chart_data_models.dart';

/// Apple-inspired Node-Link Skill Tree showing topic prerequisites.
/// Mastered nodes glow green, weak nodes show orange indicator,
/// links are smooth Bézier curves.
class SkillTreeWidget extends StatefulWidget {
  final List<SkillTreeNode> nodes;
  final String title;
  final double height;

  const SkillTreeWidget({
    super.key,
    required this.nodes,
    this.title = 'Skill Tree',
    this.height = 400,
  });

  @override
  State<SkillTreeWidget> createState() => _SkillTreeWidgetState();
}

class _SkillTreeWidgetState extends State<SkillTreeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.nodes.isEmpty) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text(
            'No prerequisite data available yet',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textLight),
          ),
        ),
      );
    }

    // Build the tree layout
    final layout = _computeLayout(widget.nodes);

    return _AnimatedBuilder2(
      animation: _animation,
      builder: (context, _) {
        return SizedBox(
          height: widget.height,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
              width: max(layout.totalWidth, MediaQuery.of(context).size.width - 72),
              height: widget.height,
              child: CustomPaint(
                painter: _SkillTreePainter(
                  layout: layout,
                  progress: _animation.value,
                ),
                child: Stack(
                  children: layout.positionedNodes.map((pn) {
                    return Positioned(
                      left: pn.x - pn.width / 2,
                      top: pn.y - 18,
                      child: Opacity(
                        opacity: _animation.value,
                        child: Transform.scale(
                          scale: 0.8 + 0.2 * _animation.value,
                          child: _NodeChip(
                            label: pn.node.label,
                            strength: pn.node.strength,
                            accuracy: pn.node.accuracy,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  _TreeLayout _computeLayout(List<SkillTreeNode> nodes) {
    // Build adjacency: which nodes are roots (no prerequisites in the set)?
    final nodeMap = {for (var n in nodes) n.topicId: n};
    final allIds = nodeMap.keys.toSet();

    // Find children for each node
    final children = <String, List<String>>{};
    for (final n in nodes) {
      for (final prereqId in n.prerequisiteIds) {
        if (allIds.contains(prereqId)) {
          children.putIfAbsent(prereqId, () => []).add(n.topicId);
        }
      }
    }

    // Roots = nodes that are not a child of anyone in this set
    final childSet = children.values.expand((c) => c).toSet();
    final roots = allIds.where((id) => !childSet.contains(id)).toList();
    if (roots.isEmpty && nodes.isNotEmpty) {
      // Fallback: use first node as root
      roots.add(nodes.first.topicId);
    }

    // BFS to assign levels
    final levels = <String, int>{};
    final queue = <String>[...roots];
    for (final r in roots) {
      levels[r] = 0;
    }

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final currentLevel = levels[current]!;
      for (final childId in (children[current] ?? [])) {
        final existingLevel = levels[childId];
        if (existingLevel == null || existingLevel < currentLevel + 1) {
          levels[childId] = currentLevel + 1;
          queue.add(childId);
        }
      }
    }

    // Assign remaining unvisited nodes
    for (final id in allIds) {
      levels.putIfAbsent(id, () => 0);
    }

    // Group by level
    final levelGroups = <int, List<String>>{};
    for (final entry in levels.entries) {
      levelGroups.putIfAbsent(entry.value, () => []).add(entry.key);
    }

    final maxLevel = levelGroups.keys.reduce(max);
    const nodeWidth = 120.0;
    const nodeSpacingH = 24.0;
    const levelSpacingV = 80.0;

    final positionedNodes = <_PositionedNode>[];
    final positions = <String, Offset>{};

    for (int level = 0; level <= maxLevel; level++) {
      final nodesAtLevel = levelGroups[level] ?? [];
      final totalW = nodesAtLevel.length * nodeWidth +
          (nodesAtLevel.length - 1) * nodeSpacingH;
      final startX = totalW / 2;

      for (int i = 0; i < nodesAtLevel.length; i++) {
        final id = nodesAtLevel[i];
        final x = -startX + i * (nodeWidth + nodeSpacingH) + nodeWidth / 2 +
            (levelGroups.values.map((v) => v.length).reduce(max) * (nodeWidth + nodeSpacingH)) / 2;
        final y = 20.0 + level * levelSpacingV;
        positions[id] = Offset(x, y);
        positionedNodes.add(_PositionedNode(
          node: nodeMap[id]!,
          x: x,
          y: y,
          width: nodeWidth,
        ));
      }
    }

    // Build edges
    final edges = <_Edge>[];
    for (final n in nodes) {
      for (final prereqId in n.prerequisiteIds) {
        if (positions.containsKey(prereqId) && positions.containsKey(n.topicId)) {
          edges.add(_Edge(
            from: positions[prereqId]!,
            to: positions[n.topicId]!,
            fromStrength: nodeMap[prereqId]?.strength ?? TopicStrength.moderate,
          ));
        }
      }
    }

    final allX = positionedNodes.map((p) => p.x).toList();
    final minX = allX.isEmpty ? 0.0 : allX.reduce(min);
    final maxX = allX.isEmpty ? 300.0 : allX.reduce(max);
    final totalWidth = (maxX - minX) + nodeWidth + 48;

    return _TreeLayout(
      positionedNodes: positionedNodes,
      edges: edges,
      totalWidth: totalWidth,
    );
  }
}

class _TreeLayout {
  final List<_PositionedNode> positionedNodes;
  final List<_Edge> edges;
  final double totalWidth;

  const _TreeLayout({
    required this.positionedNodes,
    required this.edges,
    required this.totalWidth,
  });
}

class _PositionedNode {
  final SkillTreeNode node;
  final double x, y, width;

  const _PositionedNode({
    required this.node,
    required this.x,
    required this.y,
    required this.width,
  });
}

class _Edge {
  final Offset from, to;
  final TopicStrength fromStrength;

  const _Edge({required this.from, required this.to, required this.fromStrength});
}

class _SkillTreePainter extends CustomPainter {
  final _TreeLayout layout;
  final double progress;

  _SkillTreePainter({required this.layout, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw Bézier curve links
    for (final edge in layout.edges) {
      final paint = Paint()
        ..color = edge.fromStrength == TopicStrength.strong
            ? AppColors.primary.withValues(alpha: 0.3 * progress)
            : AppColors.surfaceDark.withValues(alpha: progress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      final midY = (edge.from.dy + edge.to.dy) / 2;
      final path = Path()
        ..moveTo(edge.from.dx, edge.from.dy + 18)
        ..cubicTo(
          edge.from.dx, midY,
          edge.to.dx, midY,
          edge.to.dx, edge.to.dy - 18,
        );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SkillTreePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Individual node chip in the skill tree.
class _NodeChip extends StatelessWidget {
  final String label;
  final TopicStrength strength;
  final double accuracy;

  const _NodeChip({
    required this.label,
    required this.strength,
    required this.accuracy,
  });

  @override
  Widget build(BuildContext context) {
    final isMastered = strength == TopicStrength.strong;
    final isWeak = strength == TopicStrength.weak;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isMastered
            ? AppColors.greenSurface
            : isWeak
                ? AppColors.warningLight
                : AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMastered
              ? AppColors.primary.withValues(alpha: 0.5)
              : isWeak
                  ? AppColors.warning.withValues(alpha: 0.4)
                  : AppColors.surfaceDark,
          width: isMastered ? 2 : 1,
        ),
        boxShadow: [
          if (isMastered)
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 2),
            )
          else
            BoxShadow(
              color: AppColors.slate900.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isWeak)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  color: AppColors.warning,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          if (isMastered)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.check_circle, size: 12, color: AppColors.primary),
            ),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isMastered ? FontWeight.w600 : FontWeight.w500,
                color: isMastered
                    ? AppColors.greenStrong
                    : isWeak
                        ? AppColors.weak
                        : AppColors.textDark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Reused AnimatedBuilder pattern.
class _AnimatedBuilder2 extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;
  final Widget? child;

  const _AnimatedBuilder2({
    required Animation<double> animation,
    required this.builder,
    this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}
