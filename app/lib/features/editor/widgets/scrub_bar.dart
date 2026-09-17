import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../project/controllers/project_controller.dart';
import '../../../domain/models/credit_block.dart';
import '../../../domain/engine/roll_engine.dart';
import '../../monitor/controllers/playback_controller.dart';

/// Scrub bar with timecode and block markers, so the user can jump to
/// e.g. "Cast" instantly (§8 of the brief).
class ScrubBar extends ConsumerWidget {
  const ScrubBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectControllerProvider);
    final e = project.engine;
    final frame = ref.watch(playbackControllerProvider).frame;

    final markers = <(double pct, Color color)>[];
    for (final b in project.activeBlocks) {
      if (b is SpacerBlock) continue;
      final y = project.measurements.blockY[b.id] ?? 0;
      final fr = e.headFrames + (e.ppf == 0 ? 0 : y / e.ppf);
      final pct = (fr / e.totalFrames * 100).clamp(0, 100).toDouble();
      markers.add((pct, b is CastBlock ? EcColors.accentPrimary : EcColors.borderStrong));
    }

    void handleDrag(BuildContext context, Offset globalPos) {
      final box = context.findRenderObject() as RenderBox;
      final local = box.globalToLocal(globalPos);
      final t = (local.dx / box.size.width).clamp(0.0, 1.0);
      ref.read(playbackControllerProvider.notifier).scrubToFraction(t);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(formatTimecode(frame, e.fps), style: const TextStyle(fontFamily: EcFonts.mono, fontSize: 12, color: EcColors.textPrimary)),
            Text(formatTimecode(e.totalFrames, e.fps), style: const TextStyle(fontFamily: EcFonts.mono, fontSize: 11, color: EcColors.textTertiary)),
          ],
        ),
        const SizedBox(height: 4),
        Builder(builder: (barContext) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanDown: (d) => handleDrag(barContext, d.globalPosition),
            onPanUpdate: (d) => handleDrag(barContext, d.globalPosition),
            child: SizedBox(
              height: 24,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(height: 3, decoration: BoxDecoration(color: EcColors.surfaceHi, borderRadius: BorderRadius.circular(EcRadius.full))),
                  for (final m in markers)
                    Align(
                      alignment: Alignment(m.$1 / 50 - 1, 0),
                      child: Container(width: 1, height: 10, color: m.$2),
                    ),
                  Align(
                    alignment: Alignment((frame / e.totalFrames).clamp(0, 1) * 2 - 1, 0),
                    child: Container(
                      width: 2,
                      height: 16,
                      decoration: BoxDecoration(color: EcColors.accentPrimary, boxShadow: [BoxShadow(color: EcColors.accentPrimary.withValues(alpha: .6), blurRadius: 8)]),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
