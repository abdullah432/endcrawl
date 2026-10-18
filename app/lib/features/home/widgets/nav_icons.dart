import 'package:flutter/material.dart';

/// The tablet's two navigation icons (§2): a four-square grid for
/// Projects and a gear — Lucide's "settings" cog — for Settings, never a
/// sun, which reads as brightness. Drawn from the design's 24 × 24 stroke
/// paths (stroke 1.8, round caps and joins).
enum NavIcon { projects, settings }

class NavIconView extends StatelessWidget {
  final NavIcon icon;
  final double size;
  final Color color;

  const NavIconView(this.icon, {super.key, this.size = 18, required this.color});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(size: Size.square(size), painter: _NavIconPainter(icon, color)),
  );
}

class _NavIconPainter extends CustomPainter {
  final NavIcon icon;
  final Color color;
  _NavIconPainter(this.icon, this.color);

  // Lucide "settings" (MIT): the cog's outline; the hub is a circle of 3.
  static const _cog =
      'M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38'
      'a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38'
      'a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18'
      'a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08'
      'a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08'
      'a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z';

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (icon) {
      case NavIcon.projects:
        for (final (x, y) in const [(3.0, 4.0), (14.0, 4.0), (3.0, 14.0), (14.0, 14.0)]) {
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, 7, 7), const Radius.circular(1.5)), paint);
        }
      case NavIcon.settings:
        canvas.drawPath(_parse(_cog), paint);
        canvas.drawCircle(const Offset(12, 12), 3, paint);
    }
  }

  /// Enough of the SVG path grammar for the cog: M, H, V, h, v, l, a, z.
  static Path _parse(String d) {
    final path = Path();
    final tokens = RegExp(r'[a-zA-Z]|-?\d*\.?\d+').allMatches(d).map((m) => m.group(0)!).toList();
    var i = 0;
    var command = '';
    var current = Offset.zero;
    double next() => double.parse(tokens[i++]);
    while (i < tokens.length) {
      if (RegExp(r'[a-zA-Z]').hasMatch(tokens[i])) command = tokens[i++];
      switch (command) {
        case 'M':
          current = Offset(next(), next());
          path.moveTo(current.dx, current.dy);
        case 'H':
          current = Offset(next(), current.dy);
          path.lineTo(current.dx, current.dy);
        case 'V':
          current = Offset(current.dx, next());
          path.lineTo(current.dx, current.dy);
        case 'h':
          current = current.translate(next(), 0);
          path.lineTo(current.dx, current.dy);
        case 'v':
          current = current.translate(0, next());
          path.lineTo(current.dx, current.dy);
        case 'l':
          current = current.translate(next(), next());
          path.lineTo(current.dx, current.dy);
        case 'a':
          final rx = next(), ry = next();
          next(); // x-axis rotation: always 0 here.
          final large = next() != 0, sweep = next() != 0;
          current = current.translate(next(), next());
          path.arcToPoint(current, radius: Radius.elliptical(rx, ry), largeArc: large, clockwise: sweep);
        case 'z' || 'Z':
          path.close();
        default:
          throw FormatException('Unsupported path command $command');
      }
    }
    return path;
  }

  @override
  bool shouldRepaint(_NavIconPainter old) => old.icon != icon || old.color != color;
}
