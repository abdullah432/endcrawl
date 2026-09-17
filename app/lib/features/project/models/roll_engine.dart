import 'dart:math';

import '../../../core/theme/app_theme.dart';
import 'credit_block.dart';
import 'project_settings.dart';

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

CastGeometry computeCastGeometry(CastBlock block, RollGeometry g) {
  final gut = g.w * block.gutter;
  final colW = (g.safeWidth - gut) / 2;
  var maxc = 0;
  for (final r in block.rows) {
    if (r is PairCastRow) {
      maxc = max(maxc, max(r.role.length, r.actor.length));
    }
  }
  final need = maxc * g.base * 0.5;
  final collapse = block.collapse == CastCollapseMode.always ||
      (block.collapse != CastCollapseMode.never && colW < need);
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

/// Nearest whole-pixel-per-frame rates, offered as one-tap "judder-free"
/// fixes when the current duration lands on a fractional rate.
List<(int ppf, double totalFrames)> engineSnaps(RollEngineResult e) {
  final out = <(int, double)>[];
  for (final k in {e.ppf.floor(), e.ppf.ceil()}) {
    if (k < 1) continue;
    final sf = (e.travel / k).ceilToDouble();
    final tf = sf + e.fixedFrames;
    if (!out.any((o) => o.$1 == k)) out.add((k, tf));
  }
  return out;
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
