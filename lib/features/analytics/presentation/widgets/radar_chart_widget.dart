import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/chart_data_models.dart';

/// Apple-inspired Radar Chart for visualizing subject mastery
/// across multiple sub-topics as a filled polygon shape.
class RadarChartWidget extends StatefulWidget {
  final List<RadarDataPoint> data;
  final double size;

  const RadarChartWidget({
    super.key,
    required this.data,
    this.size = 260,
  });

  @override
  State<RadarChartWidget> createState() => _RadarChartWidgetState();
}

class _RadarChartWidgetState extends State<RadarChartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    Future.delayed(const Duration(milliseconds: 200), () {
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
    if (widget.data.isEmpty) {
      return SizedBox(
        height: widget.size,
        child: Center(
          child: Text(
            'Take tests to see your mastery shape',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textLight),
          ),
        ),
      );
    }

    return _AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _RadarPainter(
              data: widget.data,
              progress: _animation.value,
            ),
          ),
        );
      },
    );
  }
}

class _RadarPainter extends CustomPainter {
  final List<RadarDataPoint> data;
  final double progress;

  _RadarPainter({required this.data, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 36;
    final sides = data.length;
    final angleStep = (2 * pi) / sides;
    // Start from top (- π/2)
    const startAngle = -pi / 2;

    // ─── Draw concentric grid polygons ───
    final gridPaint = Paint()
      ..color = AppColors.slate900.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (int ring = 1; ring <= 4; ring++) {
      final r = radius * ring / 4;
      final path = Path();
      for (int i = 0; i <= sides; i++) {
        final angle = startAngle + angleStep * (i % sides);
        final point = Offset(
          center.dx + r * cos(angle),
          center.dy + r * sin(angle),
        );
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // ─── Draw axis lines from center ───
    final axisPaint = Paint()
      ..color = AppColors.slate900.withValues(alpha: 0.04)
      ..strokeWidth = 0.5;

    for (int i = 0; i < sides; i++) {
      final angle = startAngle + angleStep * i;
      final outer = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      canvas.drawLine(center, outer, axisPaint);
    }

    // ─── Draw data shape (animated) ───
    final dataPath = Path();
    final dataPoints = <Offset>[];

    for (int i = 0; i < sides; i++) {
      final angle = startAngle + angleStep * i;
      final value = data[i].value.clamp(0.0, 1.0) * progress;
      final r = radius * value;
      final point = Offset(
        center.dx + r * cos(angle),
        center.dy + r * sin(angle),
      );
      dataPoints.add(point);
      if (i == 0) {
        dataPath.moveTo(point.dx, point.dy);
      } else {
        dataPath.lineTo(point.dx, point.dy);
      }
    }
    dataPath.close();

    // Gradient fill for the data shape
    final fillPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: [
          AppColors.primary.withValues(alpha: 0.08),
          AppColors.primary.withValues(alpha: 0.30),
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawPath(dataPath, fillPaint);

    // Stroke for the data shape
    final strokePaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(dataPath, strokePaint);

    // ─── Draw vertex dots ───
    final dotFillPaint = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.fill;
    final dotStrokePaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (final point in dataPoints) {
      canvas.drawCircle(point, 4.0, dotFillPaint);
      canvas.drawCircle(point, 4.0, dotStrokePaint);
    }

    // ─── Draw labels ───
    for (int i = 0; i < sides; i++) {
      final angle = startAngle + angleStep * i;
      final labelRadius = radius + 20;
      final labelPos = Offset(
        center.dx + labelRadius * cos(angle),
        center.dy + labelRadius * sin(angle),
      );

      final textSpan = TextSpan(
        text: data[i].label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.textLight,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      textPainter.layout(maxWidth: 80);

      // Center the label on the position
      final textOffset = Offset(
        labelPos.dx - textPainter.width / 2,
        labelPos.dy - textPainter.height / 2,
      );
      textPainter.paint(canvas, textOffset);
    }
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.data != data;
}

/// Reused AnimatedBuilder pattern from progress_bar.dart
class _AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;
  final Widget? child;

  const _AnimatedBuilder({
    required Animation<double> animation,
    required this.builder,
    this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}
