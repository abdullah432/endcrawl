import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:lastreel/features/auth/widgets/google_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The mark is hand-transcribed from Google's SVG path data, which is the one
/// part of the auth UI that could be silently wrong — a mistyped coordinate
/// produces a plausible-looking but off-brand logo that no layout test would
/// catch. So: paint it and read the pixels back.
void main() {
  const size = 96.0;
  const key = Key('mark');

  /// Rasterises the mark once. Encoding needs the real event loop, hence
  /// `runAsync` — awaiting `toByteData` on the test's fake clock deadlocks.
  Future<Uint8List> render(WidgetTester tester) async {
    final pixels = await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return bytes!.buffer.asUint8List();
    });
    return pixels!;
  }

  /// The colour at a point given in the mark's own 24×24 coordinates.
  Color sample(Uint8List rgba, double x, double y) {
    const scale = size / 24;
    final offset = (((y * scale).round() * size.toInt()) + (x * scale).round()) * 4;
    return Color.fromARGB(rgba[offset + 3], rgba[offset], rgba[offset + 1], rgba[offset + 2]);
  }

  /// Compares ignoring the couple of units antialiasing can shift a channel.
  void expectColor(Color actual, Color expected) {
    expect((actual.r - expected.r).abs(), lessThan(0.04), reason: 'red channel');
    expect((actual.g - expected.g).abs(), lessThan(0.04), reason: 'green channel');
    expect((actual.b - expected.b).abs(), lessThan(0.04), reason: 'blue channel');
  }

  testWidgets('paints each arc of the G in its own Google colour', (tester) async {
    await tester.pumpWidget(
      const Center(
        child: RepaintBoundary(key: key, child: GoogleMark(size: size)),
      ),
    );

    final rgba = await render(tester);

    // Four points, one well inside each arc of the ring.
    expectColor(sample(rgba, 12, 2.6), const Color(0xFFEA4335)); // top — red
    expectColor(sample(rgba, 2.6, 12), const Color(0xFFFBBC05)); // left — yellow
    expectColor(sample(rgba, 12, 21.4), const Color(0xFF34A853)); // bottom — green
    expectColor(sample(rgba, 20, 12.6), const Color(0xFF4285F4)); // the bar — blue
  });

  testWidgets('leaves the middle of the ring empty', (tester) async {
    await tester.pumpWidget(
      const Center(
        child: RepaintBoundary(key: key, child: GoogleMark(size: size)),
      ),
    );

    // The G is a ring, not a disc. A transcription error that closed a path
    // the wrong way would fill this in.
    expect(sample(await render(tester), 9, 12).a, 0);
  });
}
