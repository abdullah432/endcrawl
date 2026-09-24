import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_context.dart';
import '../../../core/theme/tokens.dart';
import '../../../domain/engine/roll_engine.dart';
import '../../../domain/models/credit_block.dart';
import '../../monitor/controllers/playback_controller.dart';
import '../../project/controllers/project_controller.dart';

/// Timecode, then a track with a tick at each block so "Cast" is one drag
/// away (3.1).
class ScrubBar extends ConsumerWidget {
  const ScrubBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.type;
    final p = context.palette;
    final e = ref.watch(projectControllerProvider.select((s) => s.engine));
    final frame = ref.watch(playbackControllerProvider.select((s) => s.frame));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(formatTimecode(frame, e.fps), style: t.mono.copyWith(fontSize: 11, color: p.ink)),
            Text(formatTimecode(e.totalFrames, e.fps), style: t.mono.copyWith(fontSize: 11)),
          ],
        ),
        const ScrubTrack(),
      ],
    );
  }
}

/// The draggable track itself — shared by the editor and, [onBlack], the
/// landscape monitor (3.4).
class ScrubTrack extends ConsumerWidget {
  final bool onBlack;
  const ScrubTrack({super.key, this.onBlack = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final project = ref.watch(projectControllerProvider);
    final e = project.engine;
    final frame = ref.watch(playbackControllerProvider.select((s) => s.frame));
    final progress = e.totalFrames == 0 ? 0.0 : (frame / e.totalFrames).clamp(0.0, 1.0);

    final ticks = onBlack
        ? const <double>[]
        : [
            for (final b in project.activeBlocks)
              if (b is! SpacerBlock && project.measurements.blockY[b.id] != null)
                (frameForY(e, project.measurements.blockY[b.id]! + (b is HoldBlock ? project.geometry.h : 0)) /
                        e.totalFrames)
                    .clamp(0.0, 1.0),
          ];

    void scrub(Offset local, double width) =>
        ref.read(playbackControllerProvider.notifier).scrubToFraction((local.dx / width).clamp(0.0, 1.0));

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return Semantics(
          slider: true,
          label: 'Playhead',
          value: formatTimecode(frame, e.fps),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanDown: (d) => scrub(d.localPosition, w),
            onPanUpdate: (d) => scrub(d.localPosition, w),
            child: SizedBox(
              height: onBlack ? 30 : 22,
              child: Stack(
                alignment: Alignment.centerLeft,
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: onBlack ? Colors.white.withValues(alpha: .2) : p.ink.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(EcRadius.pill),
                    ),
                  ),
                  Container(
                    width: w * progress,
                    height: 4,
                    decoration: BoxDecoration(gradient: p.primary, borderRadius: BorderRadius.circular(EcRadius.pill)),
                  ),
                  for (final x in ticks)
                    Positioned(left: w * x, top: 6, child: Container(width: 1, height: 10, color: p.faint)),
                  Positioned(
                    left: w * progress - 7,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: onBlack ? null : Border.all(color: p.accentSolid, width: 3),
                        boxShadow: onBlack ? null : p.primaryShadow,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
