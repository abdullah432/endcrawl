import 'package:endcrawl/domain/engine/roll_engine.dart';
import 'package:endcrawl/domain/models/credit_block.dart';
import 'package:endcrawl/domain/models/credit_face.dart';
import 'package:endcrawl/domain/models/project_settings.dart';
import 'package:flutter_test/flutter_test.dart';

const _blocks = <CreditBlock>[
  NameListBlock(id: 'dir', header: 'Directed by', names: ['Maya Okonkwo']),
  NameListBlock(id: 'thx', kind: BlockKind.thanks, header: 'Thanks', names: ['A', 'B', 'C', 'D']),
  HoldBlock(id: 'hld', lines: ['IN MEMORY'], hold: 3, fadeIn: .5, fadeOut: .5),
];

const _measured = RollMeasurements(travel: 5000, blockY: {'dir': 0, 'thx': 1000, 'hld': 3000});

RollEngineResult _engine(ProjectSettings s) => computeEngine(
      project: s,
      activeBlocks: _blocks,
      measurements: _measured,
      geometry: computeGeometry(formatW: 1920, formatH: 1080, face: CreditFace.grotesque),
    );

final _hd = computeGeometry(formatW: 1920, formatH: 1080, face: CreditFace.grotesque);

RollEngineResult _roll(List<CreditBlock> blocks, RollMeasurements m) => computeEngine(
      project: const ProjectSettings(fps: 24, mode: TimingMode.speed, ppf: 4),
      activeBlocks: blocks,
      measurements: m,
      geometry: _hd,
    );

HoldSegment _holdSeg(RollEngineResult e) => e.segments.whereType<HoldSegment>().single;

void main() {
  group('hold cards', () {
    const dir = NameListBlock(id: 'dir', header: 'Directed by', names: ['Maya Okonkwo']);
    const thx = NameListBlock(id: 'thx', kind: BlockKind.thanks, header: 'Thanks', names: ['A']);
    const hold = HoldBlock(id: 'hld', lines: ['THE END'], hold: 3, fadeIn: .5, fadeOut: .5);

    test('the roll stops with the hold’s clear frame exactly in view, nothing else', () {
      final h = _hd.h;
      final m = RollMeasurements(travel: 1000 + h + 800 + h, blockY: {'dir': 0, 'hld': 1000, 'thx': 1000 + h});
      final e = _roll(const [dir, hold, thx], m);
      final seg = _holdSeg(e);

      final mid = paintAt(e, seg.f0 + seg.lengthFrames / 2);
      expect(mid.holdId, 'hld');
      expect(mid.holdOpacity, 1);
      // The visible band [offset - h, offset] is the gap and only the gap.
      expect(mid.offset - h, 1000);
      expect(mid.offset, m.blockY['thx']);
      expect(frameForY(e, 1000 + h), seg.f0);
    });

    test('a closing hold ends the roll — no blank scroll after the card', () {
      final h = _hd.h;
      final m = RollMeasurements(travel: 1000 + h + h, blockY: {'dir': 0, 'hld': 1000});
      final e = _roll(const [dir, hold], m);
      final seg = _holdSeg(e);

      expect(e.travel, 1000 + h);
      final tail = e.segments.whereType<ScrollSegment>().last;
      expect(tail.f1 - tail.f0, 0);
      expect(paintAt(e, e.totalFrames - 1).offset, seg.y0);
      expect(e.totalFrames, seg.f1 + e.tailFrames);
    });

    test('an opening hold starts in frame — no blank scroll-in before the card', () {
      final h = _hd.h;
      final m = RollMeasurements(travel: h + 800 + h, blockY: {'hld': 0, 'dir': h});
      final e = _roll(const [hold, dir], m);
      final seg = _holdSeg(e);

      expect(seg.f0, e.headFrames);
      expect(paintAt(e, 0).offset, h);
      expect(e.scrollFrames, (800 + h) / 4);
    });
  });

  group('blockSeconds', () {
    test('a scrolling block is its height at the current rate; holds are their stated time', () {
      final e = _engine(const ProjectSettings(fps: 24, mode: TimingMode.speed, ppf: 4));
      final s = blockSeconds(e, _blocks, _measured);

      expect(s['dir'], closeTo(1000 / (4 * 24), 0.001));
      expect(s['hld'], 4);
    });

    test('an unmeasured block is left out rather than shown as zero', () {
      final e = _engine(const ProjectSettings(fps: 24, mode: TimingMode.speed, ppf: 4));
      final s = blockSeconds(e, _blocks, const RollMeasurements(travel: 5000));
      expect(s.containsKey('dir'), isFalse);
      expect(s['hld'], 4);
    });
  });

  group('readability', () {
    test('a readable roll has no culprit', () {
      final e = _engine(const ProjectSettings(fps: 24, mode: TimingMode.speed, ppf: 4));
      expect(e.readable, isTrue);
      expect(readabilityCulprit(e, _blocks), isNull);
    });

    test('too fast pins the warning on the block with the most lines', () {
      final e = _engine(const ProjectSettings(fps: 24, mode: TimingMode.speed, ppf: 30));
      expect(e.readable, isFalse);
      expect(readabilityCulprit(e, _blocks), 'thx');
    });
  });

  group('timingFixes', () {
    test('offers whole, readable rates nearest first, with their runtimes', () {
      final e = _engine(const ProjectSettings(fps: 24, mode: TimingMode.duration, durationFrames: 24 * 47 + 5));
      expect(e.clean, isFalse);

      final fixes = timingFixes(e);
      expect(fixes, hasLength(2));
      final readableMax = (e.canvasH / (3 * e.fps)).floor();
      for (final (ppf, frames) in fixes) {
        expect(ppf, lessThanOrEqualTo(readableMax));
        expect(frames, (e.travel / ppf).ceilToDouble() + e.fixedFrames);
      }
      expect(fixes.first.$1, greaterThan(fixes.last.$1));
    });

    test('a clean, readable roll needs no fix', () {
      final e = _engine(const ProjectSettings(fps: 24, mode: TimingMode.speed, ppf: 4));
      expect(timingFixes(e), isEmpty);
    });
  });

  group('neighbourRates', () {
    test('a whole rate offers one faster and one slower', () {
      final e = _engine(const ProjectSettings(fps: 24, mode: TimingMode.speed, ppf: 4));
      final n = neighbourRates(e);
      expect(n.shorter!.$1, 5);
      expect(n.longer!.$1, 3);
      expect(n.shorter!.$2, lessThan(e.totalFrames));
      expect(n.longer!.$2, greaterThan(e.totalFrames));
    });

    test('a fractional rate offers the whole rates either side', () {
      final e = _engine(const ProjectSettings(fps: 24, mode: TimingMode.duration, durationFrames: 24 * 47 + 5));
      final n = neighbourRates(e);
      expect(n.shorter!.$1, e.ppf.ceil());
      expect(n.longer!.$1, e.ppf.floor());
    });
  });
}
