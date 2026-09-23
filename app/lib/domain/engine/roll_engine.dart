import 'dart:math';

import '../models/credit_block.dart';
import '../models/credit_face.dart';
import '../models/project_settings.dart';

/// Pure, widget-free port of the prototype's roll math (`geom()`,
/// `castGeom()`, `eng()`, `snaps()`, `tc()`). None of this depends on
/// Flutter's widget tree — it only needs the canvas size and the measured
/// heights of the laid-out blocks, exactly like the DOM version needed
/// `offsetTop` after layout.

class RollGeometry {
  final double w;
  final double h;
  final bool tall;
  final double unit;
  final double base; // the credit-roll base font size, in canvas px
  final double safeWidth;
  final CreditFace face;

  const RollGeometry({
    required this.w,
    required this.h,
    required this.tall,
    required this.unit,
    required this.base,
    required this.safeWidth,
    required this.face,
  });
}

RollGeometry computeGeometry({
  required int formatW,
  required int formatH,
  required CreditFace face,
}) {
  final w = formatW.toDouble();
  final h = formatH.toDouble();
  final tall = h >= w;
  final unit = (w / 1920) * (tall ? 1.75 : 1);
  final base = 44 * unit;
  return RollGeometry(
    w: w,
    h: h,
    tall: tall,
    unit: unit,
    base: base,
    safeWidth: w * 0.8,
    face: face,
  );
}

class CastGeometry {
  final double gutter;
  final double colWidth;
  final bool collapse;
  final double need;
  final int maxChars;

  const CastGeometry({
    required this.gutter,
    required this.colWidth,
    required this.collapse,
    required this.need,
    required this.maxChars,
  });
}

CastGeometry computeCastGeometry(PairListBlock block, RollGeometry g) {
  final gut = g.w * block.gutter;
  final colW = (g.safeWidth - gut) / 2;
  var maxc = 0;
  for (final r in block.rows) {
    if (r is PairCastRow) {
      maxc = max(maxc, max(r.role.length, r.actor.length));
    }
  }
  final need = maxc * g.base * 0.5;
  final collapse = block.alwaysStacked || (block.collapse != CastCollapseMode.never && colW < need);
  return CastGeometry(gutter: gut, colWidth: colW, collapse: collapse, need: need, maxChars: maxc);
}

/// Measured content: the total scrollable travel and each block's top
/// offset within the roll, taken after Flutter lays the roll content out —
/// this is the equivalent of the prototype's `measure()` reading
/// `offsetTop` off the DOM.
class RollMeasurements {
  final double travel;
  final Map<String, double> blockY;
  const RollMeasurements({this.travel = 1, this.blockY = const {}});

  bool closeTo(RollMeasurements other) {
    if ((travel - other.travel).abs() > 0.5) return false;
    for (final k in blockY.keys) {
      if (((blockY[k] ?? 0) - (other.blockY[k] ?? 0)).abs() > 0.5) return false;
    }
    return blockY.length == other.blockY.length;
  }
}

sealed class RollSegment {
  final double y0;
  final double f0;
  final double f1;
  const RollSegment({required this.y0, required this.f0, required this.f1});
}

class FreezeSegment extends RollSegment {
  const FreezeSegment({required super.y0, required super.f0, required super.f1});
}

class ScrollSegment extends RollSegment {
  const ScrollSegment({required super.y0, required super.f0, required super.f1});
}

class HoldSegment extends RollSegment {
  final String id;
  final double fadeInFrames;
  final double fadeOutFrames;
  final double lengthFrames;
  const HoldSegment({
    required super.y0,
    required super.f0,
    required super.f1,
    required this.id,
    required this.fadeInFrames,
    required this.fadeOutFrames,
    required this.lengthFrames,
  });
}

class RollEngineResult {
  final double fps;
  final double ppf;
  final double pps;
  final double scrollFrames;
  final double fixedFrames;
  final bool clean;
  final double dwellSeconds;
  final bool readable;
  final List<RollSegment> segments;
  final double travel;
  final double travelUsed;
  final double headFrames;
  final double tailFrames;
  final double holdFrames;
  final double totalFrames;
  final double canvasH;
  final double canvasW;

