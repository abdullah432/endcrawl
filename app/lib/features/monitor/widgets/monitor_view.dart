import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../project/controllers/project_controller.dart';
import '../controllers/playback_controller.dart';
import 'roll_frame.dart';
import 'safe_guides.dart';

/// The monitor: real-time playback at project frame rate — what plays is
/// what renders (§8 of the brief). The frame is laid out at full canvas
/// resolution by [RollFrame] (the same widget the exporter renders) and
/// scaled down to fit, like the prototype's `canvasScale` transform; the
/// safe-area guides are drawn over it at display size.
class MonitorView extends ConsumerStatefulWidget {
  const MonitorView({super.key});

  @override
  ConsumerState<MonitorView> createState() => _MonitorViewState();
}

class _MonitorViewState extends ConsumerState<MonitorView> {
  late final _frame = ValueNotifier<double>(ref.read(playbackControllerProvider).frame);

  @override
  void dispose() {
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(playbackControllerProvider.select((s) => s.frame), (_, f) => _frame.value = f);
    final project = ref.watch(projectControllerProvider);
    final g = project.geometry;
    final frame = RollFrame(
      settings: project.settings,
      blocks: project.activeBlocks,
      geometry: g,
      engine: project.engine,
      frame: _frame,
      onMeasured: ref.read(projectControllerProvider.notifier).updateMeasurements,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = math.min(constraints.maxWidth / g.w, constraints.maxHeight / g.h);
        final guideWidth = math.max(1.0, g.w / 900);

        return Center(
          child: SizedBox(
            width: g.w * scale,
            height: g.h * scale,
            child: ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // The OverflowBox lets the full-resolution frame lay out
                  // inside the much smaller display box before it's scaled.
                  OverflowBox(
                    alignment: Alignment.topLeft,
                    minWidth: g.w,
                    maxWidth: g.w,
                    minHeight: g.h,
                    maxHeight: g.h,
                    child: Transform.scale(alignment: Alignment.topLeft, scale: scale, child: frame),
                  ),
                  if (project.settings.safeGuides)
                    SafeGuides(guideWidth: (guideWidth * scale).clamp(1.0, double.infinity)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
