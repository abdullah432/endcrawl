import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../domain/engine/roll_engine.dart';
import '../../../domain/models/credit_block.dart';
import '../../../domain/models/project_settings.dart';
import '../../monitor/widgets/roll_content.dart';
import '../../monitor/widgets/roll_frame.dart';
import 'frame_source.dart';

/// Draws a project's frames offscreen at the output resolution, for the
/// encoder. It hosts the same [RollFrame] the monitor shows in a detached
/// render tree — its own [BuildOwner], [PipelineOwner] and [RenderView],
/// never attached to the screen — so a render is exactly what played, and
/// type stays vector-sharp at 4K rather than being an upscaled preview.
///
/// Works from a snapshot of the project taken at [open]; editing while a
/// render runs doesn't touch it. Call [dispose] when done.
class FrameRenderer implements FrameSource {
  final RollGeometry geometry;
  final int outputWidth;
  final int outputHeight;
  final RollEngineResult engine;

  /// Render pixels per canvas pixel: a whole number.
  final int _scale;
  final bool _crawl3d;

  /// Rows drawn below the frame for the sub-pixel shift to reveal.
  static const _overscanPx = 2;

  final ValueNotifier<double> _frame;
  final BuildOwner _buildOwner;
  final PipelineOwner _pipelineOwner;
  final RenderRepaintBoundary _boundary;
  final RenderObjectToWidgetElement<RenderBox> _root;

  FrameRenderer._(
    this.geometry,
    this.outputWidth,
    this.outputHeight,
    this.engine,
    this._scale,
    this._crawl3d,
    this._frame,
    this._buildOwner,
    this._pipelineOwner,
    this._boundary,
    this._root,
  );

  /// Frames in the render, head to tail.
  @override
  int get frameCount => engine.totalFrames.round();

  /// Lays the roll out, waits for its typefaces, and times it from its own
  /// measurements, so the render never depends on what the monitor last
  /// happened to measure.
  static Future<FrameRenderer> open({
    required ProjectSettings settings,
    required List<CreditBlock> blocks,
    required RollGeometry geometry,
    required int outputWidth,
    required int outputHeight,
  }) async {
    final view = ui.PlatformDispatcher.instance.implicitView ?? ui.PlatformDispatcher.instance.views.first;
    // Drawn at a whole multiple of the canvas — the smallest that's at least
    // the output — so a whole-pixel speed stays whole. [render] then fits it
    // to the exact output size, applying any sub-pixel remainder.
    final scale = max(1, (outputWidth / geometry.w).ceil());
    final overscan = _overscanPx / scale;
    final size = Size(geometry.w * scale, (geometry.h + overscan) * scale);
    final boundary = RenderRepaintBoundary();
    final renderView = RenderView(
      view: view,
      configuration: ViewConfiguration(
        logicalConstraints: BoxConstraints.tight(size),
        physicalConstraints: BoxConstraints.tight(size),
        devicePixelRatio: 1,
      ),
      child: RenderPositionedBox(alignment: Alignment.topLeft, child: boundary),
    );
    final pipelineOwner = PipelineOwner()..rootNode = renderView;
    renderView.prepareInitialFrame();
    final buildOwner = BuildOwner(focusManager: FocusManager());

    final frame = ValueNotifier<double>(0);
    final measurer = RollMeasurer();
    var engine = computeEngine(
      project: settings,
      activeBlocks: blocks,
      measurements: const RollMeasurements(),
      geometry: geometry,
    );

    RenderObjectToWidgetElement<RenderBox>? root;
    void mount() {
      final widget = MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.noScaling),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox.fromSize(
            size: size,
            child: FittedBox(
              fit: BoxFit.fill,
              child: RollFrame(
                settings: settings,
                blocks: blocks,
                geometry: geometry,
                engine: engine,
                frame: frame,
                measurer: measurer,
                forRender: true,
                snap: scale.toDouble(),
                overscan: overscan,
              ),
            ),
          ),
        ),
      );
      root = RenderObjectToWidgetAdapter<RenderBox>(container: boundary, child: widget)
          .attachToRenderTree(buildOwner, root);
    }

    void flush() {
      buildOwner
        ..buildScope(root!)
        ..finalizeTree();
      pipelineOwner
        ..flushLayout()
        ..flushCompositingBits()
        ..flushPaint();
    }

    mount();
    flush();
    // The first layout asks for any typeface not yet loaded; lay out again
    // once they're in, or the text is measured in a fallback font.
    try {
      await GoogleFonts.pendingFonts();
    } catch (_) {
      // Offline with nothing cached: the platform fallback is all there is.
    }
    flush();

    final measured = measurer.measure() ?? const RollMeasurements();
    engine = computeEngine(project: settings, activeBlocks: blocks, measurements: measured, geometry: geometry);
    mount();
    flush();

    return FrameRenderer._(
      geometry,
      outputWidth,
      outputHeight,
      engine,
      scale,
      settings.look == RollLook.crawl3d,
      frame,
      buildOwner,
      pipelineOwner,
      boundary,
      root!,
    );
  }

  /// Frame [index] as an image at exactly the output size.
  ///
  /// The roll is drawn on whole render pixels, then this one resample moves
  /// it the rest of the way — the fraction of a pixel it really travelled —
  /// and fits it to the output. Every frame then moves the same distance,
  /// at any speed and any output size, rather than stepping 3,3,4,3,4 px.
  /// A whole-pixel speed at a whole-multiple size has no fraction and no
  /// scaling, so it comes through pixel for pixel.
  @override
  Future<ui.Image> render(int index) async {
    _frame.value = index.toDouble();
    _buildOwner
      ..buildScope(_root)
      ..finalizeTree();
    _pipelineOwner
      ..flushLayout()
      ..flushCompositingBits()
      ..flushPaint();
    final drawn = await _boundary.toImage();

    final offset = paintAt(engine, index.toDouble()).offset;
    final placed = RollFrame.placedOffset(offset, snap: _scale.toDouble(), crawl3d: _crawl3d);
    final fraction = (offset - placed) * _scale;
    final source = Rect.fromLTWH(0, fraction, geometry.w * _scale, geometry.h * _scale);
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImageRect(
      drawn,
      source,
      Rect.fromLTWH(0, 0, outputWidth.toDouble(), outputHeight.toDouble()),
      Paint()..filterQuality = FilterQuality.medium,
    );
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(outputWidth, outputHeight);
    } finally {
      picture.dispose();
      drawn.dispose();
    }
  }

  /// Frame [index] as straight RGBA bytes, row by row, for the encoder.
  Future<Uint8List> renderRgba(int index) async {
    final image = await render(index);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
      return data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      image.dispose();
    }
  }

  /// Unmounts the tree, so its states and listeners are released.
  @override
  void dispose() {
    RenderObjectToWidgetAdapter<RenderBox>(container: _boundary).attachToRenderTree(_buildOwner, _root);
    _buildOwner.finalizeTree();
    _frame.dispose();
  }
}
