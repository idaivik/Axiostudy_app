import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum AxioButtonStyle { primary, secondary, text }

class AxioButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final AxioButtonStyle style;
  final bool isLoading;
  final IconData? icon;
  final double? width;

  const AxioButton({
    super.key,
    required this.label,
    this.onPressed,
    this.style = AxioButtonStyle.primary,
    this.isLoading = false,
    this.icon,
    this.width,
  });

  @override
  State<AxioButton> createState() => _AxioButtonState();
}

class _AxioButtonState extends State<AxioButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: widget.style == AxioButtonStyle.primary
                  ? AppColors.white
                  : AppColors.primary,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 18),
                const SizedBox(width: 8),
              ],
              Text(widget.label, style: AppTypography.button),
            ],
          );

    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        _scaleController.forward();
      },
      onTapUp: (_) => _scaleController.reverse(),
      onTapCancel: () => _scaleController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: SizedBox(
          width: widget.width,
          child: switch (widget.style) {
            AxioButtonStyle.primary => ElevatedButton(
                onPressed: widget.isLoading ? null : widget.onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 0,
                  textStyle: AppTypography.button,
                ),
                child: child,
              ),
            AxioButtonStyle.secondary => OutlinedButton(
                onPressed: widget.isLoading ? null : widget.onPressed,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  textStyle: AppTypography.button.copyWith(color: AppColors.primary),
                ),
                child: child,
              ),
            AxioButtonStyle.text => TextButton(
                onPressed: widget.isLoading ? null : widget.onPressed,
                child: child,
              ),
          },
        ),
      ),
    );
  }
}
