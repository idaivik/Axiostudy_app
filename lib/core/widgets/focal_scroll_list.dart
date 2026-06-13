import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';

/// Apple-Watch–style "focal point" scrolling list.
///
/// Items are laid out at a fixed [itemExtent]. The item nearest the focal line
/// (slightly above the vertical centre) renders at full size + opacity; items
/// scale down and fade as they recede, so focus is always drawn to one item at
/// a time instead of a flat wall of cards. On open it can auto-centre a given
/// [initialFocusIndex].
///
/// Shared by the roadmap (FocalRoadmapList) and the subject chapter list.
class FocalScrollList extends StatefulWidget {
  final int itemCount;
  final double itemExtent;
  final IndexedWidgetBuilder itemBuilder;

  /// Item to centre when the list first appears (e.g. a deep-linked chapter).
  final int initialFocusIndex;

  /// Where the focal line sits, as a fraction of viewport height (0.5 = centre).
  final double focalFraction;

  /// Scale/opacity applied to fully off-focus items.
  final double minScale;
  final double minOpacity;

  const FocalScrollList({
    super.key,
    required this.itemCount,
    required this.itemExtent,
    required this.itemBuilder,
    this.initialFocusIndex = 0,
    this.focalFraction = 0.40,
    this.minScale = 0.66,
    this.minOpacity = 0.30,
  });

  @override
  State<FocalScrollList> createState() => _FocalScrollListState();
}

class _FocalScrollListState extends State<FocalScrollList> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerInitial());
  }

  void _centerInitial() {
    if (!_controller.hasClients || widget.initialFocusIndex <= 0) return;
    final target = (widget.initialFocusIndex * widget.itemExtent)
        .clamp(0.0, _controller.position.maxScrollExtent);
    _controller.jumpTo(target);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount == 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportH = constraints.maxHeight;
        final focalY = viewportH * widget.focalFraction;
        // Asymmetric padding lets the first and last items reach the focal line.
        final topPad = (focalY - widget.itemExtent / 2).clamp(0.0, viewportH);
        final bottomPad =
            (viewportH - focalY - widget.itemExtent / 2).clamp(0.0, viewportH);

        return ListView.builder(
          controller: _controller,
          itemExtent: widget.itemExtent,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(top: topPad, bottom: bottomPad),
          itemCount: widget.itemCount,
          itemBuilder: (context, i) {
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final offset = _controller.hasClients ? _controller.offset : 0.0;
                final itemCenter =
                    topPad + (i * widget.itemExtent) + (widget.itemExtent / 2);
                final focalLine = offset + focalY;
                final distance = (itemCenter - focalLine).abs();
                // Tighter range + smaller min scale → harder shrink as items recede.
                final t = (distance / (viewportH * 0.45)).clamp(0.0, 1.0);
                final eased = Curves.easeOutCubic.transform(t);
                final scale = lerpDouble(1.0, widget.minScale, eased)!;
                final opacity = lerpDouble(1.0, widget.minOpacity, t)!;
                return Opacity(
                  opacity: opacity,
                  child: Transform.scale(scale: scale, child: child),
                );
              },
              child: widget.itemBuilder(context, i),
            );
          },
        );
      },
    );
  }
}