  const RollEngineResult({
    required this.fps,
    required this.ppf,
    required this.pps,
    required this.scrollFrames,
    required this.fixedFrames,
    required this.clean,
    required this.dwellSeconds,
    required this.readable,
    required this.segments,
    required this.travel,
    required this.travelUsed,
    required this.headFrames,
    required this.tailFrames,
    required this.holdFrames,
    required this.totalFrames,
    required this.canvasH,
    required this.canvasW,
  });
}

RollEngineResult computeEngine({
  required ProjectSettings project,
  required List<CreditBlock> activeBlocks,
  required RollMeasurements measurements,
  required RollGeometry geometry,
}) {
  final fps = project.fps;
  final travel = max(1.0, measurements.travel);
  final headF = (project.headSeconds * fps).round().toDouble();
  final tailF = (project.tailSeconds * fps).round().toDouble();
  final holds = activeBlocks.whereType<HoldBlock>().toList();
  final holdF = holds.fold<double>(
      0, (a, b) => a + ((b.fadeIn + b.hold + b.fadeOut) * fps).round());
  final fixed = headF + tailF + holdF;

  double ppf;
  double scrollF;
  if (project.mode == TimingMode.duration) {
    final tot = max(fixed + fps * 2, project.durationFrames.toDouble());
    scrollF = tot - fixed;
    ppf = travel / scrollF;
  } else {
    ppf = max(1.0, project.ppf);
    scrollF = (travel / ppf).ceilToDouble();
  }
  final travelUsed = project.mode == TimingMode.speed ? ppf * scrollF : travel;
  final clean = (ppf - ppf.roundToDouble()).abs() < 0.0008;
  final pps = ppf * fps;
  final dwell = pps == 0 ? 0.0 : geometry.h / pps;
  final readable = dwell >= 3;

  final segs = <RollSegment>[];
  double y = 0;
  double f = 0;
  segs.add(FreezeSegment(y0: 0, f0: 0, f1: headF));
  f = headF;

  final sortedHolds = holds
      .map((b) => MapEntry(b, measurements.blockY[b.id] ?? 0.0))
      .toList()
    ..sort((a, b) => a.value.compareTo(b.value));

  for (final entry in sortedHolds) {
    final b = entry.key;
    final hy = entry.value;
    final ty = max(y, min(travelUsed, hy));
    final dy = ty - y;
    final df = ppf == 0 ? 0.0 : dy / ppf;
    segs.add(ScrollSegment(y0: y, f0: f, f1: f + df));
    f += df;
    y = ty;
    final len = ((b.fadeIn + b.hold + b.fadeOut) * fps).round().toDouble();
    final fi = max(1.0, (b.fadeIn * fps).round().toDouble());
    final fo = max(1.0, (b.fadeOut * fps).round().toDouble());
    segs.add(HoldSegment(
      y0: y,
      f0: f,
      f1: f + len,
      id: b.id,
      fadeInFrames: fi,
      fadeOutFrames: fo,
      lengthFrames: len,
    ));
    f += len;
  }

  final tailScrollDf = ppf == 0 ? 0.0 : (travelUsed - y) / ppf;
  segs.add(ScrollSegment(y0: y, f0: f, f1: f + tailScrollDf));
  f += tailScrollDf;
  segs.add(FreezeSegment(y0: travelUsed, f0: f, f1: f + tailF));
  f += tailF;

  return RollEngineResult(
    fps: fps,
    ppf: ppf,
    pps: pps,
    scrollFrames: scrollF,
    fixedFrames: fixed,
    clean: clean,
    dwellSeconds: dwell,
    readable: readable,
    segments: segs,
    travel: travel,
    travelUsed: travelUsed,
    headFrames: headF,
    tailFrames: tailF,
    holdFrames: holdF,
    totalFrames: max(1.0, f),
    canvasH: geometry.h,
    canvasW: geometry.w,
  );
}

class RollPaint {
  final double offset;
  final String? holdId;
  final double holdOpacity;
  const RollPaint({required this.offset, required this.holdId, required this.holdOpacity});
}

RollPaint paintAt(RollEngineResult e, double frame) {
  final fi = frame.clamp(0, max(0, e.totalFrames - 1)).floorToDouble();
  RollSegment seg = e.segments.last;
  for (final s in e.segments) {
    if (fi >= s.f0 && fi < s.f1) {
      seg = s;
      break;
    }
  }
  var off = seg.y0;
  var holdOp = 0.0;
  String? holdId;
  if (seg is ScrollSegment) off = seg.y0 + (fi - seg.f0) * e.ppf;
  if (seg is HoldSegment) {
    holdId = seg.id;
    final t = fi - seg.f0;
    holdOp = t < seg.fadeInFrames
        ? t / seg.fadeInFrames
        : (t > seg.lengthFrames - seg.fadeOutFrames
            ? max(0.0, (seg.lengthFrames - t) / seg.fadeOutFrames)
            : 1.0);
  }
  off = off.roundToDouble();
  return RollPaint(offset: off, holdId: holdId, holdOpacity: holdOp);
}

