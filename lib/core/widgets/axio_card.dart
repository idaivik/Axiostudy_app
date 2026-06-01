import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Expandable/collapsible card used throughout AxioStudy.
///
/// Shows a summary in collapsed state with an optional metric badge.
/// Expands smoothly to reveal detailed content on tap.
/// Supports an accent color strip on the left edge.
class AxioCard extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final Widget? collapsedContent;
  final Widget? expandedContent;
  final bool isExpandable;
  final bool initiallyExpanded;
  final Color? accentColor;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const AxioCard({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.collapsedContent,
    this.expandedContent,
    this.isExpandable = true,
    this.initiallyExpanded = false,
    this.accentColor,
    this.onTap,
    this.padding,
    this.margin,
  });

  @override
  State<AxioCard> createState() => _AxioCardState();
}

class _AxioCardState extends State<AxioCard>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
    if (_isExpanded) _controller.value = 1.0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    if (!widget.isExpandable) {
      widget.onTap?.call();
      return;
    }
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: widget.margin ?? const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.divider, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.slate900.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Accent strip
              if (widget.accentColor != null)
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: widget.accentColor,
                  ),
                ),
              // Card content
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _toggleExpand,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: widget.padding ??
                          const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header row
                          Row(
                            children: [
                              if (widget.leading != null) ...[
                                widget.leading!,
                                const SizedBox(width: 12),
                              ],
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.title,
                                      style: AppTypography.heading3,
                                    ),
                                    if (widget.subtitle != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        widget.subtitle!,
                                        style: AppTypography.bodyMedium,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (widget.trailing != null) widget.trailing!,
                              if (widget.isExpandable &&
                                  widget.expandedContent != null) ...[
                                const SizedBox(width: 8),
                                RotationTransition(
                                  turns: _rotationAnimation,
                                  child: Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: AppColors.textLight,
                                    size: 24,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          // Collapsed content (always visible)
                          if (widget.collapsedContent != null) ...[
                            const SizedBox(height: 12),
                            widget.collapsedContent!,
                          ],
                          // Expanded content (animated)
                          if (widget.expandedContent != null)
                            SizeTransition(
                              sizeFactor: _expandAnimation,
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 12),
                                  const Divider(),
                                  const SizedBox(height: 12),
                                  widget.expandedContent!,
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
