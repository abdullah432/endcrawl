import 'package:flutter/material.dart';

import '../../../domain/models/project_settings.dart';

class MonitorBackgroundLayer extends StatelessWidget {
  final MonitorBackground background;

  const MonitorBackgroundLayer({super.key, required this.background});

  @override
  Widget build(BuildContext context) {
    switch (background) {
      case MonitorBackground.black:
        return const ColoredBox(color: Colors.black);
      case MonitorBackground.green:
        return const ColoredBox(color: Color(0xFF12B34A));
      case MonitorBackground.custom:
        return const ColoredBox(color: Color(0xFF101820));
      case MonitorBackground.alpha:
        return const ColoredBox(color: Colors.black, child: CustomPaint(painter: _CheckerboardPainter(), size: Size.infinite));
      case MonitorBackground.underlay:
        return Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(-0.6, -1),
                  end: Alignment(0.6, 1),
                  colors: [Color(0xFF30241A), Color(0xFF0D0F14), Color(0xFF16202B), Color(0xFF080A0C)],
                  stops: [0, 0.42, 0.72, 1],
                ),
              ),
            ),
            const Positioned(
              left: 8,
              bottom: 5,
              child: Text('SCENE_042_GRADE.mov', style: TextStyle(fontFamily: 'IBM Plex Mono', fontSize: 8, color: Colors.white54)),
            ),
          ],
        );
    }
  }
}

class _CheckerboardPainter extends CustomPainter {
  const _CheckerboardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const tile = 14.0;
    final a = Paint()..color = const Color(0xFF2A2D31);
    final b = Paint()..color = const Color(0xFF16181B);
    canvas.drawRect(Offset.zero & size, b);
    for (double y = 0; y < size.height; y += tile) {
      for (double x = 0; x < size.width; x += tile) {
        final alt = (((x / tile).round() + (y / tile).round()) % 2) == 0;
        canvas.drawRect(Rect.fromLTWH(x, y, tile, tile), alt ? a : b);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CheckerboardPainter oldDelegate) => false;
}
