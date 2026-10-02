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
  final bool _motionSmoothing;

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
    this._motionSmoothing,
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
    var overscan = _overscanPx / scale;
    var size = Size(geometry.w * scale, (geometry.h + overscan) * scale);
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
                sampleSubframes: true,
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
    // A flat roll needs only one rasterization per output frame: sample
    // shifted crops of the same pixels over a 180-degree shutter exposure.
    // Draw enough below the frame to reveal every crop without a dark edge.
    if (settings.motionSmoothing && settings.look == RollLook.flat2d) {
      overscan = (_overscanPx + (engine.ppf * scale / 2).ceil()) / scale;
      size = Size(geometry.w * scale, (geometry.h + overscan) * scale);
      renderView.configuration = ViewConfiguration(
        logicalConstraints: BoxConstraints.tight(size),
        physicalConstraints: BoxConstraints.tight(size),
        devicePixelRatio: 1,
      );
    }
    mount();
    flush();

    return FrameRenderer._(
      geometry,
      outputWidth,
      outputHeight,
      engine,
      scale,
      settings.look == RollLook.crawl3d,
      settings.motionSmoothing,
      frame,
      buildOwner,
      pipelineOwner,
      boundary,
      root!,
    );
  }

  /// Draw at an exact time, retaining the existing pixel-stable rasterization.
  Future<ui.Image> _draw(double frame) async {
    _frame.value = frame;
    _buildOwner
      ..buildScope(_root)
      ..finalizeTree();
    _pipelineOwner
      ..flushLayout()
      ..flushCompositingBits()
      ..flushPaint();
    return _boundary.toImage();
  }

  /// Frame [index] at the output size. Smoothing integrates a half-frame
  /// exposure rather than taking an instantaneous, perfectly sharp sample.
  /// Holds and freezes remain sharp; perspective is sampled in time, not
  /// blurred uniformly across lines that move at different speeds.
  ///
  /// Without smoothing, a flat roll at a fractional speed is still kept at
  /// one sharpness on every frame. A plain resample is crisp on a whole
  /// pixel and softest half way between, so 5.5 px/frame (a whole-pixel
  /// speed moved to 60 fps at the same runtime) would alternate crisp and
  /// soft frames, a visible 30 Hz shimmer. Half-pixel speeds are biased a
  /// quarter pixel, so frames alternate between mirror-image filters of
  /// equal sharpness; other fractional speeds average one pixel of travel.
  /// Whole-pixel speeds stay pixel for pixel.
  @override
  Future<ui.Image> render(int index) async {
    final first = paintAt(engine, index - .25, subframe: true);
    final last = paintAt(engine, index + .25, subframe: true);
    final moving = (last.offset - first.offset).abs() > .000001;
    final smoothing = _motionSmoothing && moving;
    final flat = !_crawl3d && first.holdId == null && last.holdId == null;
    final step = (engine.ppf * _scale) % 1;
    final subpixel = !smoothing && moving && flat && step > .0001 && step < .9999;
    final halfPixel = subpixel && (step - .5).abs() <= .0001;
    // Exposure in frames: half a frame when smoothing; one render pixel of
    // travel for an uneven fractional speed; otherwise an instant.
    final exposure = smoothing ? .5 : (subpixel && !halfPixel ? 1 / (engine.ppf * _scale) : 0.0);
    // Flat rolls reuse one image; keep sample spacing below one output pixel
    // when possible. Perspective needs distinct rasterizations, bounded to
    // four to limit memory and GPU work on phones.
    final samples = smoothing
        ? (flat ? ((last.offset - first.offset).abs() * outputHeight / geometry.h).ceil().clamp(4, 16) : 4)
        : (exposure > 0 ? 8 : 1);
    final times = [for (var i = 0; i < samples; i++) index + (samples == 1 ? 0.0 : ((i + .5) / samples - .5) * exposure)];
    final paints = [for (final time in times) paintAt(engine, time, subframe: true)];
    final images = <ui.Image>[];
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final destination = Rect.fromLTWH(0, 0, outputWidth.toDouble(), outputHeight.toDouble());
    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..color = Color.from(alpha: 1 / samples, red: 1, green: 1, blue: 1)
      ..blendMode = samples == 1 ? BlendMode.src : BlendMode.plus;
    ui.Picture? picture;
    try {
      ui.Image? reused;
      if (flat) {
        reused = await _draw(times.first);
        images.add(reused);
      }
      for (var i = 0; i < samples; i++) {
        final drawn = reused ?? await _draw(times[i]);
        if (reused == null) images.add(drawn);
        final placed = RollFrame.placedOffset(flat ? paints.first.offset : paints[i].offset, snap: _scale.toDouble(), crawl3d: _crawl3d);
        var fraction = (paints[i].offset - placed) * _scale;
        if (halfPixel) fraction = (fraction * 2 + .0001).floorToDouble() / 2 + .25;
        canvas.drawImageRect(drawn, Rect.fromLTWH(0, fraction, geometry.w * _scale, geometry.h * _scale), destination, paint);
      }
      picture = recorder.endRecording();
      return await picture.toImage(outputWidth, outputHeight);
    } finally {
      picture?.dispose();
      for (final image in images) {
        image.dispose();
      }
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
