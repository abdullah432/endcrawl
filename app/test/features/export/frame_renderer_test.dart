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

/// The luminance-weighted vertical centre of the frame's lit pixels, or
/// null when anything lit touches the top or bottom edge (a line only
/// partly in frame would skew it).
double? _centroid(Uint8List rgba, int width) {
  final rows = rgba.length ~/ (width * 4);
  var sum = 0.0;
  var weight = 0.0;
  for (var y = 0; y < rows; y++) {
    var row = 0.0;
    for (var x = 0; x < width; x++) {
      row += rgba[(y * width + x) * 4];
    }
    if (row > 0 && (y < 2 || y >= rows - 2)) return null;
    sum += row * y;
    weight += row;
  }
  return weight == 0 ? null : sum / weight;
}

/// How far the picture moves from frame to frame, over a run of frames
/// where one short block is wholly in view.
Future<List<double>> _steps(FrameRenderer r, int width) async {
  final e = r.engine;
  final mid = (e.headFrames + e.scrollFrames / 2).round();
  final centres = <double>[];
  for (var i = mid - 12; i <= mid + 12; i++) {
    final c = _centroid(await r.renderRgba(i), width);
    if (c != null) centres.add(c);
  }
  return [for (var i = 1; i < centres.length; i++) centres[i - 1] - centres[i]];
}

double _spread(List<double> xs) {
  final mean = xs.reduce((a, b) => a + b) / xs.length;
  return xs.map((x) => (x - mean).abs()).reduce((a, b) => a > b ? a : b);
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

  group('motion is even from frame to frame', () {
    const block = [NameListBlock(id: 'dir', header: 'Directed by', names: ['Maya Okonkwo'])];

    Future<List<double>> stepsFor({required String formatId, required int outW, required int outH, required double ppf}) async {
      final settings = ProjectSettings(formatId: formatId, fps: 24, mode: TimingMode.speed, ppf: ppf, headSeconds: 0, tailSeconds: 0);
      final r = await FrameRenderer.open(
        settings: settings,
        blocks: block,
        geometry: computeGeometry(formatW: settings.format.w, formatH: settings.format.h, face: CreditFace.grotesque),
        outputWidth: outW,
        outputHeight: outH,
      );
      addTearDown(r.dispose);
      return _steps(r, outW);
    }

    testWidgets('at a fractional speed, no uneven whole-pixel steps', (tester) async {
      await tester.runAsync(() async {
        final steps = await stepsFor(formatId: '1x1', outW: 1080, outH: 1080, ppf: 3.37);
        expect(steps.length, greaterThan(10));
        final mean = steps.reduce((a, b) => a + b) / steps.length;
        expect(mean, closeTo(3.37, 0.05));
        expect(_spread(steps), lessThan(0.15), reason: 'steps: $steps');
      });
    });

    testWidgets('scaled to an output size that isn’t a whole multiple of the canvas', (tester) async {
      await tester.runAsync(() async {
        // 2.39 scope, 2048 wide, delivered at 1920: 4 px a frame becomes 3.75.
        final steps = await stepsFor(formatId: '239', outW: 1920, outH: 804, ppf: 4);
        final mean = steps.reduce((a, b) => a + b) / steps.length;
        expect(mean, closeTo(3.75, 0.05));
        expect(_spread(steps), lessThan(0.15), reason: 'steps: $steps');
      });
    });

    testWidgets('a whole-pixel speed at native size moves exactly that far every frame', (tester) async {
      await tester.runAsync(() async {
        final steps = await stepsFor(formatId: '1x1', outW: 1080, outH: 1080, ppf: 4);
        for (final s in steps) {
          expect(s, closeTo(4, 0.01));
        }
      });
    });
  });

  group('3D crawl', () {
    Future<void> endsBlank(ProjectSettings settings) async {
      final r = await FrameRenderer.open(
        settings: settings,
        blocks: project.blocks,
        geometry: geometry,
        outputWidth: 480,
        outputHeight: 270,
      );
      addTearDown(r.dispose);
      final e = r.engine;
      expect(_lit(await r.renderRgba((e.headFrames + e.scrollFrames / 3).round()), 480), isTrue);
      final lastScrolled = (e.totalFrames - e.tailFrames - 1).round();
      expect(_lit(await r.renderRgba(lastScrolled), 480), isFalse, reason: 'the last line has faded out');
    }

    testWidgets('the last line recedes and fades out before the roll ends', (tester) async {
      await tester.runAsync(() => endsBlank(project.settings.copyWith(look: RollLook.crawl3d)));
    });

    testWidgets('even with the horizon inside the frame', (tester) async {
      await tester.runAsync(
        () => endsBlank(project.settings.copyWith(look: RollLook.crawl3d, tilt: 55, vanishingDistance: 20)),
      );
    });
  });
}
