import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../domain/engine/roll_engine.dart';
import '../../../domain/models/credit_block.dart';
import '../../../domain/models/project_settings.dart';
import 'hold_overlay.dart';
import 'monitor_background.dart';
import 'roll_content.dart';

/// One frame of the canvas at full render resolution (`g.w × g.h`): the
/// background, the roll at [frame], the 3D tilt and any hold card — no
/// guides or chrome. The monitor scales it down to fit; the exporter
/// renders it offscreen, frame by frame, so what plays is what renders.
///
/// [frame] is a listenable so a new frame repaints only the moving parts;
/// the roll's content is laid out once per edit, not once per frame.
class RollFrame extends StatelessWidget {
  final ProjectSettings settings;
  final List<CreditBlock> blocks;
  final RollGeometry geometry;
  final RollEngineResult engine;
  final ValueListenable<double> frame;

  /// Reports where each block landed, which the engine times the roll by.
  final ValueChanged<RollMeasurements>? onMeasured;

  /// For reading measurements on demand, where no frame is scheduled.
  final RollMeasurer? measurer;

  /// Rendering for a file rather than the screen: transparency is real
  /// rather than a checkerboard, and a reference clip is not burned in.
  final bool forRender;

  /// Render pixels per canvas pixel. When set, the flat roll is placed on
  /// whole render pixels (glyphs snap to pixels anyway, so this makes the
  /// snapping even) and the exporter applies the sub-pixel remainder by
  /// resampling. Null draws at the exact offset, as the monitor does.
  final double? snap;

  /// Extra canvas rows drawn below the frame, so a sub-pixel shift upward
  /// has real picture to reveal rather than an empty edge.
  final double overscan;

  const RollFrame({
    super.key,
    required this.settings,
    required this.blocks,
    required this.geometry,
    required this.engine,
    required this.frame,
    this.onMeasured,
    this.measurer,
    this.forRender = false,
    this.snap,
    this.overscan = 0,
  });

  /// Where the roll is drawn for [offset]: on whole render pixels when
  /// [snap] is set, except in 3D, where perspective moves every line by a
  /// different amount anyway.
  static double placedOffset(double offset, {double? snap, required bool crawl3d}) =>
      snap == null || crawl3d ? offset : (offset * snap).floorToDouble() / snap;

  @override
  Widget build(BuildContext context) {
    final g = geometry;
    final paper = settings.background == MonitorBackground.paper;
    final holds = blocks.whereType<HoldBlock>().toList();
    final content = OverflowBox(
      alignment: Alignment.topLeft,
      minWidth: g.w,
      maxWidth: g.w,
      minHeight: 0,
      maxHeight: double.infinity,
      child: RollContent(blocks: blocks, geometry: g, onMeasured: onMeasured, measurer: measurer),
    );

    final crawl3d = settings.look == RollLook.crawl3d;

    return SizedBox(
      width: g.w,
      height: g.h + overscan,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            MonitorBackgroundLayer(background: settings.background, forRender: forRender),
            Positioned(
              left: 0,
              top: 0,
              width: g.w,
              // 3D keeps its frame-sized box: the tilt pivots on its bottom edge.
              height: g.h + (crawl3d ? 0 : overscan),
              child: _Ink(
                paper: paper,
                child: ClipRect(
                  child: ValueListenableBuilder<double>(
                    valueListenable: frame,
                    child: content,
                    builder: (context, f, content) {
                      final placed = placedOffset(paintAt(engine, f).offset, snap: snap, crawl3d: crawl3d);
                      final translated = Transform.translate(offset: Offset(0, g.h - placed), child: content);
                      if (!crawl3d) return translated;
                      final perspectivePx = g.h * (settings.vanishingDistance / 100) * 2;
                      final m = Matrix4.identity()
                        ..setEntry(3, 2, perspectivePx == 0 ? 0 : -1 / perspectivePx)
                        ..rotateX(settings.tilt * math.pi / 180);
                      return _vanish(Transform(alignment: Alignment.bottomCenter, transform: m, child: translated));
                    },
                  ),
                ),
              ),
            ),
            if (holds.isNotEmpty)
              Positioned(
                left: 0,
                top: 0,
                width: g.w,
                height: g.h,
                child: _Ink(
                  paper: paper,
                  child: ValueListenableBuilder<double>(
                    valueListenable: frame,
                    builder: (context, f, _) => HoldOverlay(holds: holds, geometry: g, paint: paintAt(engine, f)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The 3D crawl fades out as it recedes (see [CrawlVanish]).
  Widget _vanish(Widget crawl) {
    final g = geometry;
    final v = CrawlVanish.of(settings, g.h);
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Color(0x00000000), Color(0x00000000), Color(0xFF000000)],
        stops: [0, (g.h - v.vanishAt) / g.h, (g.h - v.fadeFrom) / g.h],
      ).createShader(bounds),
      child: crawl,
    );
  }
}

/// Credits are drawn white; on paper they are inverted to ink.
class _Ink extends StatelessWidget {
  final bool paper;
  final Widget child;
  const _Ink({required this.paper, required this.child});

  @override
  Widget build(BuildContext context) => paper ? ColorFiltered(colorFilter: kPaperInvert, child: child) : child;
}
