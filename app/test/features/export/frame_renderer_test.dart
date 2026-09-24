import 'dart:typed_data';

import 'package:endcrawl/domain/engine/roll_engine.dart';
import 'package:endcrawl/domain/models/credit_block.dart';
import 'package:endcrawl/domain/models/credit_face.dart';
import 'package:endcrawl/domain/models/project_settings.dart';
import 'package:endcrawl/features/export/render/frame_renderer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

/// Whether any pixel in rows [top, bottom) is lit (not black, not clear).
bool _lit(Uint8List rgba, int width, {int top = 0, int? bottom}) {
  final rows = rgba.length ~/ (width * 4);
  for (var y = top; y < (bottom ?? rows); y++) {
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      if (rgba[i] > 40 || rgba[i + 1] > 40 || rgba[i + 2] > 40) return true;
    }
  }
  return false;
}

void main() {
  final project = film();
  final blocks = [
    ...project.blocks,
    const HoldBlock(id: 'end', lines: ['THE END'], hold: 2, fadeIn: .25, fadeOut: .25),
  ];
  final geometry = computeGeometry(formatW: 1920, formatH: 1080, face: CreditFace.grotesque);

  Future<FrameRenderer> open({ProjectSettings? settings}) => FrameRenderer.open(
        settings: settings ?? project.settings,
        blocks: blocks,
        geometry: geometry,
        outputWidth: 480,
        outputHeight: 270,
      );

  testWidgets('renders frames at the output size, timed from its own layout', (tester) async {
    await tester.runAsync(() async {
      final r = await open();
      addTearDown(r.dispose);

      expect(r.frameCount, greaterThan(24 * 2));
      expect(r.engine.travel, greaterThan(geometry.h));

      final head = await r.renderRgba(0);
      expect(head.length, 480 * 270 * 4);
      expect(_lit(head, 480), isFalse, reason: 'the roll starts below the frame');

      final mid = await r.renderRgba((r.engine.headFrames + r.engine.scrollFrames / 3).round());
      expect(_lit(mid, 480), isTrue, reason: 'credits are in frame mid-roll');
    });
  });

  testWidgets('a hold card is shown on a clear frame, alone', (tester) async {
    await tester.runAsync(() async {
      final r = await open();
      addTearDown(r.dispose);

      final hold = r.engine.segments.whereType<HoldSegment>().single;
      final frame = await r.renderRgba((hold.f0 + hold.lengthFrames / 2).round());
      // The card's line sits at the centre; the top and bottom fifths — where
      // the neighbouring credits would be — are black.
      expect(_lit(frame, 480, top: 110, bottom: 160), isTrue);
      expect(_lit(frame, 480, bottom: 54), isFalse);
      expect(_lit(frame, 480, top: 216), isFalse);
    });
  });

  testWidgets('a transparent background renders clear, not a checkerboard', (tester) async {
    await tester.runAsync(() async {
      final r = await open(settings: project.settings.copyWith(background: MonitorBackground.alpha));
      addTearDown(r.dispose);

      final head = await r.renderRgba(0);
      expect(head.every((b) => b == 0), isTrue);
    });
  });
}
