import 'package:flutter/material.dart';

/// The dotted leader between a two-column cast row's role and actor —
/// port of the prototype's `radial-gradient` dot-repeat background.
class DottedLeaderPainter extends CustomPainter {
  final double dotSpacing;
  final double dotRadius;
  final double baselineFromBottom;
  final Color color;

  DottedLeaderPainter({
    required this.dotSpacing,
    required this.dotRadius,
    required this.baselineFromBottom,
    this.color = const Color(0x8CFFFFFF),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final y = size.height - baselineFromBottom;
    var x = dotSpacing / 2;
    while (x < size.width) {
      canvas.drawCircle(Offset(x, y), dotRadius, paint);
      x += dotSpacing;
    }
  }

  @override
  bool shouldRepaint(covariant DottedLeaderPainter oldDelegate) =>
      oldDelegate.dotSpacing != dotSpacing || oldDelegate.dotRadius != dotRadius || oldDelegate.baselineFromBottom != baselineFromBottom;
}
