import 'package:flutter/material.dart';

import '../../../core/theme/theme_context.dart';

/// Title-safe (80%, dashed) and action-safe (90%, solid) guides — on by
/// default for landscape formats, always toggleable (§3 of the brief).
class SafeGuides extends StatelessWidget {
  final double guideWidth;

  const SafeGuides({super.key, required this.guideWidth});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return IgnorePointer(
      child: FractionallySizedBox(
        widthFactor: .9,
        heightFactor: .9,
        child: Container(
          decoration: BoxDecoration(border: Border.all(color: Colors.white.withValues(alpha: .22), width: guideWidth)),
          child: Center(
            child: FractionallySizedBox(
              widthFactor: 8 / 9,
              heightFactor: 8 / 9,
              child: CustomPaint(painter: _DashedRectPainter(color: p.accentOnBlack.withValues(alpha: .55), strokeWidth: guideWidth)),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  _DashedRectPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    final rect = Offset.zero & size;
    final path = Path()..addRect(rect);
    _drawDashedPath(canvas, path, paint);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const dashWidth = 6.0;
    const dashGap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(metric.extractPath(distance, next.clamp(0, metric.length)), paint);
        distance = next + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) => false;
}
