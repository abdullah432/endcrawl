import 'dart:ui' as ui;

import '../../../domain/engine/roll_engine.dart';
import '../../../domain/models/credit_block.dart';
import '../../../domain/models/project_settings.dart';
import 'frame_renderer.dart';

/// Frames of one render, in order. [FrameRenderer] in the app; a stand-in
/// in tests, where the controller's loop is what's under test.
abstract interface class FrameSource {
  int get frameCount;

  /// Frame [index] at the output size; the caller disposes it.
  Future<ui.Image> render(int index);

  void dispose();
}

typedef FrameSourceFactory = Future<FrameSource> Function({
  required ProjectSettings settings,
  required List<CreditBlock> blocks,
  required RollGeometry geometry,
  required int outputWidth,
  required int outputHeight,
});
