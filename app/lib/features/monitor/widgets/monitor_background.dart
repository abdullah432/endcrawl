import 'package:flutter/material.dart';

import '../../../domain/models/project_settings.dart';

/// What the roll plays over (5.3).
class MonitorBackgroundLayer extends StatelessWidget {
  final MonitorBackground background;

  const MonitorBackgroundLayer({super.key, required this.background});

  /// Paper for print proofs.
  static const paper = Color(0xFFF3F1EC);

  @override
  Widget build(BuildContext context) {
    return switch (background) {
      MonitorBackground.black => const ColoredBox(color: Colors.black),
      MonitorBackground.alpha => const CustomPaint(painter: CheckerboardPainter(), size: Size.infinite),
      MonitorBackground.paper => const ColoredBox(color: paper),
      MonitorBackground.reference => const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(0.5, -1),
              end: Alignment(-0.5, 1),
              colors: [Color(0xFF4A3524), Color(0xFF101216), Color(0xFF1C2A38)],
            ),
          ),
        ),
    };
  }
}

/// Transparency, shown the way every editor shows it.
class CheckerboardPainter extends CustomPainter {
  final double tile;
  const CheckerboardPainter({this.tile = 12});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final dark = Paint()..color = const Color(0xFFE3DCD0);
    for (var y = 0.0; y < size.height; y += tile) {
      for (var x = 0.0; x < size.width; x += tile) {
        if (((x / tile).round() + (y / tile).round()).isEven) canvas.drawRect(Rect.fromLTWH(x, y, tile, tile), dark);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CheckerboardPainter oldDelegate) => oldDelegate.tile != tile;
}

/// White credits read as ink on paper: the roll is inverted, alpha kept.
const kPaperInvert = ColorFilter.matrix(<double>[
  -1, 0, 0, 0, 255, //
  0, -1, 0, 0, 255, //
  0, 0, -1, 0, 255, //
  0, 0, 0, 1, 0, //
]);
