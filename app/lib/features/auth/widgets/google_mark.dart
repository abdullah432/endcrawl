import 'package:flutter/material.dart';

/// The Google "G", painted from the official mark's own path data.
///
/// Transcribed from the 24×24 SVG rather than approximated with arcs, and
/// painted rather than shipped as an asset or pulled in via an SVG package:
/// the geometry is fixed, so a `CustomPainter` is exact at any size, costs
/// nothing at runtime and adds no dependency for a single icon.
class GoogleMark extends StatelessWidget {
  final double size;

  const GoogleMark({super.key, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _GoogleMarkPainter()),
    );
  }
}

class _GoogleMarkPainter extends CustomPainter {
  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  /// The mark's own coordinate system; everything below is in these units
  /// and scaled to fit whatever box it is given.
  static const _viewBox = 24.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _viewBox, size.height / _viewBox);

    final paint = Paint()..isAntiAlias = true;
    canvas.drawPath(_blueArm(), paint..color = _blue);
    canvas.drawPath(_greenArc(), paint..color = _green);
    canvas.drawPath(_yellowArc(), paint..color = _yellow);
    canvas.drawPath(_redArc(), paint..color = _red);

    canvas.restore();
  }

  // M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21
  // 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z
  Path _blueArm() => Path()
    ..moveTo(22.56, 12.25)
    ..relativeCubicTo(0, -0.78, -0.07, -1.53, -0.2, -2.25)
    ..lineTo(12, 10)
    ..relativeLineTo(0, 4.26)
    ..relativeLineTo(5.92, 0)
    ..relativeCubicTo(-0.26, 1.37, -1.04, 2.53, -2.21, 3.31)
    ..relativeLineTo(0, 2.77)
    ..relativeLineTo(3.57, 0)
    ..relativeCubicTo(2.08, -1.92, 3.28, -4.74, 3.28, -8.09)
    ..close();

  // M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71
  // 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z
  Path _greenArc() => Path()
    ..moveTo(12, 23)
    ..relativeCubicTo(2.97, 0, 5.46, -0.98, 7.28, -2.66)
    ..relativeLineTo(-3.57, -2.77)
    ..relativeCubicTo(-0.98, 0.66, -2.23, 1.06, -3.71, 1.06)
    ..relativeCubicTo(-2.86, 0, -5.29, -1.93, -6.16, -4.53)
    ..lineTo(2.18, 14.09)
    ..relativeLineTo(0, 2.84)
    ..cubicTo(3.99, 20.53, 7.7, 23, 12, 23)
    ..close();

  // M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43
  // 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z
  Path _yellowArc() => Path()
    ..moveTo(5.84, 14.09)
    ..relativeCubicTo(-0.22, -0.66, -0.35, -1.36, -0.35, -2.09)
    // The SVG's smooth-cubic `s`, resolved: the first control point is the
    // previous one reflected through the current point.
    ..cubicTo(5.49, 11.27, 5.62, 10.57, 5.84, 9.91)
    ..lineTo(5.84, 7.07)
    ..lineTo(2.18, 7.07)
    ..cubicTo(1.43, 8.55, 1, 10.22, 1, 12)
    ..cubicTo(1, 13.78, 1.43, 15.45, 2.18, 16.93)
    ..relativeLineTo(2.85, -2.22)
    ..relativeLineTo(0.81, -0.62)
    ..close();

  // M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1
  // 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z
  Path _redArc() => Path()
    ..moveTo(12, 5.38)
    ..relativeCubicTo(1.62, 0, 3.06, 0.56, 4.21, 1.64)
    ..relativeLineTo(3.15, -3.15)
    ..cubicTo(17.45, 2.09, 14.97, 1, 12, 1)
    ..cubicTo(7.7, 1, 3.99, 3.47, 2.18, 7.07)
    ..relativeLineTo(3.66, 2.84)
    ..relativeCubicTo(0.87, -2.6, 3.3, -4.53, 6.16, -4.53)
    ..close();

  @override
  bool shouldRepaint(_GoogleMarkPainter oldDelegate) => false;
}
