import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../project/controllers/project_controller.dart';
import '../../project/models/credit_block.dart';
import '../../project/models/project_settings.dart';
import '../../project/models/roll_engine.dart';
import '../controllers/playback_controller.dart';
import 'hold_overlay.dart';
import 'monitor_background.dart';
import 'roll_content.dart';
import 'safe_guides.dart';

/// The monitor: real-time playback at project frame rate — what plays is
/// what renders (§8 of the brief). Renders the roll at full canvas
/// resolution then scales the whole thing down to fit the available box,
/// exactly like the prototype's `canvasScale` transform.
///
/// Two [OverflowBox]es do the work CSS does for free: the outer one lets a
/// box declared at full render resolution (`g.w × g.h`) lay out inside a
/// much smaller display box (it's then visually shrunk by [Transform.scale]
/// to exactly fit); the inner one lets the *roll content* grow taller than
/// the canvas — it's the scrollable part, clipped by the [ClipRect] around
/// it and positioned by [Transform.translate] — without either box being
/// crushed down to its tight ambient constraints.
class MonitorView extends ConsumerWidget {
  const MonitorView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectControllerProvider);
    final settings = project.settings;
    final g = project.geometry;
    final content = RollContent(blocks: project.activeBlocks, geometry: g);
    final holds = project.activeBlocks.whereType<HoldBlock>().toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final availW = constraints.maxWidth;
        final availH = constraints.maxHeight;
        final scale = math.min(availW / g.w, availH / g.h);
        final dW = g.w * scale;
        final dH = g.h * scale;
        final guideWidth = math.max(1.0, g.w / 900);

        Widget atFullRes(Widget child) {
          return OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: g.w,
            maxWidth: g.w,
            minHeight: g.h,
            maxHeight: g.h,
            child: Transform.scale(alignment: Alignment.topLeft, scale: scale, child: child),
          );
        }

        return Center(
          child: SizedBox(
            width: dW,
            height: dH,
            child: ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MonitorBackgroundLayer(background: settings.background),
                  atFullRes(
                    SizedBox(
                      width: g.w,
                      height: g.h,
                      child: ClipRect(
                        child: Consumer(
                          builder: (context, ref, _) {
                            final frame = ref.watch(playbackControllerProvider).frame;
                            final paint = paintAt(project.engine, frame);
                            final translated = Transform.translate(
                              offset: Offset(0, g.h - paint.offset),
                              child: OverflowBox(
                                alignment: Alignment.topLeft,
                                minWidth: g.w,
                                maxWidth: g.w,
                                minHeight: 0,
                                maxHeight: double.infinity,
                                child: SizedBox(width: g.w, child: content),
                              ),
                            );
                            if (settings.look != RollLook.crawl3d) return translated;
                            final perspectivePx = g.h * (settings.vanishingDistance / 100) * 2;
                            final m = Matrix4.identity()
                              ..setEntry(3, 2, perspectivePx == 0 ? 0 : -1 / perspectivePx)
                              ..rotateX(settings.tilt * math.pi / 180);
                            return Transform(alignment: Alignment.bottomCenter, transform: m, child: translated);
                          },
                        ),
                      ),
                    ),
                  ),
                  Consumer(
                    builder: (context, ref, _) {
                      final frame = ref.watch(playbackControllerProvider).frame;
                      final paint = paintAt(project.engine, frame);
                      return atFullRes(SizedBox(width: g.w, height: g.h, child: HoldOverlay(holds: holds, geometry: g, paint: paint)));
                    },
                  ),
                  if (settings.safeGuides) SafeGuides(guideWidth: (guideWidth * scale).clamp(1.0, double.infinity)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
