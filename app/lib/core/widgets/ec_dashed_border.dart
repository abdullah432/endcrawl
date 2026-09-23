import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/theme_context.dart';

/// A dashed rounded outline — the empty reel slot on the library and the
/// "Start empty" row. Flutter's borders are solid only, so it's painted.
class EcDashedBorder extends StatelessWidget {
  final Widget child;
  final double radius;
  final Color? color;
  final VoidCallback? onTap;

  const EcDashedBorder({super.key, required this.child, this.radius = 18, this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedPainter(color: color ?? context.palette.line2, radius: radius),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: child),
      ),
    );
  }
}

class _DashedPainter extends CustomPainter {
  final Color color;
  final double radius;
  _DashedPainter({required this.color, required this.radius});

  static const _dash = 5.0;
  static const _gap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final outline = Path()
      ..addRRect(RRect.fromRectAndRadius((Offset.zero & size).deflate(0.5), Radius.circular(radius)));
    for (final PathMetric metric in outline.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + _dash), paint);
        d += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPainter old) => old.color != color || old.radius != radius;
}