/// `HH:MM:SS:FF` timecode, frame-accurate at the given frame rate.
String formatTimecode(double frames, double fps) {
  final b = fps.round().clamp(1, 1000000);
  final f = max(0, frames.round());
  final ff = f % b;
  final s = (f ~/ b) % 60;
  final m = (f ~/ (b * 60)) % 60;
  final h = f ~/ (b * 3600);
  return [h, m, s, ff].map((n) => n.toString().padLeft(2, '0')).join(':');
}

/// How long each active block is on screen, in seconds — the "0:48" on
/// its row. A hold or spacer is its own stated time; a scrolling block is
/// its measured height at the current rate. Blocks not yet measured are
/// left out rather than shown as zero.
Map<String, double> blockSeconds(RollEngineResult e, List<CreditBlock> activeBlocks, RollMeasurements m) {
  final out = <String, double>{};
  for (var i = 0; i < activeBlocks.length; i++) {
    final b = activeBlocks[i];
    switch (b) {
      case HoldBlock(:final fadeIn, :final hold, :final fadeOut):
        out[b.id] = fadeIn + hold + fadeOut;
        continue;
      case SpacerBlock(:final seconds):
        out[b.id] = seconds;
        continue;
      default:
    }
    final y = m.blockY[b.id];
    if (y == null || e.pps == 0) continue;
    final nextY = i < activeBlocks.length - 1 ? m.blockY[activeBlocks[i + 1].id] : null;
    final end = nextY ?? (e.travel - e.canvasH);
    out[b.id] = max(0.0, end - y) / e.pps;
  }
  return out;
}

/// The block a "too fast" warning is pinned on: the one with the most
/// lines to read, which is where a short dwell bites first. Null when the
/// roll is readable or nothing has more than one line.
String? readabilityCulprit(RollEngineResult e, List<CreditBlock> activeBlocks) {
  if (e.readable) return null;
  String? id;
  var most = 1;
  for (final b in activeBlocks) {
    final lines = switch (b) {
      NameListBlock(:final names) => names.length,
      PairListBlock(:final rows) => rows.length,
      MainCreditsBlock(:final cards) => cards.fold<int>(0, (a, c) => a + c.names.length),
      _ => 1,
    };
    if (lines > most) {
      most = lines;
      id = b.id;
    }
  }
  return id;
}

/// One-tap fixes for a juddering or too-fast roll (3.2): the nearest whole
/// pixel-per-frame rates that also keep every line on screen for the 3 s
/// floor, nearest first, with the runtime each gives.
List<(int ppf, double totalFrames)> timingFixes(RollEngineResult e, {int count = 2}) {
  if (e.fps == 0 || e.travel <= 1) return const [];
  final readableMax = max(1, (e.canvasH / (3 * e.fps)).floor());
  final start = min(readableMax, max(1, e.ppf.round()));
  final out = <(int, double)>[];
  for (var k = start; k >= 1 && out.length < count; k--) {
    if (e.clean && e.readable) break;
    if ((k - e.ppf).abs() < 0.0008) continue;
    out.add((k, (e.travel / k).ceilToDouble() + e.fixedFrames));
  }
  return out;
}

/// The whole-pixel rates either side of the current one — faster (a
/// shorter runtime) and slower (longer) — with the runtime each gives (5.1).
({(int, double)? shorter, (int, double)? longer}) neighbourRates(RollEngineResult e) {
  if (e.fps == 0 || e.travel <= 1) return (shorter: null, longer: null);
  final whole = (e.ppf - e.ppf.roundToDouble()).abs() < 0.0008;
  final up = whole ? e.ppf.round() + 1 : e.ppf.ceil();
  final down = whole ? e.ppf.round() - 1 : e.ppf.floor();
  (int, double) at(int k) => (k, (e.travel / k).ceilToDouble() + e.fixedFrames);
  return (shorter: at(up), longer: down >= 1 ? at(down) : null);
}
