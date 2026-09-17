import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../monitor/controllers/playback_controller.dart';
import '../../monitor/widgets/monitor_view.dart';
import '../../project/controllers/project_controller.dart';
import '../../project/models/roll_engine.dart';
import 'status_line.dart';

/// Turning the phone to landscape expands the monitor to full-bleed with
/// the editor UI dimmed away; turning back restores the editor (§4 of the
/// brief — this should feel inevitable, so it triggers off the device's
/// real orientation, not a manual toggle).
class LandscapeMonitor extends ConsumerWidget {
  const LandscapeMonitor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectControllerProvider);
    final playback = ref.watch(playbackControllerProvider);
    final playbackCtrl = ref.read(playbackControllerProvider.notifier);
    final e = project.engine;

    return Stack(
      fit: StackFit.expand,
      children: [
        const MonitorView(),
        Positioned(
          left: EcSpace.s5,
          right: EcSpace.s5,
          top: EcSpace.s3,
          child: SafeArea(
            bottom: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: .7), border: Border.all(color: EcColors.borderHairline), borderRadius: BorderRadius.circular(EcRadius.full)),
                    child: StatusLine(project: project),
                  ),
                ),
                const SizedBox(width: EcSpace.s3),
                const Flexible(
                  child: Text(
                    'FULL-BLEED MONITOR · ROTATE BACK TO EDIT',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 10, letterSpacing: 1.2, color: EcColors.textTertiary),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: EcSpace.s4,
          child: SafeArea(
            top: false,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: EcSpace.s4, vertical: 8),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: .7), border: Border.all(color: EcColors.borderHairline), borderRadius: BorderRadius.circular(EcRadius.full)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Material(
                      color: EcColors.accentPrimary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: playbackCtrl.togglePlay,
                        child: SizedBox(width: 34, height: 34, child: Icon(playback.playing ? Icons.pause : Icons.play_arrow, size: 16, color: EcColors.accentInk)),
                      ),
                    ),
                    const SizedBox(width: EcSpace.s3),
                    SizedBox(
                      width: 104,
                      child: Text(formatTimecode(playback.frame, e.fps), style: const TextStyle(fontFamily: EcFonts.mono, fontSize: 13, color: EcColors.textPrimary)),
                    ),
                    Builder(builder: (barContext) {
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanDown: (d) => _scrub(barContext, d.globalPosition, ref),
                        onPanUpdate: (d) => _scrub(barContext, d.globalPosition, ref),
                        child: SizedBox(
                          width: 260,
                          height: 34,
                          child: Stack(
                            alignment: Alignment.centerLeft,
                            children: [
                              Container(height: 3, decoration: BoxDecoration(color: EcColors.surfaceHi, borderRadius: BorderRadius.circular(EcRadius.full))),
                              Align(
                                alignment: Alignment((playback.frame / e.totalFrames).clamp(0, 1) * 2 - 1, 0),
                                child: Container(width: 2, height: 20, color: EcColors.accentPrimary),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(width: EcSpace.s3),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _scrub(BuildContext context, Offset globalPos, WidgetRef ref) {
    final box = context.findRenderObject() as RenderBox;
    final local = box.globalToLocal(globalPos);
    final t = (local.dx / box.size.width).clamp(0.0, 1.0);
    ref.read(playbackControllerProvider.notifier).scrubToFraction(t);
  }
}
