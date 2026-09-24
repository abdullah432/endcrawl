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

/// Draws a project's frames offscreen at the output resolution, for the
/// encoder. It hosts the same [RollFrame] the monitor shows in a detached
/// render tree — its own [BuildOwner], [PipelineOwner] and [RenderView],
/// never attached to the screen — so a render is exactly what played, and
/// type stays vector-sharp at 4K rather than being an upscaled preview.
///
/// Works from a snapshot of the project taken at [open]; editing while a
/// render runs doesn't touch it. Call [dispose] when done.
class FrameRenderer {
  final RollGeometry geometry;
  final int outputWidth;
  final int outputHeight;
  final RollEngineResult engine;

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
    this._frame,
    this._buildOwner,
    this._pipelineOwner,
    this._boundary,
    this._root,
  );

  /// Frames in the render, head to tail.
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
    final size = Size(geometry.w, geometry.h);
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
          child: RollFrame(
            settings: settings,
            blocks: blocks,
            geometry: geometry,
            engine: engine,
            frame: frame,
            measurer: measurer,
            forRender: true,
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

    return FrameRenderer._(geometry, outputWidth, outputHeight, engine, frame, buildOwner, pipelineOwner, boundary, root!);
  }

  /// Frame [index] as an image at the output size.
  Future<ui.Image> render(int index) {
    _frame.value = index.toDouble();
    _buildOwner
      ..buildScope(_root)
      ..finalizeTree();
    _pipelineOwner
      ..flushLayout()
      ..flushCompositingBits()
      ..flushPaint();
    return _boundary.toImage(pixelRatio: outputWidth / geometry.w);
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
  void dispose() {
    RenderObjectToWidgetAdapter<RenderBox>(container: _boundary).attachToRenderTree(_buildOwner, _root);
    _buildOwner.finalizeTree();
    _frame.dispose();
  }
}
